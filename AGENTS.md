# AGENTS.md — Working in UpTowerDefense

Offline-first 2D tower defense for Android and iOS, built with Flutter and Flame.
No account, no server, no network access on any gameplay path.

This file is the operating contract for coding agents working in this repo. It
records the rules that are easy to break and expensive to debug. When it disagrees
with the code, the code is wrong — fix it, or fix this file in the same change.

| | |
|---|---|
| Stack | Flutter 3.47.8 · Dart 3.13.7 · Flame 1.38.2 |
| Shell | Riverpod 3.4.3 · go_router 18.1.1 · shared_preferences 2.5.6 |
| App ID | `com.uptowerdefense.game` |
| Orientation | Landscape gameplay; menus adapt to portrait and landscape |
| Phase status | **Phases 0–11 complete; Phase 12 automated half done; Phase 13 (release prep) in progress; V2-0 in progress** — Phase 12 added the QA scenario doc, restart/navigation leak tests, paired stress frame-cost tests (simulation + effects) and a splash broad-phase optimization; its manual device pass is still outstanding. Phase 13 so far: release signing via `android/key.properties`, launcher icons, dark splash, store listing + release checklist docs, package-licence audit and a repository-level save-upgrade test; release APK and iOS simulator builds verified. Haptics are wired for builds, upgrades and leaks (D71). V2-0 updated the toolchain to Flutter 3.47.8 / Dart 3.13.7 and refreshed host-side performance baselines; physical-device QA and graphics/memory profiling remain outstanding. Signed store uploads and the iOS archive/TestFlight path still need developer accounts. |

---

## 1. Source of truth

Read these before changing behaviour. They are ordered by authority.

| Document | Authority over |
|---|---|
| [`PLAN.md`](PLAN.md) | Product scope, phase sequencing, acceptance criteria |
| [`docs/V2_PLAN.md`](docs/V2_PLAN.md) | v2 scope, phases V2-0 to V2-6, save/version policy |
| [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md) | Game rules, and the decisions/deviations log (D1–D21) |
| [`docs/adr/0001-flutter-flame-layer-boundaries.md`](docs/adr/0001-flutter-flame-layer-boundaries.md) | Layer boundaries — accepted, not negotiable |
| [`docs/CONTENT_AUTHORING.md`](docs/CONTENT_AUTHORING.md) | JSON content formats and validation rules |
| [`docs/ASSET_ATTRIBUTIONS.md`](docs/ASSET_ATTRIBUTIONS.md) | Required record for every external asset and package licence |
| [`docs/QA_SCENARIOS.md`](docs/QA_SCENARIOS.md) | Phase 12 manual QA pass: repeatable scenarios and sign-off |
| [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md) | Release gates, signing setup, upgrade verification, rollback/patch procedure |
| [`docs/STORE_LISTING.md`](docs/STORE_LISTING.md) | Store copy, privacy and age-rating answers, screenshot plan |

**Every intentional deviation from PLAN.md gets a row in the GAME_DESIGN decisions
log** (§14), with the reason and the phase it applies to. Adding a rule without
logging it is an incomplete change.

---

## 2. Architecture — the one rule that matters

Five layers, one direction of dependency (ADR 0001):

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

- **Domain code imports no Flutter and no Flame.** `lib/features/gameplay/domain/**`
  must not import `package:flutter/*` or `package:flame/*`, and must not read
  screen dimensions. Use `package:meta` for `@immutable`.
- **Flame components are never the source of truth** for gold, level outcome,
  upgrade costs, or campaign unlocks. They read the session and draw it. If a
  gameplay decision appears in a component, it belongs in the domain layer.
- **Rendering never touches saves or unlocks.**
- **Definitions are immutable and shared**; runtime state lives in separate
  objects (`TowerInstance`, `EnemyState`) and is never written back into a
  definition.
- **Time enters the simulation as an explicit `dt`.** Nothing in the domain layer
  reads wall-clock time.
- **Per-frame entity state never flows through global UI providers.** The HUD
  subscribes to coarse, intentionally published values only.

A gameplay rule added to a Flame component is a review rejection, not a style
nit.

---

## 3. Simulation invariants

These are the rules that break silently when violated. Each has a test; keep the
test.

- **One clock.** The domain advances only through `LevelSession.advance(dt)`.
  Never use `Timer`, `Future.delayed`, or `DateTime.now()` for gameplay timing.
