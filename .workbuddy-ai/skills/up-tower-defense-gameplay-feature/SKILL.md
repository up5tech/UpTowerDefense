---
name: up-tower-defense-gameplay-feature
description: Implement a new gameplay feature or rule in the UpTowerDefense Flutter/Flame tower defense repo — targeting, projectiles, damage, status effects, tower upgrades, selling, wave transitions, victory/defeat, save and campaign progress — following the ADR 0001 layer boundaries. This skill should be used when adding or changing gameplay behaviour in lib/features/gameplay/**, when a new system must be added to LevelSession, when a Flame component needs to visualise new state, or when a domain rule is being tested. It encodes the five-layer dependency rule, the simulation invariants, the transactional economy pattern, the typed-refusal pattern, the HUD publish-if-changed contract and the domain-test style that this codebase requires.
agent_created: true
---

# UpTowerDefense — implementing a gameplay feature

Gameplay rules live in the domain layer as plain Dart. Flame draws them; Flutter
widgets present them. This skill is the procedure for adding a rule without
breaking that split.

**The single most common failure mode in this repo is putting a gameplay
decision in a Flame component.** A tower that decides its own target, a component
that pays a reward, a `render()` that mutates game state — each of these passes
`flutter analyze`, breaks no test, and makes the rule untestable. Read §2 before
writing any code.

---

## 1. Orient first

Before editing:

1. Read the phase's **acceptance criteria** in `PLAN.md` §8 and the matching
   **rules** in `docs/GAME_DESIGN.md`.
2. Read `docs/adr/0001-flutter-flame-layer-boundaries.md`.
3. Read `AGENTS.md` in the repo root — it is the operating contract.
4. Inspect the existing code. Phases 0–4 are done: `LevelSession` already owns
   waves, enemies, leaks, the core, gold and tower placement. Extend it; do not
   build a parallel mechanism.

---

## 2. The layer rule

```text
Flutter presentation   menus, HUD, panels, dialogs, settings
        ↓
Flame presentation     game loop, world, components, effects, input
        ↓
Application            level start/restart, pause, outcomes, unlocks
        ↓
Domain (plain Dart)    waves, movement, targeting, damage, economy, outcomes
        ↓
Data                   content loaders, repositories, saves
```

| Rule | Enforcement |
|---|---|
| Domain imports no Flutter and no Flame | `lib/features/gameplay/domain/**` uses only `dart:*` and `package:meta` |
| Domain never reads screen dimensions | world units only |
| Flame components never own gold, outcome, costs, unlocks | they read the session |
| Rendering never touches saves or unlocks | data layer only |
| Definitions immutable; runtime state separate | `TowerInstance`, `EnemyState` |
| Time enters the domain as explicit `dt` | no `Timer`, no `DateTime.now()` |
| Per-frame state never flows through global providers | HUD subscribes to a coarse snapshot |

If a rule needs a new system, it belongs in `domain/`. The current domain
layout:

```text
lib/features/gameplay/domain/
  models/          immutable definitions + mutable runtime state
  level_session.dart   the authoritative simulation
  map_geometry.dart    route maths
  *_validation.dart    content validators
  validation_result.dart
```

---

## 3. Where a new rule goes

| Kind of change | Layer | Typical file |
|---|---|---|
| New stat, new enemy, new tower | Data + Domain | `assets/data/*.json`, `domain/models/*` |
| New rule that changes simulation outcomes | Domain | `domain/level_session.dart` or a new `domain/<system>.dart` |
| New rule the player triggers (build, upgrade, sell, start wave) | Domain + Application | `domain/level_session.dart`, `application/level_controller.dart` |
| New thing to draw | Flame | `flame/<entity>_layer.dart` |
| New button, panel, readout | Flutter presentation | `presentation/gameplay_screen.dart` |
| New persisted thing | Data | `data/*_repository.dart` |

---

## 4. The `LevelSession` contract

`LevelSession` is the authoritative simulation. It is constructed with the
content bundle and advanced only through `advance(dt)`.

```dart
final session = LevelSession(
  level: content.level,
  map: content.map,
  enemyCatalog: content.enemies,
  towerCatalog: content.towers,
);

session.advance(1 / 60);   // the ONLY way time enters the domain
```

Existing public surface — extend it, do not replace it:

| Member | Role |
|---|---|
| `phase` | `LevelPhase.ready / playing / victory / defeat` |
| `coreHealth`, `gold`, `leaks`, `elapsed` | mutable run state |
| `enemies`, `pendingSpawns`, `towers`, `towerCount` | live collections |
| `startedWaves`, `totalWaves`, `isWaveActive`, `canStartNextWave` | wave state |
| `startNextWave()` | schedules spawns on the simulation clock |
| `canBuildOn(padId, definition)` | non-mutating check |
| `buildTower(padId, definition)` | the only path that spends gold |
| `towerAtPad(padId)`, `isPadOccupied(padId)` | occupancy queries |
| `reportEnemyDefeated(enemy)` | the single kill-resolution path |
| `advance(dt)` | advances the simulation |

---

## 5. Patterns to copy

### 5.1 Transactional operation (gold)

A refused operation must leave the run byte-for-byte unchanged. Validate
everything first, then mutate.

```dart
TowerBuildResult buildTower(String padId, TowerDefinition definition) {
  final blocker = _buildBlocker(padId, definition);
  if (blocker != null) {
    return TowerBuildResult.refused(
      blocker,
      missingGold: blocker == TowerBuildBlocker.insufficientGold
          ? definition.buildCost - gold
          : 0,
    );
  }

  gold -= definition.buildCost;          // only after every check passed
  final tower = TowerInstance(...);
  _towers.add(tower);
  _towersByPad[padId] = tower;            // pad id is the occupancy key
  return TowerBuildResult.built(tower);
}
```

**The rule:** check → mutate. Never mutate then check, never partially apply.

### 5.2 Typed refusal, not a log line

Return a reason so the UI can explain a disabled option and tests can assert
the exact rule.

```dart
enum TowerBuildBlocker {
  levelEnded,
  unknownPad,
  padOccupied,
  insufficientGold,
}
```

A test that asserts "no tower was built" passes even when the *wrong* rule
fired. A test that asserts `blocker == TowerBuildBlocker.insufficientGold`
pins the behaviour.

### 5.3 Resolve-once semantics

Each enemy resolves exactly once, whether it died or leaked. Removal from the
active list is what guarantees it:

```dart
void reportEnemyDefeated(EnemyState enemy) {
  final removed = _enemies.remove(enemy);
  if (!removed) {
    return;              // already resolved — no second reward
  }
  enemy.resolved = true;
  gold += enemy.definition.rewardGold;
  _evaluateWaveCompletion();
}
```

Never pay a reward outside this path. Never let a leaked enemy also pay a kill
reward.

### 5.4 Simulation-time spawns

Spawn times are absolute simulation times, and a mid-frame spawn starts at its
exact progress so cadence never grants a free step.

```dart
final activeFor = math.max(0.0, _elapsed - spawn.time);
_enemies.add(EnemyState(
  instanceId: _nextInstanceId,
  definition: spawn.definition,
  distanceAlongRoute: spawn.definition.speed * activeFor,
));
```

### 5.5 Publishing to the HUD

`LevelController` publishes a coarse, immutable snapshot and notifies only when
it actually changed — so a running level does not rebuild Flutter every frame.

```dart
@immutable
class LevelHudState {
  final int coreHealth, maxCoreHealth, gold, towerCount;
  final int startedWaves, totalWaves, activeEnemies;
  final LevelPhase phase;
  final bool canStartWave;

  // == and hashCode implemented by hand
}

void _publishIfChanged() {
  final next = _snapshot(session);
  if (next == _hud) return;
  _hud = next;
  notifyListeners();
}
```

**Adding a HUD value:** add the field to `LevelHudState`, include it in `==`
and `hashCode`, add it to `_snapshot`, and add it to `toString`. A field
missing from `==` makes the publish check silently skip updates.

### 5.6 Rendering new state

Flame layers read the session **every frame** rather than caching, so the
renderer can never show something the simulation does not have.

```dart
class TowerLayer extends PositionComponent {
  final LevelSession session;

  @override
  void render(Canvas canvas) {
    for (final tower in session.towers) { ... }
  }
}
```

### 5.7 Clamping deltas

The engine clamps; the domain defends itself.

```dart
static const double maxFrameDelta = 0.1;

@override
void update(double dt) {
  final clamped = dt.clamp(0.0, maxFrameDelta);
  controller.advance(clamped);
  super.update(clamped);
}
```

The domain additionally ignores non-positive and non-finite deltas:

```dart
void advance(double dt) {
  if (!dt.isFinite || dt <= 0) return;
  if (_phase != LevelPhase.playing) return;
  ...
}
```

---

## 6. Invariants to preserve

- One clock — only `advance(dt)`.
- Frame deltas clamped; a hiccup slows the game, never teleports an enemy.
- Frame-rate independent results (assert at 1/60, 1/30 and a coarse step).
- Each enemy resolves once; reward once; leak penalty once.
- Economy operations atomic.
- Waves never overlap.
- The UI never reports success before the domain operation succeeds.
- Pausing freezes every simulation-bound timer.
- Gold is an integer.
- Deterministic tie-breaking for targeting.
- Victory only when every wave spawned and no enemy is active or pending.
- Defeat only when core health reaches zero, and only once.

---

## 7. Tests

### Placement

| Kind | Path | Covers |
|---|---|---|
| Unit | `test/unit/` | domain rules, validation, economy, controller |
| Widget | `test/widget/` | navigation, HUD, panels, build flow |
| Integration | `test/integration/` | end-to-end level flows |

**Domain tests never pump a widget.** A domain rule that can only be tested
through a renderer is in the wrong layer.

### Fixtures

Reuse what exists in `test/helpers/`:

- `content_fixtures.dart` — `testGrunt`, `testRunner`, `testRanger`,
  `testEnemyCatalog`, `testTowerCatalog`, `testLevel`, `testBundle`
- `map_fixture.dart` — `testMap`
- `gameplay_harness.dart` — `pumpGameplay(tester, bundle: ...)`
- `pump_app.dart`, `pump_until.dart`, `stub_asset_bundle.dart`

### Style

Drive the simulation in game-loop-sized frames, the way the engine does:

```dart
void _run(LevelSession session, double seconds) {
  const step = 1 / 60;
  for (var elapsed = 0.0; elapsed < seconds; elapsed += step) {
    session.advance(step);
  }
}
```

Assert the exact rule, not the absence of an effect:

```dart
expect(result.blocker, TowerBuildBlocker.insufficientGold);
expect(result.missingGold, 20);
expect(session.gold, 150);            // unchanged
```

Test frame-rate independence for anything time-based:

```dart
final sixty = timeToFirstLeak(1 / 60);
final thirty = timeToFirstLeak(1 / 30);
expect((sixty - thirty).abs(), lessThan(0.02));
```

For the game loop, `pumpAndSettle` never settles — pump a few frames instead.

---

## 8. Procedure

1. **Read** the phase criteria, the design rules and ADR 0001.
2. **Decide the layer** for each part of the change (§3). If a rule cannot be
   expressed without a renderer, it belongs in the domain.
3. **Implement in the domain** first, with the rule expressed as a plain method
   on `LevelSession` or a focused system beside it.
4. **Write the domain test** in the same change. If the rule cannot be tested
   without a widget, stop and move it down a layer.
5. **Expose the outcome** through `LevelSession` → `LevelController` →
   `LevelHudState` if the player needs to see it.
6. **Render it** in a Flame layer that reads the session.
7. **Present it** in the Flutter UI, which reads the controller and never
   mutates state.
8. **Update the docs** — GAME_DESIGN rules, the decisions log (§14) for any
   deviation from PLAN.md, CONTENT_AUTHORING if a data format changed, README
   phase status.
9. **Run the gates:**

```bash
dart format --line-length 80 lib test
flutter analyze
env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy flutter test
```

The `env -u` prefix is required in the sandboxed IDE shell — the proxy
variables intercept `flutter_tester`'s local WebSocket and every test fails with
`Unable to connect to flutter_tester process`. `flutter analyze` works either
way.

10. **Report** what was built, the test results, the remaining risks and the next
    phase's prerequisites.

---

## 9. Review checklist

Before calling a feature done:

- [ ] The domain layer imports no Flutter or Flame.
- [ ] No gameplay rule was added to a Flame component.
- [ ] No wall-clock timer or `DateTime.now()` in the domain.
- [ ] Gold operations are atomic; refusals leave state untouched.
- [ ] Refusals are typed and asserted exactly in tests.
- [ ] Each enemy resolves once; reward once.
- [ ] Results are frame-rate independent, and tested so.
- [ ] New HUD fields are in `==`, `hashCode` and `toString`.
- [ ] The renderer reads live session state rather than caching it.
- [ ] The UI never shows success before the domain operation succeeded.
- [ ] `flutter analyze`, `dart format` and `flutter test` are clean.
- [ ] GAME_DESIGN, the decisions log, CONTENT_AUTHORING and README were updated
      where behaviour or formats changed.
- [ ] No later-phase feature was implemented opportunistically.