- **Frame deltas are clamped.** `UpTowerDefenseGame.maxFrameDelta = 0.1`. A
  lifecycle hiccup must slow the game down, never teleport an enemy past a tower
  or deliver a whole wave at once.
- **Spawn timing is frame-rate independent.** An enemy spawned mid-frame starts
  at its exact route progress (`speed × activeFor`) and skips that frame's
  movement, so spawn cadence never grants a free step.
- **Each enemy resolves exactly once.** Removal from the active list is what makes
  the death event, the kill reward and the leak penalty fire once. Never pay a
  reward outside the single resolution path.
- **Economy operations are atomic.** Deduct gold only after every rule passes.
  A refused build leaves gold and pad occupancy untouched. The build panel reads
  occupancy and gold from the session on every build, so it can never show an
  option for a pad that was just filled.
- **Refusals are typed, not logged.** Return a reason (`TowerBuildBlocker`) so the
  UI can explain a disabled option and tests can assert the exact rule.
- **Stats come from the instance, never the definition's base level.** Cooldowns,
  the range check, the drawn range circle and the panel all read
  `TowerInstance.stats`; reading `definition.baseStats` in any one of them makes
  an upgrade cosmetic in that place only, which is the hardest kind of bug to
  notice.
- **Waves never overlap.** The next wave is available only when no wave is
  active and no wave remains.
- **Phase changes go through the transition table.** `LevelSession._enterPhase`
  asserts `LevelPhaseTransitions`; a new phase change needs an edge there and a
  test, not an ad-hoc assignment. A terminal phase consumes no time and holds no
  spawns or shots, so a late frame cannot move a finished level or pay a second
  reward.
- **Pause withholds time; speed scales it.** Neither reaches the domain. The
  controller multiplies the frame delta, returns it, and the game feeds the same
  value to the effect layer, so pause freezes effects and 2x speeds them up.
- **The UI never reports success before the domain operation succeeds.**
- **Pausing freezes every simulation-bound timer**, and status effects expire in
  simulation time.
- **Gold is an integer.** No floating-point currency arithmetic.

---

## 4. Coding conventions

- **Imports:** `package:up_tower_defense/...`, never relative paths, per
  `flame_lint`.
- **Formatting:** `dart format --line-length 80 lib test tool`. The repo is
  formatted at 80 columns; match it.
- **Analysis:** `flame_lint` with `strict-casts`, `strict-inference` and
  `strict-raw-types` enabled. Fix warnings rather than suppressing them. A
  suppression that is genuinely required gets a comment on the line explaining
  why.
- **Doc comments:** every public class and non-obvious member carries a `///`
  comment that explains *why*, not *what*. Existing code does this consistently —
  match its voice.
- **Immutability:** content definitions (`TowerDefinition`, `EnemyDefinition`,
  `LevelDefinition`, `MapDefinition`) are immutable and shared. Mutable runtime
  state is a separate type.
- **No god objects.** Split a system when it owns two responsibilities. Introduce
  an abstraction when a *second* real use case appears — not before.
- **No package without a stated reason** for why the SDK or an existing package
  is insufficient.
- **Naming:** `snake_case` for files, types and members; `PascalCase` for types;
  `SCREAMING_SNAKE_CASE` for constants.
- **Comments explain intent and trade-offs.** Do not narrate what the next line
  obviously does.

---

## 5. Content authoring

Gameplay balance lives in JSON under `assets/data/`, never in widgets or combat
code. Tower costs, damage, ranges and enemy stats are tuned by editing data.

| Directory | Holds | Reference |
|---|---|---|
| `assets/data/campaign.json` | Region and level order, and each level's display name | `docs/CONTENT_AUTHORING.md` §Campaign |
| `assets/data/maps/` | One file per map | §Maps |
| `assets/data/enemies/` | `enemies.json`, the shared catalog | §Enemies |
| `assets/data/towers/` | `towers.json`, the shared catalog | §Towers |
| `assets/data/levels/` | One file per level | §Levels |

Rules that matter:

- **Validation reports every problem at once**, not just the first, so an author
  fixes a file in one pass.
- **Dangling references fail at load**, not at spawn time. `LevelRepository`
  resolves the map, enemies and towers into one validated `LevelBundle` before a
  session exists.
- **Every shipped file is loaded by `test/unit/content_assets_test.dart`.** That
  test is the content gate: a malformed file fails the test run, not a player's
  session. Run it after every content edit.
- **Balance edits follow the tuning workflow** in `docs/CONTENT_AUTHORING.md`
  ("Tuning workflow"): validate → probe → read the outcome table against its
  order-matched control → run `balance_regression_test` → update its pinned
  table in the same change as the data.
- **A new map must be registered** in `ContentCatalog.mapAssetsById`, or the
  catalog test fails because the catalog must list every shipped map.
- **A new level must be added to the campaign.** A level id is its file name, and
  `campaign_assets_test` asserts the campaign lists exactly the level files that
  ship — an unreachable level is a test failure, not a hidden level.
- **The campaign's level name must match the level file.** The picker reads the
  name from the campaign so it does not load ten bundles; the content test and
  `tool/validate_content.dart` both fail when the two drift.
- **Coordinates are world units, never pixels.** The camera renders a fixed
  resolution per map and letterboxes off-ratio screens.
- **A new level must leave the player able to build.** The content test asserts
  each level's starting gold can afford at least one tower.
- **Keep JSON ASCII, 2-space indented, one object per line.**
- **Every external asset is recorded** in `docs/ASSET_ATTRIBUTIONS.md` before it
  ships. Do not ship assets with unclear licences.

---

## 6. Commands

```bash
flutter pub get
flutter analyze                                    # static analysis (flame_lint)
flutter test                                       # unit + widget tests
dart format --line-length 80 lib test tool       # formatting (incl. the tool)
dart run tool/validate_content.dart                # every shipped asset, from disk
flutter build apk --debug                          # Android debug APK
flutter build ios --simulator                      # iOS simulator app
```

All three of `analyze`, `test` and `format` must pass before a phase is done.

**Environment gotcha:** in the sandboxed IDE shell, `HTTP_PROXY`/`HTTPS_PROXY`
are set and they intercept `flutter_tester`'s local WebSocket, so `flutter test`
fails with `Unable to connect to flutter_tester process: WebSocketException:
Invalid WebSocket upgrade request`. This is an environment problem, not a code
problem. Run the suite with the proxy unset:

```bash
env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy flutter test
```

`flutter analyze` is unaffected and works with the proxy set.

---

## 7. Testing

| Kind | Location | Covers |
|---|---|---|
| Unit | `test/unit/` | Content decoding and validation, campaign order and progress, geometry, session simulation, combat, level flow, economy, controller, settings, save codec and repository, offline guard |
| Widget | `test/widget/` | Navigation, settings, map selection, build flow, HUD, pause/speed/restart, result flow, level picker |
| Integration | `test/integration/` | Multi-screen flows (campaign → level → result → next), one flow per file |

Conventions:

- **Domain tests never pump a widget.** They construct state and call systems
  directly. A domain rule that can only be tested through a renderer is a rule in
  the wrong layer.
- **Fixtures live in `test/helpers/`** — `content_fixtures.dart` defines the
  test enemy/tower/level catalog, `map_fixture.dart` the test map,
  `gameplay_harness.dart` pumps the gameplay screen with an injected game.
  Reuse them instead of inventing new ones per test file.
- **Drive the simulation in game-loop-sized frames** (`1/60`) via a `_run`
  helper, the way the engine does.
- **Assert the exact rule, not the absence of an effect.** A test that only
  checks "nothing happened" passes when the rule is broken in the other
  direction.
- **Test frame-rate independence** for anything time-based: assert the outcome at
  `1/60`, `1/30` and a coarse step agree.
- **The game loop never settles** in widget tests — pump a few frames instead of
  `pumpAndSettle`.
- **Guard tests are load-bearing.** `content_assets_test.dart`,
  `offline_guard_test.dart` and `balance_regression_test.dart` fail the build
  when content, platform config or campaign balance breaks. Do not weaken them
  to make a change pass.

---

## 8. Offline promise

- The **release** Android manifest declares **no permissions**. Debug and profile
  manifests keep `INTERNET` only so the Flutter VM service can attach.
- No gameplay path calls a network or account API.
- Keep network dependencies out of the core loop. If a feature needs the
  network, it does not belong in the MVP.

---

## 9. Working a phase

`PLAN.md` §8 defines Phases 0–14 with deliverables and acceptance criteria. Do
not start a later content-heavy phase while an earlier phase's acceptance
criteria are failing.

For each phase:

1. **Inspect the repo before editing.** It is not empty; Phases 0–8 are done.
2. **Read the phase's acceptance criteria** in PLAN.md and the matching rules in
   GAME_DESIGN.md.
3. **Implement the smallest vertical slice** that proves the feature end to end.
4. **Add or update tests alongside the implementation**, not after.
5. **Update the docs in the same change:** GAME_DESIGN rules, the decisions log,
   CONTENT_AUTHORING formats, README phase status.
6. **Run format, analyze and test.** Fix failures; do not suppress warnings.
7. **Report** what was completed, the test results, the remaining risks, and the
   next phase's prerequisites.

**Do not implement later-phase features** unless explicitly requested or needed
to unblock the current phase. The plan is explicit about this: finish one
polished vertical slice before producing more content.

### Definition of done

A phase is complete only when all of these hold:

1. The phase's deliverables exist and can be demonstrated.
2. The acceptance criteria in PLAN.md are met.
3. Relevant automated tests pass.
4. `flutter analyze` and `dart format` are clean.
5. No new critical error or resource leak is known.
6. README and design docs are updated where behaviour, setup or architecture
   changed.
7. The app is runnable from a clean checkout.

---

## 10. Layout

```text
lib/
  main.dart                     bootstrap: settings load + provider container
  app/                          shell: router, routes, theme, orientation policy
  core/constants/               app identity constants
  features/<feature>/
    domain/                     plain-Dart models, systems, validation
    data/                       JSON decoders, repositories, content catalog
    application/                providers, controllers, session coordination
    flame/                      game entry point, layers, rendering, hit testing
    presentation/               screens, HUD, panels
  shared/layout/                responsive menu frame
assets/data/                    campaign, maps, enemies, towers, levels (JSON)
tool/                           development content validator (pure Dart)
test/
  helpers/                      fixtures and harnesses
  unit/  widget/  integration/
docs/                           design, ADRs, content authoring, attributions, QA scenarios
```

Create a folder when it holds real code. Do not add empty abstractions ahead of
a phase that needs them.

<!-- trail:start -->
## Trail — repo context graph

This repo is indexed in `.trail/cache/`: small linked markdown nodes that explain each
system and carry exact file:line spans, kept in sync with the code through git.

For ANY task here — understanding how something works, finding where code lives,
or scoping a change — get context from the graph before grepping or opening
source files. Re-ask freely (it's cheap) and reuse literal identifiers you
already have (symbol, error string, file name) as the query. New to this repo?
Run `trail map` first — a token-budgeted orientation (dir clusters, hubs,
hotspots), no LLM, no key.

- Run `trail ask "<your question>" --source` → ranked nodes with the relevant
  code spans inlined (each hit's ≤8-line crux by default; `--full` for whole
  definitions when the crux isn't enough). Match the tool to the task shape:
  for understanding or editing, the top node IS the answer — cite its
  `covers:` file:line spans and edit straight from `--source`. For
  exhaustive tasks ("every occurrence / every caller of this pattern"), ranked
  results are top-N, not complete — run `trail grep "<literal>"` instead
  (exhaustive over indexed files, grouped by enclosing symbol), falling back
  to raw `grep -rn` only for unindexed files.
- `trail skeleton <file>` → every definition's signature + span, ~10× cheaper
  than reading the file; use it to skim an API surface.
- `trail callers <symbol>` gives precomputed, exact edges — who calls this.
  Add `--direction out` for what it calls, or `--depth N` to walk
  transitively for the full blast radius. For structural questions, skip
  ranking and use this directly.
- Or browse: `.trail/cache/INDEX.md` lists every node; follow the links.
- Monorepos and folders of multiple repos rank fairly across sub-projects —
  hits carry `[scope/]` labels naming which one they're from. Narrow with
  `trail ask "<task>" --in <scope>/` once you know where you're working.

If a returned span is truncated ("+N more lines"), open the file at that exact
range before finalizing. Only open source files when a node genuinely lacks a
needed detail, and then at the exact file:line the node points to — never
re-read whole files.

After big code changes, refresh the graph with `trail build` (deterministic,
no API key, $0).
<!-- trail:end -->
