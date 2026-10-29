# UpTowerDefense — Game Design

**Status:** Baseline confirmed in Phase 0. Rules here are the implementation
reference for gameplay code and tests.
**Source of truth:** This document records the game rules; [`PLAN.md`](../PLAN.md)
remains the product and phasing plan. When the two disagree on a rule, fix the
disagreement here first, then in code.

---

## 1. Product summary

A single-player, offline-first 2D tower defense game for Android and iOS built
with Flutter and Flame. The player defends an energy core along a fixed route by
building and upgrading towers on predefined build pads, clearing successive
waves while ascending a campaign of regions.

Nothing in the gameplay path may require a network connection, an account, or a
remote service. All content, progression, and saves live on the device.

### Design pillars

1. **Readable tactics** — towers, enemies, projectiles, ranges, status effects,
   and warnings stay distinguishable on a phone screen.
2. **Fast decisions** — building, upgrading, selling, pausing, and speed changes
   take very few taps.
3. **Earned progression** — regions and upgrades are unlocked by playing; no
   pay-to-win mechanics in the initial release.
4. **Replay value** — optional objectives, ratings, and multiple viable tower
   mixes.
5. **Offline by design** — no gameplay path blocks on connectivity.

---

## 2. Scope

### In scope for the initial release (MVP)

- Main menu, level select, settings, credits.
- A campaign of at least 10 hand-authored levels across 2 regions.
- Fixed-route maps with predefined build pads; placement never affects pathing.
- Three tower types (Ranger, Cannon, Frost) with upgrades and selling.
- Three basic enemy types (Grunt, Runner, Brute) plus a region boss.
- Data-driven towers, enemies, waves, maps, levels, rewards, and objectives.
- Full combat, economy, wave, victory/defeat, pause, restart, and 1x/2x speed.
- Local campaign progress, settings, and best results.
- Sound effects, optional music, animation, and impact feedback.
- Automated unit, widget, and integration tests for the core loop.

### Explicitly out of scope until after release

Multiplayer/PvP/co-op/clans/chat, leaderboards, cloud saves, server APIs,
mandatory sign-in, purchases/ads/loot boxes, user level editor, procedural
campaign maps, 3D or physics-heavy simulation, user-generated content, and
remote configuration.

---

## 3. Platform and orientation

- Targets: current supported Android and iOS devices (minimum OS versions are
  fixed in Phase 13 against the then-current Flutter toolchain).
- Gameplay orientation: **landscape**. Menus must adapt to aspect ratios and
  safe areas rather than assuming one screen size.
- The game world uses its own logical coordinate space, independent of physical
  pixels, and is converted to screen coordinates consistently.

---

## 4. Core loop

1. Player opens a level and sees the map, core health, starting gold, and
   available towers.
2. Player spends gold to build towers on valid build pads.
3. Player starts the next wave (manual start for the MVP; see §14).
4. Enemies spawn in configured groups and follow the route to the core.
5. Towers acquire targets and attack using range, cooldown, damage, and target
   priority.
6. Kills grant gold; enemies reaching the exit damage the core.
7. Between waves the player builds, upgrades, sells, and adjusts priorities.
8. The level ends on victory (all waves cleared) or defeat (core health zero).
9. A result summary grants rewards and unlocks; progress is saved locally.

---

## 5. Controls

- Tap a build pad → build selection panel with costs and affordability.
- Tap a tower → detail panel (stats, upgrade, target priority, sell).
- Tap the selected object again, or empty ground, to dismiss the panel.
- Pause/resume is always reachable during gameplay.
- Speed: 1x and 2x for the MVP (`3x` only after performance and balance tests).
- Simulation pauses while the app is inactive or a blocking dialog is open.
- Touch targets stay large and states (selected, disabled, unaffordable) are
  visually explicit.

---

## 6. Level state machine

States: `loading`, `ready`, `playing`, `waveTransition`, `paused`, `victory`,
`defeat`, `disposed`. Illegal transitions are rejected (for example, no spawning
from `defeat`). State is modelled as an enum or sealed type, never as a
collection of ad-hoc booleans.

Implemented (`LevelPhase`): `ready`, `playing`, `waveTransition`, `victory`,
`defeat`. `paused` is deliberately **not** a phase: pause freezes the clock
rather than the level's rules, so it lives in the controller and the engine, and
a paused level is simply a level that receives no time.

`LevelPhaseTransitions` holds the legal moves and `LevelSession` routes every
change through one assert-guarded entry point, so an illegal move fails a test
instead of leaving a level that can never progress:

| From | May move to | When |
|---|---|---|
| `ready` | `playing` | the first wave starts |
| `playing` | `waveTransition` | a wave is cleared and waves remain |
| `playing` | `victory` | the last wave is cleared |
| `playing` | `defeat` | core health reaches zero |
| `waveTransition` | `playing` | the countdown ends, or the player starts early |

`victory` and `defeat` are terminal. Entering either clears the spawn queue and
every shot in flight, and later frames are ignored, so a host that outlives the
attempt cannot move a finished level ([D28](#14-decisions-and-deviations-log)).

### Victory and defeat

- **Victory:** every configured wave has spawned, every enemy is resolved, and
  no enemy is active or pending.
- **Defeat:** core health reaches zero.
- Each outcome is emitted exactly once per attempt, even if several callbacks
  fire in the same frame.
- Restart resets transient level state and preserves campaign data saved before
  the attempt.

---

## 7. Economy

- Currency is integer gold; no floating-point currency arithmetic.
- Gold comes from kills. A level sets `startingGold`; an enemy sets
  `rewardGold`, paid exactly once when it is defeated. An enemy that leaks pays
  nothing, so a leak costs core health *and* income.
- Finishing a level grants a star rating, not gold: gold is per-attempt and
  resets with the level, so a carry-over reward would need a meta currency the
  MVP does not have ([D39](#14-decisions-and-deviations-log)).
- Building and upgrading consume gold; the operation is atomic (deduct only
  when the action succeeds). A refused build — unknown pad, occupied pad, not
  enough gold, level already over — leaves gold and occupancy untouched.
- A pad holds at most one tower, and the pad id is the occupancy key.
- Selling refunds a configurable share of total invested gold; default **60%**.
- Costs, rewards, and refund rates come from data definitions, never from
  scattered constants or widgets.
- The UI shows cost, refund, damage, range, attack speed, and effect changes
  before the player commits. The UI never reports success before the domain
  operation succeeds.

---

## 8. Waves

- A level holds ordered wave definitions; a wave holds one or more spawn groups.
- A spawn group defines enemy ID, count, interval between spawns, and optional
  initial delay.
- Waves run in deterministic order; the next wave becomes available only when
  the current wave is complete.
- Waves do not overlap in the MVP.
- The MVP starts waves automatically: a cleared wave holds a countdown
  (`waveTransitionSeconds`, level data) and the next wave then arrives on its
  own. The HUD control starts it early and is disabled while a wave runs, so a
  wave can never be skipped or double-started
  ([D29](#14-decisions-and-deviations-log)).
- Starting early carries **no** gold bonus in the MVP: a bonus is a balance rule
  with no tested shape yet, and overlapping waves stay post-MVP.
- Groups inside a wave spawn on their own offsets from the wave start, so one
  wave can mix cadences without extra rules.
- A wave completes only after all its enemies have spawned **and** all of them
  are resolved (killed or leaked).
- Spawn timing uses simulation time so pause and game speed affect it
  consistently. Overlapping waves and "start next wave early" bonuses are
  post-MVP.

---

## 9. Movement, targeting, combat

### Pathing

- Each map is an ordered, validated waypoint list.
- Enemies advance along the route by simulation time, consistent across frame
  rates and speed multipliers.
- Reaching the endpoint emits exactly one leak event and removes the enemy from
  active combat.

### Targeting

- MVP policies: **First** (furthest along the route) and **Strongest** (highest
  current health).
- Tie-breaking is deterministic so tests are stable.
- A tower reacquires a valid target when its current target dies or leaks; it
  never retains a disposed entity.
- Implemented in Phase 5: `TargetingSystem.acquire` scans only live enemies
  inside the tower's range and applies the tower's policy — First from Phase 5,
  Strongest from Phase 6 — breaking ties on the lower instance id. Targeting is
  recomputed from the live enemy list rather than cached, so a dead or leaked
  enemy can never stay selected.

### Projectiles and hits

- A shot is simulation state (`ProjectileState`), advanced by `LevelSession`
  with the same delta as everything else, so whether a hit lands never depends
  on frame rate.
- Each frame a live shot re-aims at its target's current position; it lands when
  it reaches the target's body radius. If the target was resolved meanwhile the
  destination freezes at its last known position and the shot expires there with
  no effect, which is how target references are invalidated safely.
- A tower with no target fires nothing and spends no cooldown: it waits.
- The cooldown is charged in simulation time on fire, so pause and speed never
  desynchronise it.

### Damage and status

- All damage flows through one domain rule path; health clamps at zero and death
  dispatches exactly once.
- Implemented in Phase 5: `LevelSession._applyDamage` is that single path — it
  clamps health, then calls `reportEnemyDefeated`, which removes the enemy,
  pays `rewardGold` once and re-evaluates the level. A second hit on an already
  resolved enemy is a no-op, so several kills inside one update each pay once.
- Damage types exist only when a mechanic depends on them.
- Splash damage uses a fixed radius and fixed (non-falling-off) damage in the
  MVP.
- Implemented in Phase 6: `LevelSession._resolveHit` collects the target plus
  every enemy whose centre lies within `splashRadius` of the impact — boundary
  included — *before* any damage is applied, so a kill in the middle of the
  loop cannot change which enemies the blast reaches. Every victim takes
  exactly the shell's damage; there is no falloff ([D24](#14-decisions-and-deviations-log)).
- Frost slow has configured magnitude, duration, refresh/stacking rule, and a
  minimum speed cap; a level may also carry a **damage amplifier**: while the
  slow is active, every source deals its damage plus `damageAmp` against that
  target.
- Implemented in Phase 6: an enemy carries exactly one slow. A weaker hit is
  ignored outright — it does not even refresh the timer — so a weak tower
  cannot piggy-back a strong slow forever; an equal or stronger hit replaces
  the magnitude, takes its own speed floor and buys the full duration again.
  `EnemyState.currentSpeed` never drops below `speed × minSpeedRatio`, so a
  swarm of slow towers cannot freeze a target ([D25](#14-decisions-and-deviations-log)).
  The amplifier is read inside `_applyDamage` itself, so shots, splash and any
  future effect agree on whether it applied, and it stops with the chill it
  arrived with — `isSlowed` gates it, not the stored number.
- Rewards and leak penalties apply once per enemy.
- Status effects expire in simulation time and pause with the game.

### Timing

- Simulation delta time is clamped after lifecycle interruptions so enemies
  cannot teleport or waves instantly complete.
- On resume, the game pauses (or reconciles explicitly) instead of advancing on
  wall-clock time.
- Game speed multiplies simulation delta only; UI animation and system timers
  are not scaled indiscriminately.

---

## 10. Towers

| Tower | Role | Behavior | Tactical use |
|---|---|---|---|
| Ranger Tower | Fast single target | Moderate damage, high fire rate, low cost | Reliable early defense |
| Cannon Tower | Area damage | Slow projectile, splash damage, slow fire rate | Packed low-health enemies |
| Frost Tower | Control | A chill that spreads in a capped blast, plus a damage amplifier on chilled targets | Slows whole clusters of durable enemies and makes every other tower hit harder while the chill lasts |

Every tower definition carries a stable ID, localized name key, description/role,
build cost, refund policy, range, cooldown, allowed targeting policies, per-level
stats and upgrade costs, damage values, projectile/effect config, and asset/sound
references. A fourth tower is post-MVP.

Towers are placed on predefined build pads; two towers cannot share a pad and no
tower can be placed off-pad or on the route.

Implemented in Phase 4: the Ranger Tower, with its cost, range, cooldown and
colour read from `assets/data/towers/towers.json`, and build-pad occupancy owned
by `LevelSession`. Implemented in Phase 5: targeting, cooldowns, projectile
flight, damage and kill rewards, all driven from `LevelSession.advance` — the
tower panel's numbers and the combat numbers are literally the same fields.
Implemented in Phase 6: the Cannon Tower (fixed-radius splash), the Frost Tower
(capped slow), upgrade levels with per-level costs, selling against total
invested gold, and per-tower target priority (First / Strongest). Upgrades and
sells are transactional like builds: gold moves only after every rule passes,
and the refund is the definition's rate applied to build plus every upgrade,
floored to an integer ([D26](#14-decisions-and-deviations-log)).

Every stat is read from the tower's **current** level — the shot timer, the
range check, the drawn range circle and the panel all resolve through
`TowerInstance.stats`, never through the definition's base level. An upgrade
therefore changes behaviour and display together; reading the base stats in any
one of those places would silently make an upgrade cosmetic.

---

## 11. Enemies

| Enemy | Role | Behavior |
|---|---|---|
| Grunt | Standard | Balanced speed and health |
| Runner | Fast | Low health, high speed |
| Brute | Tank | High health, low speed |
| Region Boss | Boss | Higher health plus one simple special rule |

Enemy definitions support health, speed, armor/resistance, reward, core damage on
leak, visual variant, status resistance, and optional abilities. No general
ability framework is built until a real enemy requires one.

---

## 12. UX

### Screens

- **Main menu:** play/continue, level select, codex, settings, credits/legal. No
  login or connectivity check on first launch. **Play** opens the campaign's first
  unfinished level, so the one-tap path keeps working all the way through.
- **Campaign picker:** regions in play order, each level with its number, name and
  best star rating; locked levels say which level unlocks them. The list is
  paged at five levels per page in campaign order, with page controls and a
  "Levels 1–5 of 10" label, so a phone never has to scroll a long list. It
  opens on the page holding the first unfinished level (the last page once the
  campaign is cleared), and a flag button on the pager jumps back to that page
  after browsing. Totals
  (levels cleared, stars earned) sit above the list and always count the whole
  campaign. Tapping an open level opens it.
- **Gameplay HUD:** core health, gold, wave counter, pause/resume, 1x/2x speed,
  the next-wave countdown, build panel, tower panel, and clear feedback for
  invalid actions and leaks. HUD never covers critical route segments or makes
  pads hard to tap.
- **Pause overlay:** resume, restart and quit, with the field frozen behind it.
  Backgrounding the app pauses the same way, and a system resume never overrides
  a pause the player chose.
- **Tower detail:** name/level/role, damage, range, fire rate, active effect, next
  upgrade cost and changes, target priority, sell with refund.
- **Result summary:** outcome, waves cleared, remaining core health, kills, leaks,
  gold earned, the star rating earned, and replay/back-to-menu actions. A
  victory also delivers the unlock it just granted — the summary names the
  level that opened (`Unlocked: …`) in the subtitle slot, or says the campaign
  is complete, since the unlock *is* the reward (D39 keeps gold inside the
  attempt) — and its "Next level" action starts that level as a fresh attempt.
  A defeat offers replay and menu only.
- **Settings:** music/SFX volume and toggles, haptics, reduced motion, language
  (once localised), and reset progress with confirmation.

### Accessibility

Large touch targets, readable text, no reliance on colour alone (silhouettes,
icons, effects), visual equivalents for audio cues, safe-area respect,
reduced-motion support, and verified text scaling in menus. Every gameplay
fact carries both a drawing and a sound, and each can be turned off alone: the
SFX switch silences cues without hiding them, and the effects still say what
happened in a silent room. In gameplay, reduced motion holds every effect cue
at its first frame's size and position and keeps only the fade, so the cue
stays readable while the movement does not.

---

## 13. Content and persistence

- Towers, enemies, waves, maps, and levels are validated data definitions (JSON
  assets for the MVP), loaded locally with developer-readable diagnostics.
- Validation rejects bad IDs, dangling references, negative costs, non-positive
  health, invalid counts/intervals, and broken routes or pad IDs. A test loads
  every shipped definition.
- The campaign is authored data (`assets/data/campaign.json`): ordered regions,
  each holding ordered levels. The flattened order **is** the unlock order — a
  level opens once the one before it is completed — so regions pace the campaign
  without introducing a second unlock rule.
- A level's id is its file name (`assets/data/levels/<id>.json`). The campaign
  must list exactly the levels that ship: an unreachable level, a listed level
  with no file, and a duplicate id are all validation failures.
- Star rating is one fixed rule over one number the player can always see:
  finishing is 1 star, finishing with at least half the core is 2, finishing
  untouched is 3, and a defeat is 0. It is deliberately not per-level data, so
  every level explains itself the same way.
- Progress — the best result per level — is persisted in the versioned save.
  The unlock rule and the picker read the same shape they had while progress
  was in memory, so persistence changed neither of them.
- Saves are versioned JSON with `schemaVersion`; reads are validated, writes
  replace the stored payload only after the outgoing one has been copied aside,
  and incompatible data is migrated forward explicitly or recovered safely —
  never silently reinterpreted.
- One document holds campaign progress (unlocks, results, best ratings) and
  settings, so there is one schema version, one migration path and one backup
  for everything a relaunch needs.
- Saves happen after a level finishes, after a reset and on settings updates —
  never per frame. Both writers share one document and one write queue, so their
  updates cannot interleave into a half-written save.
- A load never writes. An unreadable payload is preserved first, the backup is
  tried second, and only then does the session start on defaults.
- If saving or parsing fails, the game keeps running with safe defaults, reports
  the issue on the menu and in Settings, and keeps the damaged payload for
  recovery. Settings always says where progress lives; the menu stays silent
  unless a load degraded, so the warning is the only line it ever adds to the
  first screen.
- Resetting progress is a confirmed action in Settings, and it leaves settings
  untouched — the two halves of a save are reset independently.

---

## 14. Decisions and deviations log

Record every intentional departure from [`PLAN.md`](../PLAN.md) here, with the
reason and the phase it applies to.

| # | Decision | Status | Notes |
|---|---|---|---|
| D1 | Stack is Flutter + Flame (Flame 1.38.2, Flutter 3.47.7, Dart 3.13.5) | Confirmed (Phase 0) | See `docs/adr/0001-flutter-flame-layer-boundaries.md`. |
| D2 | 2D, single-player, offline-first, landscape gameplay | Confirmed (Phase 0) | Applied at runtime in Phase 1: gameplay locks to landscape via `AppOrientation`, menus allow portrait and landscape and adapt to safe areas. |
| D3 | Tower placement restricted to predefined build pads | Confirmed (Phase 0) | Predictable pathing and better touch accuracy; free placement is post-MVP. |
| D4 | Wave start UX for the MVP | Confirmed (Phase 3) | Manual start via one HUD control; see D16. Phase 7 still adds the countdown, the start-early bonus and the result screen on top of it. |
| D5 | Local state management (Riverpod) and navigation (GoRouter or typed layer) | Confirmed (Phase 1) | `flutter_riverpod` 3.4.3 for state and dependency injection, `go_router` 18.1.1 for routing. Shell screens are nested under the main-menu route so the menu is always the root of the back stack. |
| D6 | Audio package | Confirmed (Phase 10) | `flame_audio` 2.12.2, installed after a compatibility review: it declares `flame: ^1.38.0`, so it fits the pinned Flame 1.38.2, and it wraps `audioplayers` for exactly the two jobs this game needs — one-shot SFX from bundled assets now, a looping music track later. Playback reads files shipped in the bundle, so it stays offline and needs no permission. |
| D7 | Internal app ID / bundle identifiers | Confirmed (Phase 0) | `com.uptowerdefense.game` for Android and iOS (`.RunnerTests` suffix for the iOS test bundle); public name, icon, and trademark check remain before release. |
| D8 | Phase 1 settings live in `shared_preferences`, not the campaign save | Superseded by D41 (Phase 9) | Preferences were non-sensitive key-value entries read once at bootstrap, behind the `SettingsStore` boundary. Phase 9 folded them into the versioned save so there is a single migration path; the boundary stayed, so no widget changed. |
| D9 | Settings shipped in Phase 1 are toggles only (music, sound effects, haptics, reduced motion) | Confirmed (Phase 1) | Volume sliders and language are added with audio (Phase 10) and localisation, so no control ships that has no visible effect. |
| D10 | Maps are authored JSON with a fixed world size, route, core and predefined pads | Confirmed (Phase 2) | World units are independent of screen pixels; the camera renders a fixed resolution per map and letterboxes off-ratio screens. Format and validation rules live in `docs/CONTENT_AUTHORING.md`. |
| D11 | Pad selection is screen-local state, not a global provider | Confirmed (Phase 2) | `MapSelection` is a `ValueNotifier` owned by the gameplay screen and disposed with it; it is event-driven, not per-frame simulation state (ADR 0001). |
| D12 | A map's core must sit on the route's final waypoint | Confirmed (Phase 2) | Enforced by `MapValidator` so "reached the end of the route" and "reached the core" can never disagree; relax if a later map needs an offset core. |
| D13 | Enemies, levels and waves are authored JSON resolved into one validated `LevelBundle` | Confirmed (Phase 3) | `LevelRepository` resolves the level's map and the shared enemy catalog before a session exists, so a dangling `mapId` or `enemyId` fails at load with a readable issue instead of at spawn time. Formats live in `docs/CONTENT_AUTHORING.md`. |
| D14 | Core health is level data; leak damage is enemy data | Confirmed (Phase 3) | A level sets `coreHealth`; each enemy sets `coreDamageOnLeak`, clamped at zero on the core. This keeps "how long the level lasts" and "what a mistake costs" independent knobs per level and per enemy type. |
| D15 | Simulation time is the only clock, and one frame advances at most 0.1 s | Confirmed (Phase 3) | `LevelSession` advances only through an explicit delta; the Flame loop clamps each delta to `maxFrameDelta` so a lifecycle hiccup cannot teleport enemies through towers or deliver a whole wave at once. |
| D16 | Waves start manually from the HUD, one at a time | Superseded by D29 (Phase 7) | Resolves D4. The control is enabled only when no wave is active and no wave remains, which also makes "waves never overlap" structural rather than a check to remember. Phase 7 replaced "manual" with "automatic after a countdown, startable early"; the no-overlap guarantee and the single control survived unchanged. |
| D17 | An enemy spawned mid-frame starts at its exact route progress and skips that frame's movement | Confirmed (Phase 3) | Spawn time is carried into the distance (`speed × activeFor`), so spawn cadence never grants a free step and arrival times stay identical at any frame rate. |
| D18 | Tower stats and costs live in one shared `towers.json` catalog | Confirmed (Phase 4) | Build cost, range, fire cooldown and damage all come from data, so the build panel, the tower panel and (from Phase 5) combat read the same numbers. Phase 4 ships the Ranger only; the catalog format already holds the rest of the roster. |
| D19 | Building is a single transactional session operation; the pad id is the occupancy key | Confirmed (Phase 4) | `buildTower` checks level state, pad existence, occupancy and gold in that order, and deducts gold only after all checks pass. Refusals return a typed reason (`TowerBuildBlocker`), so the UI can explain a blocked option and tests can assert the exact rule instead of the absence of an effect. |
| D20 | Kills pay gold from the enemy definition; leaks pay nothing | Confirmed (Phase 4) | `rewardGold` sits next to the enemy's health and leak damage, which keeps "what a kill is worth" and "what a leak costs" tunable per enemy. The reward is paid inside `reportEnemyDefeated`, the same single path combat will use in Phase 5, so it can never be paid twice. |
| D21 | Pad selection is the only selection state; an occupied pad swaps the panel to tower details | Confirmed (Phase 4) | Reusing the Phase 2 selection avoids a second "selected tower" source of truth that could disagree with occupancy. The panel reads occupancy and gold from the session every build, so it can never show a build option for a pad that was just filled. |
| D22 | Projectiles are session state that re-aim each frame and expire when their target is gone | Confirmed (Phase 5) | Homing keeps hits frame-rate independent and needs no prediction of a moving target. A shot whose target died flies to the last known position and expires without effect, so the reference can never dangle. Landing checks the target's body radius, so a shot disappears where it visibly meets the enemy. |
| D23 | Combat publishes facts; the Flame layer owns the effects that show them | Confirmed (Phase 5) | `LevelSession.drainCombatEvents()` emits shot/hit/defeated at world positions, and `FxLayer` decides their look and lifetime. Effects therefore respond to real outcomes (they cannot play for a shot that never happened) while staying out of the rules layer, per ADR 0001. |
| D24 | Splash is centre-to-centre, boundary-inclusive, and never falls off | Confirmed (Phase 6) | A Cannon shell damages its target plus every enemy whose centre lies within `splashRadius` of the impact, for the shell's full damage. Victims are collected *before* any damage is applied, so a kill in the middle of the loop cannot change who the blast reaches. Distance falloff was rejected for the MVP: it makes "did that enemy die?" unreadable on a phone. |
| D25 | An enemy carries exactly one slow, and weaker hits are ignored outright | Confirmed (Phase 6) | Equal-or-stronger hits replace the magnitude, adopt that hit's speed floor and buy the full duration again; a weaker hit does not even refresh the timer, so a cheap Frost tower cannot extend an expensive one forever. `EnemyState.currentSpeed` floors at `speed × minSpeedRatio`, so stacked slow towers can never freeze a target. One slow per enemy makes stacking impossible by construction rather than by a rule to remember. |
| D26 | Upgrades and sells are transactional, and the refund is a share of total invested gold | Confirmed (Phase 6) | `upgradeTowerAt` and `sellTowerAt` check level state, pad existence, occupancy, max level and gold before moving any gold, and return a typed blocker otherwise. `investedGold` accumulates build cost plus every upgrade, and the refund is `sellRefundRate × investedGold` floored to an integer — the panel previews `refundForInvested`, so the number shown and the number paid are the same call. |
| D27 | Status and blast size are drawn from the simulation, not approximated in the renderer | Confirmed (Phase 6) | A hit event carries the blast radius it was resolved with, so `FxLayer` draws exactly the circle the damage rule used, and `EnemyLayer` marks a slowed enemy with a frost ring plus three ticks. The ticks exist because colour alone must never be the only cue (see §12); both read from session state each frame, so they cannot drift from the rule. |
| D28 | The level flow is an explicit state machine with one guarded entry point | Confirmed (Phase 7) | `LevelPhaseTransitions` lists every legal move and `LevelSession._enterPhase` asserts it, so an illegal transition fails a test rather than stranding a level. Entering a terminal phase clears the spawn queue and the shots in flight, and `advance` consumes nothing outside `playing`/`waveTransition`, which is what makes "no duplicate result events" and "late timers cannot modify a finished level" structural. Pause is not a phase: it withholds time instead of changing the rules. |
| D29 | Waves start automatically after a per-level countdown, and the player may start early | Confirmed (Phase 7) | Supersedes D16. `waveTransitionSeconds` is level data (default 5 s) and the countdown runs on simulation time, so pause freezes it and 2x runs it at double speed. One HUD control covers all three cases — "Start wave", the live countdown (tap to start now), and a disabled "Wave in progress" — so there is still no way to skip or double-start a wave. No early-start gold bonus: it is a balance rule with no tested shape, and overlapping waves remain post-MVP. |
| D30 | Pause and speed act on the frame delta, not on the domain | Confirmed (Phase 7) | The domain never learns that a game can be paused or run at 2x: `LevelController.advance` multiplies the delta, returns it, and the game passes that same value to the effect layer, so 2x speeds effects up with the simulation and pause freezes both. The player's pause also pauses the engine; backgrounding pauses the engine on its own, and a system resume never overrides a pause the player chose. |
| D31 | Restart resets the session in place instead of building a new one | Confirmed (Phase 7) | The same game, camera, controller and HUD survive a replay, which is what keeps the injected-game test harness honest. Every transient field is reset in `LevelSession.restart`, and a test asserts the result is indistinguishable from a fresh session; the effect layer and pad selection are cleared by the game, which owns them. |
| D32 | The result summary reports run stats owned by the session | Confirmed (Phase 7) | `kills` and `goldEarned` are incremented only in `reportEnemyDefeated`, the single resolution path, so the panel cannot show a kill or a gold piece the simulation did not record. A leak pays nothing and counts no kill, which is what makes "gold earned" differ from "gold left". The star rating joined the panel in Phase 8. |
| D33 | The campaign is an authored ordered list, and that order is the unlock rule | Confirmed (Phase 8) | `assets/data/campaign.json` holds regions of levels; the flattened order decides what opens next, so regions are pacing and presentation only. One rule along one order means the picker, the validator and the "Play" entry point cannot disagree, and a gap in the campaign is impossible by construction. |
| D34 | A campaign level's id is its file name, and the campaign must list every shipped level | Confirmed (Phase 8) | `ContentCatalog.levelAssetFor(id)` derives the path, so there is no second registry to forget. `campaign_assets_test` asserts the campaign's ids equal the level files in the asset manifest, which turns "a level nobody can reach" and "a level with no file" into test failures instead of player reports. |
| D35 | Stars are one global rule over core health, not per-level data | Superseded by D68 (v2) | Finish = 1, finish with at least half the core = 2, finish untouched = 3, defeat = 0. A player can predict the rating before the last wave from the HUD, and every level explains itself identically. Per-level objectives would need their own authoring format and explanation; they stay post-MVP. |
| D36 | The campaign carries each level's display name | Confirmed (Phase 8) | The picker renders ten levels without loading ten bundles (each of which pulls a map and both catalogs). The duplication is guarded: `campaign_assets_test` and `tool/validate_content.dart` both fail when the campaign name and the level file disagree. |
| D37 | Campaign progress is in memory for Phase 8 | Superseded by D40 (Phase 9) | `CampaignProgress` was kept immutable and shaped exactly as it would be serialised, so persistence was a repository away and the unlock rule and the picker never changed. Phase 9 added that repository; the type is untouched. |
| D38 | The content validator ships as a terminal tool as well as a test | Confirmed (Phase 8) | `dart run tool/validate_content.dart` decodes and validates every shipped file from disk, including the campaign cross-checks, without Flutter or an emulator. `campaign_assets_test` covers the same ground through the asset bundle and is the gate that runs with the suite; the tool is the fast loop for authors. |
| D39 | Level completion grants stars, not gold | Confirmed (Phase 8) | Gold is per-attempt and resets with the level, so a completion payout would have nowhere to go without a meta currency. The result therefore records stars and the best run, and the economy stays closed inside one attempt. A carry-over currency, if it is ever wanted, is a post-MVP design with its own sink. |
| D40 | The save is one versioned document under three preference keys | Confirmed (Phase 9) | `save.current`, `save.backup` and `save.damaged` live in `shared_preferences`, the storage this project already ships. A temporary file plus rename was rejected: it would add `path_provider` for a property key-value storage already gives us — each write copies the outgoing payload to the backup key *first*, so the newest save is never the only copy, and the platform persists each key atomically. |
| D41 | Settings are folded into the versioned save | Confirmed (Phase 9) | Completes D8: `{schemaVersion, results, settings}` is written by one repository through one write queue, so preferences and progress can never be stored as different generations of the format. `SettingsStore` still fronts the settings screen — its production binding is now `SaveBackedSettingsStore`, while `SharedPreferencesSettingsStore` is what a version 1 save migrates from. |
| D42 | A load never writes: current → backup → defaults, damaged data kept | Confirmed (Phase 9) | An unreadable payload is preserved to `save.damaged` before anything can replace it, then the backup is tried, and only then does the session start empty, with the outcome shown on the menu and in Settings. That ordering is what makes "an invalid save does not silently overwrite a good backup" a structural property rather than a promise. |
| D43 | Resetting progress lives in Settings, behind a confirmation | Confirmed (Phase 9) | The picker is where levels are opened, so a destructive control there would sit beside the thing it destroys. Settings already owns preferences, and the dialog says which half survives: progress is erased, settings are kept. |
| D44 | The campaign summary line is shared, and the menu shows it too | Confirmed (Phase 9) | `CampaignSummary` renders "N of M levels cleared · S of T stars" for both the picker and the main menu, so two screens can never count differently. The menu earns it: a returning player's first question is how far they got, and answering it before they open the picker is one fewer tap. It renders nothing while the campaign is still loading, so a screen never shows a total it cannot back up. |
| D45 | Gameplay facts are published as level events, and refusals publish nothing | Confirmed (Phase 10) | `CombatEvent` became `LevelEvent`: the queue now carries build and upgrade placements beside shot, hit, defeat and leak, because every cue a player needs originates in a rule the session already resolved. A refused build or upgrade publishes nothing — nothing happened — so effects and audio can only answer real outcomes, and the Flame layer stays a consumer of facts (ADR 0001). |
| D46 | Effects are bounded, shape-distinct and motion-optional | Confirmed (Phase 10) | At most 64 cues live at once, oldest dropped first, each a thin translucent stroke, so a multi-kill burst cannot paint over the enemies it describes. Every kind has its own silhouette (ring, double ring with ticks, closing reticle, rising chevrons) so it reads in greyscale, and reduced motion freezes geometry at the first frame while the fade still runs — accessibility removes motion, never information. |
| D47 | Sound cues come from the same level-event queue, one per kind per frame | Confirmed (Phase 10) | The SFX layer consumes the facts the effect layer draws, so audio and animation can never disagree about what happened, and a two-method sink interface keeps the cue rules plain Dart — the offline guard and the unit tests never touch an audio platform. Events coalesce to one cue per kind per frame (six kills at once is one sound, not a machine gun), the switch is read once when the game is built, like reduced motion, and playback failures are discarded: audio is cosmetic and must never break the frame that reported a kill. |
| D48 | Entities and the field draw CC0 sprites keyed by definition id; pads, the core and effects stay vector | Confirmed (Phase 10) | `assets/images/` carries Kenney's *Tower Defense (Top-Down)* art cropped to each sprite's own bounds, so one size constant fits every tower and enemy: identity comes from the art (`tower_<id>.png` per shipped definition, guarded by a test) instead of a body colour, which is what the greyscale rule asked for. The field repeats two tiles as shaders locked to world units, washed back into the dark palette. Pads and the core stay vector because they carry state (selection, health) measured from the map definition, and effects stay vector because D46 already made them the production design — a cue set that must be legible at any size, not a sheet of frames. |
| D49 | One app-wide music loop follows the music switch | Confirmed (Phase 10) | A single CC0 loop plays under the menus and the levels alike, started, stopped and restarted only by the persisted switch, through a two-method sink so the controller stays plain Dart and the tests never touch an audio platform. In-game pause leaves the music on: pausing is a choice about the simulation, not about the room; only backgrounding the app silences it, which `flame_audio`'s lifecycle observer already owns. Booting with the switch off never touches playback, so a player who muted the game never hears a blip at launch. |
| D50 | Loudness sliders complete D9: each channel's volume is a 0..1 multiplier, gated by its switch | Confirmed (Phase 10) | Each slider sits under its switch and disables with it, so a muted channel never promises an effect the switch already vetoed; both values persist with the rest of the settings, and saves written before the sliders fall back to full. Music retunes the running loop live through the same controller that owns the switch (D49), while SFX is read once when the attempt's game is built — the same rule as the switch itself (D47) — and multiplies the per-cue volumes instead of replacing them, so the authored balance between a rare leak and a constant shot survives whatever the player chooses. |
| D51 | The credits screen renders `docs/ASSET_ATTRIBUTIONS.md` itself | Confirmed (Phase 10) | The record and the screen are one file: `pubspec.yaml` bundles the document straight from `docs/`, so there is no copy that can drift and an asset missing from the record is missing from the credits. A plain-Dart parser turns the tracked-assets table and the runtime-package list into the screen's rows — development-only packages sit outside that list, so they are never credited — and it throws on a format change instead of silently rendering an empty list. The provider disables Riverpod's default retry (ten backoff attempts): a bundled file that cannot be read is a broken build, not a transient failure, so the screen states the error at once instead of holding \"Loading\" for the better part of a minute. |
| D52 | The first-level tutorial is a step-driven card, dismissed once and remembered with the preferences | Confirmed (Phase 11) | The card shows only while the campaign's first level is open and only until dismissed, and every step advances through its own buttons — never by demanding one exact in-world action — so building, starting a wave or pausing in any order can never strand the tour (PLAN's no-soft-lock rule). It sits top-centred under the HUD, clear of the pad panel, the wave control and the HUD itself, so it can never intercept a tap meant for the level. The dismissal records `tutorialSeen` through D50's pattern (old saves fall back to \"not seen\", so the card shows exactly once), which keeps `CampaignProgress` purely results-and-unlocks and means a campaign reset (D43) does not bring the card back to somebody starting over. |
| D53 | The codex is one screen with a Towers/Enemies toggle, read straight from the shared catalogs | Confirmed (Phase 11) | It opens from the menu, where no level exists, so it loads the same tower and enemy catalogs a level would resolve — one screen can never quote numbers a session would not use. A segmented toggle replaces a TabBar because the menu frame scrolls a single column and a TabBarView would need a bounded height inside it. Traits that are not plain numbers (splash, slow, leak damage, kill reward) become sentences derived from the definition fields, so the prose cannot drift from the data, and the whole upgrade curve is listed with its gold cost instead of only the base stats. Loading follows D51: Riverpod's retry is disabled, so a broken build states the error at once rather than holding \"Loading\" for the better part of a minute. |
| D54 | Balance round 1: Cannon damage retuned by measurement; Frost's stronger slow tried and reverted | Confirmed (Phase 11) | Every balance change is judged with `tool/balance_probe.dart`, which replays all ten levels headlessly through the real session under fixed build plans, so a change ships on numbers rather than theory. Cannon damage went 26/40/60 → 34/52/78 because the old base needed four shells (6.4s) to kill a grunt — longer than one pad's zone holds a target, so it never finished what it started; three shells (4.8s) do, and its best case (two victims in the blast) reaches 0.39 damage-per-gold-per-second against the Ranger's 0.37, the first time the niche beats the cheapest tower. Measured: 5 → 7 of 10 levels won, kills 151 → 203, every core margin improved. Frost's stronger slow (magnitude 0.5 at the base level, half a second more duration) measured net-zero — it cost ember_01 a win and cut ember_04 kills from 27 to 15 while only gaining ember_02 — so it was reverted instead of shipped on reasoning alone; Frost's binding constraint is how little its zone overlaps the other towers' on the shipped maps, which needs a map or traits fix in a later round, not another nudge inside the 0.6 slow floor. |
| D55 | Frost's round 2 is a damage amplifier on the chill, judged against a same-slot control | Confirmed (Phase 11) | Round 1 proved Frost's slow numbers were not the binding constraint, so round 2 added a *trait* instead: `slow.damageAmp` makes every source deal its damage plus a configured fraction while the target is chilled (Frost ships 0.25/0.3/0.35). It is read inside `_applyDamage` itself, so shots and splash can never disagree about whether it applied, and it is gated by `isSlowed`, so an expired chill stops amplifying without extra bookkeeping. The probe gained an *order-matched control* — the same pad order with every slot filled by a Ranger — because comparing against a differently-ordered plan would credit the build order to the Frost. Result: the amplifier is a strict improvement over the old Frost (the probe's plan goes from core 5 → 15 on meadow_03 and 4 → 13 on meadow_05), yet the same-slot control still wins all ten levels: with five spread-out pads a support slot cannot out-earn a damage slot on the current maps. The \"each tower has a useful situation\" criterion therefore stays open, and the next round must be structural — overlap-dense pads or a tank-focused level — rather than another number. |
| D56 | Round 3 added overlapping build pads, and Frost still never beats a Ranger in the same slot | Confirmed (Phase 11) | `pad_f` joins both maps — at meadow's climb corner and above ember's entry road — with its zone sitting *inside* two rangers' zones, the structural fix round 2 proved was missing; the content gate's reachability rule (every pad within the shortest tower's range) checks it like every other pad. Two deployments were measured against order-matched controls: Frost built second, and Frost built last so its amplifier multiplies five placed rangers. The late build reaches parity with a same-slot Ranger on six of ten levels (two of those ties are levels where no sixth tower ever affords), but it never wins one, and it still loses ember_03 and ember_05; the early build loses everywhere. The criterion stays open, and the run records the confound that mattered most: build *order* alone moves ember_03 from 9 to 13 core, so every future balance claim must name its control. |
| D57 | The probe's findings are a test: opening pacing pinned, controls proven order-matched, campaign outcomes pinned | Confirmed (Phase 11) | `test/unit/balance_regression_test.dart` replays the first three levels under the probe's fixed plans and asserts the opening stays a zero-leak, full-core run for both a pure-damage build and a support build, so an edit that makes the teaching levels punishing fails the suite instead of a player's first session. Its second group does not simulate at all: before any comparison runs, it proves the control fills every pad exactly once, in the same order as the plan it is matched against, differing only by swapping a damage slot for a support slot — the structural form of the round-3 lesson that build order alone moves ember_03 from 9 to 13 core. The policy mirrors `tool/balance_probe.dart` deliberately: the test is the gate, the probe stays the exploration tool, and neither number can drift from the other by refactoring alone. Beyond the opening, every one of the remaining seven levels is pinned to the probe's exact table under all four strategies — win or loss, core left and leaks — because balance data is *supposed* to move those numbers, just never silently: a mismatch tells the author to re-run the probe, review the campaign table, and edit the pin in the same change as the data. |
| D58 | The result panel delivers the unlock: it names what a victory opened and offers Next level | Confirmed (Phase 11) | Phase 11's "campaign rewards and unlock messaging" resolves to this, because D39 already made stars the reward and gold stays inside the attempt — so the unlock *is* the reward, and the summary must say it. The first-clear fact is captured just before the record runs, since afterwards progress cannot distinguish a first clear from a replay; it reaches the panel through the one rebuild that recording progress causes, never per frame. The message takes the subtitle's slot rather than adding a row: measured on the 450-high landscape surface the panel already uses, a second line overflows the card, and the subtitle carries no fact the title and rows do not. The picker's locked rows name the previous level (they said only "the previous level"), read off the same flattened order the unlock rule uses, and the gameplay route is keyed by level id so "Next level" remounts the screen — a finished attempt's game and overlays can never survive into the next level. A level outside the campaign (test fixtures) gets neither message nor button. |
| D60 | Frost's round 4: the chill spreads in a blast, closing the criterion | Confirmed (Phase 11) | Five structural candidates were measured against order-matched controls before this one: moving pad_f to the best triple-route-coverage spot, adding a seventh overlap-dense pad, a chill nova at radius 70, Frost built early (again), and all their pairwise combinations — every one tied or lost, because a support slot only pays when the chill reaches the targets the *other* towers are shooting, and a single-target Frost with the shortest range cannot guarantee that. What won is the same mechanic the Cannon got in D59: `splashRadius` on the Frost (140/148/156), which the existing hit rule already applies — `_resolveHit` spreads the projectile's `slow` to every splash victim, so this is a mechanic change carried by data, not a nudge inside D54's slow floor. Measured on all ten levels: Frost now **beats** its same-slot Ranger control on ember_04 (core 6 vs 4) and ember_05 (12 vs 10), reaches parity on ember_03 (9 vs 9, from a 5-vs-9 loss), and never does worse anywhere — the first time any tower wins slots against the damage control, so PLAN's "each tower has a useful situation" is met by all three towers. The codex and the effect layer pick the new trait up from the data (a blast ring now draws on every chill), and the gate's three frost pins moved in the same change. |
| D61 | Difficulty modes stay out of the MVP, closing Phase 11 as measured | Confirmed (Phase 11) | PLAN offers difficulty modes *only if* the default campaign is already balanced, and the phase closes with that baseline measured rather than asserted: the probe runs all four strategies through all ten levels at 40/40 wins, each tower beats its same-slot control somewhere (D59, D60), and the opening three levels are gated to a zero-leak three-star run (D57). What modes would multiply — waves, gold, core — is exactly the surface the balance gate pins, so shipping them now would mean tuning two campaigns at once; they belong after release feedback says the single campaign needs more, alongside PLAN's other post-MVP enhancements. |
| D59 | Cannon's blast radius matches the waves it ships against: 70 → 140 | Confirmed (Phase 11) | The tower's identity ("every enemy in the blast") was unreachable: every shipped wave spaces its spawns by `speed × interval` — 80–140 world units — and a 70-unit blast therefore never touched a second target, making the Cannon a strictly worse single-target tower (21 dps for 110 gold against the Ranger's 25.7 for 70) and the cause of all three ember losses. The radius now covers every same-group spacing (140/148/156), measured with the probe against order-matched controls: `cannon crossfire` goes from 7/10 to 10/10 wins and now *beats* an all-ranger same-slot control on meadow_05 (16 vs 14 core), ember_03 (13 vs 9), ember_04 (12 vs 4) and ember_05 (12 vs 10) — the first level where any tower stands on its own niche, closing Phase 11's "each tower has a useful situation" for the Cannon. Cost and plan variants were tried first and rejected: a late cannon build and a cheaper cannon each flip different subsets but never beat their matched control, so the binding constraint was the splash itself, not the economy or the map. The pinned gate's cannon rows were updated in the same change, and the codex quotes the new radius from the same data. |
| D62 | Ember's pads E and F move to the entry road's south bank, because the top HUD was sitting on them | Confirmed (Phase 13) | The gameplay HUD is a Flutter overlay pinned to the top of the screen — back button and level chip at the left, gold/health/wave chips, pause and speed at the right — and the camera fits the map to the full screen height on any screen at least as wide as the world, so the strip it covers is a strip of the *map* too (about 88 px over a 360 px landscape screen, status bar included, i.e. the top quarter). Ember's `pad_e` (`y=60`) and `pad_f` (`y=110`) were inside it: the level chip takes the tap as well as the view, so those pads could be neither seen nor opened — reported as "the text covers the place to select a tower". Moving a HUD widget would only unblock the pad that happens to sit under that widget, so the content moved instead: both pads crossed to the south bank of the entry road keeping their **exact standoff from the route** (140 and 90 units), `pad_f` keeping `x=330` and `pad_e` sliding to `x=60` because `pad_a` already holds `(220, 340)` on that row. The guard that keeps it from reopening sits beside the tower-reach rule in `content_assets_test`, not in `MapValidator`: a pad's top edge must stay below the top 25% of the map, and the rule is about where the *shipped HUD* sits, so the domain validator stays free of presentation facts and the synthetic profiling map keeps all 23 of its pads. Balance was re-measured rather than assumed: the probe still reports 40/40 wins with the opening three untouched, D59's cannon rows all hold (beats its control on meadow_05, ember_03, ember_04, ember_05), and only two pins moved — ember_04's `rangers only` 4 → 6 core and its `frost control` 6 → 2 — so D60's claim that Frost "never does worse anywhere" is superseded by this row: Frost keeps parity on ember_03 (9 vs 9) and its win on ember_05 (12 vs 10), but now loses ember_04 (2 vs 6). PLAN's actual gate, "each tower has at least one useful situation", still holds through ember_05. D56's "above ember's entry road" now reads "on its south bank" for the same reason. |
| D63 | Region 3 is route topology and pacing, not a new visual theme or hazard | Planned (v2, V2-1) | Both shipped regions already draw the same vector field and the same two CC0 tiles (D48); a per-map palette would add a data field used by exactly one map, which the "second real use case" rule in AGENTS.md rejects. The third region therefore ships as a new route with a shared mid-section, more pads, and five levels completable with the three-tower roster shipped at the time — the V2-2 towers add options but are not progression requirements; no `theme` field, no hazard, no new art. A fourth region is the point where a palette field earns its place. |
| D64 | Beacon buffs range, one aura at a time, computed in one place | Planned (v2, V2-2) | Range is the only stat the game already draws, so the buff is visible in the selected tower's circle without new UI, and it does not multiply the same number Frost's `damageAmp` already multiplies (D55), which keeps probe attribution clean; cooldown buffs would change fire cadence, a surface the frame-cost tests and the "stats come from the instance" rule would both have to absorb. Effective range is `instance range × (1 + strongest aura covering the tower)` — auras never stack, so two Beacons cannot compound. Every reader (target check, drawn circle, tower panel) goes through one `LevelSession` accessor so no consumer can miss the buff. Beacon deals no damage: if the probe cannot make it beat an order-matched Ranger anywhere, it ships only after a structural fix (D56/D60 precedent) or not at all. Checked against the code when v2 scope was fixed: range is read in four places — targeting in `level_session.dart`, the selected tower's circle in `tower_layer.dart`, the panel's `Range` chip and its `Next:` upgrade preview — so the accessor must answer for a *level* (the preview asks about the next one) and `_TowerDetails` must receive those values from `_PadPanel`, which already holds the session; missing any of the four makes the buff cosmetic in exactly one place, the failure AGENTS.md §3's stats rule exists to prevent. `TowerLevelStats` has no `copyWith`, so one is added rather than mutating a shared definition, and the aura is derived per query (no cache, so nothing can go stale): on the shipped six-pad maps that is 36 range checks per combat step. AGENTS.md §3's wording ("read `TowerInstance.stats`") must become "read the session's effective stats, derived from the instance" in the same change, or the contract and the code disagree. |
| D65 | Hard is one global data profile applied at load, campaign only | Planned (v2, V2-3) | `assets/data/difficulties.json` declares Normal and Hard as multipliers over wave group counts and starting gold (`+25%` count, `×0.9` gold to start; tuned by probe), and `LevelRepository` resolves the bundle with the chosen profile, so `LevelSession` never learns difficulty exists — the same reason pause and speed stay outside the domain (D30). One profile means one extra pinned column in `balance_regression_test`; per-region profiles would multiply exactly the tuning surface D61 refused. Core health stays authored, so the star rule (D35) keeps meaning the same thing on both modes. Hard is campaign-only in v2 (endless climbs through its own composer, D62) and opens per region once that region is cleared on Normal. Checked against the code when v2 scope was fixed: `LevelRepository.load` takes only an asset path and `levelBundleProvider` is keyed by level id, so difficulty has to be an explicit argument threaded through the bundle key and the `play/:levelId` route key (`GameplayScreen._gameFor` deliberately keeps the first game it builds, so a bundle change alone would be ignored); reading it from an ambient provider instead would leak Hard into endless and into a restart. The content gate asserts each level's authored gold can afford a tower, and `LevelValidator` only checks gold ≥ 0, so the gate has to run that assertion per shipped profile, the transformed level has to be validated too, and gold scaling must stay integer (`(gold * 9) ~/ 10`, never a double). The dependency that is easy to miss: `CampaignProgress.results` is keyed by level id and `LevelResult` carries no difficulty, so a Hard run would overwrite Normal stars, campaign totals, the unlock message and D67's campaign achievements — save v4 must key results by level and difficulty with Normal as the default, and the picker and achievements must state whether they read Normal only. `tool/balance_probe.dart` reads content from disk and never uses `LevelRepository`, so it needs a difficulty argument before V2-6's both-modes table can exist. |
| D66 | The daily challenge seeds from the local calendar date, and a run keeps the seed it started | Planned (v2, V2-3) | Presentation reads the device's local date, formats it as an integer `yyyyMMdd`, and passes it in; the domain uses that seed to select the same existing campaign level on every device (D70), so no wall-clock read enters the simulation. Reset is local midnight, not a rolling 24-hour window: "a new challenge each day" explains itself in one line, while a rolling window would make two players' dailies disagree with the calendar. Changing the device clock can select a different day's challenge, and that is accepted rather than defended: the mode is offline and local, so the only person it cheats is the player. A run that starts before midnight finishes under the seed it began with; the next date has its own run, and results are stored per date id in save v5. |
| D67 | Exactly ten achievements, all derived from facts the save already stores | Planned (v2, V2-4) | The set: finish any level; finish one with the core untouched; earn three stars on any level; clear one region; three-star one region; clear all 15 campaign levels; three-star all 15; reach endless wave 10; reach endless wave 20; finish a daily challenge. Every one of them is computable from `CampaignProgress.results`, `endlessBest` and stored daily results, so nothing is tracked per frame and no achievement can invent a rule the session does not already resolve. They are evaluated once, in the same path that records a result, so a replay or a restart cannot double-award, and the save stores ids only. The set stays closed until a new stored fact exists to derive from. |
| D68 | Per-level objectives replace core-health stars: two authored `kind`s per level, `1 + met` stars | Planned (v2, V2-3) | Authoring: `objectives` is an optional level list of `{ "kind": ..., "value": ... }`, declared 0 or exactly 2 (the validator rejects 1 or 3+): stars are `1 + met`, so a single objective would cap a level at two stars. Four closed kinds in v2 — `noLeaks`; `maxTowers` (the highest number of towers standing simultaneously; selling cannot lower the recorded peak and build–sell–build cannot cheat); `deadlineSeconds` (the session's existing `elapsed`, which advances only while `playing` — pause freezes it, 2× cannot shorten it, and the between-wave countdown is excluded, so a deadline measures fighting time rather than idle time); `coreAbove` (strictly below the level's core, so it can never restate `noLeaks`) — and no free-text label: the sentence is derived from kind and value, the rule D53 already applies to codex prose. Campaign levels must declare two (`campaign_assets_test`), endless none (a run can only end in defeat), fixtures may skip them. Rule: defeat 0, victory `1 + met`; levels with no objectives keep D35's core-health ladder as a fixture-only fallback, so the synthetic map and existing tests need no authored content. One status feeds everything: `LevelSession` computes objective state (including the new peak-tower counter) and `LevelHudState` publishes `objectivesMet`, so the HUD's `Goals n/2`, the result panel and `LevelRating.starsFor` cannot disagree — a HUD reading 2/2 cannot award two stars. The pause panel, result panel and picker show the derived sentences. Save: `LevelResult` gains `objectivesMet` in schema v4 beside D65's difficulty keys, and `stars` stays the stored derived value — a load never recomputes it, so a 1.0 three-star run keeps three stars even where the new objectives would be harder (D37/D42), and `isBetterThan` keeps stars-then-core so no replay can overwrite a better stored result. Feasibility is a gate, not a hope: `maxTowers` within the pad count and affordable from starting gold on every shipped profile, `deadlineSeconds` at least the level's minimum spawn duration (the sum of each wave's longest group), and the probe must show one pinned plan reaching three stars per level. Authoring landed ahead of the rule: the ten campaign levels now declare their goals, `CONTENT_AUTHORING.md` documents the format, and the content gate checks shape and feasibility, while `LevelRating`, the HUD and the save still run on D35 — both halves must ship in the same release, so V2-3 is not done until the star rule reads them. |
| D69 | The existing boss has one health-triggered speed surge in Region 3 | Planned (v2, V2-1) | When health first reaches 50% or below, the boss moves at 1.5× its authored speed for three simulation seconds, once per boss; the definition fields are `speedSurgeHealthRatio`, `speedSurgeMultiplier` and `speedSurgeDurationSeconds`, constrained to boss definitions (`speedSurgeHealthRatio` in `(0, 1]`, multiplier `> 1`, positive duration). The phase uses simulation time, is deterministic across frame rates, and adds no new enemy or subsystem; Region 3 teaches it before relying on it. This gives the third act one authored escalation while keeping its levels playable with the existing three-tower roster. |
| D70 | The daily seed selects one existing campaign level; its result is separate from campaign progress | Planned (v2, V2-3) | Presentation reads the local date as `yyyyMMdd` and passes that integer to a pure selector. The selector uses xorshift32 (`x ^= x << 13`, then `x ^= x >> 17`, then `x ^= x << 5`) with unsigned 32-bit arithmetic after each step, and maps zero state to `0x6D2B79F5`; its output modulo the stable ordered campaign level-id list chooses the level. The selected level's authored map, waves and objectives run unchanged on Normal. Record the outcome only under that date's daily result: do not change campaign stars, results or unlocks. A pinned test locks the algorithm and expected level ids across supported devices. |
| D71 | Haptics acknowledge builds/upgrades and warn on core leaks, but never fire for routine combat | Confirmed (Phase 13) | The existing persisted `hapticsEnabled` setting gates feedback from published level events: build/upgrade request a light selection click and leak damage requests a heavy impact; shots, hits and defeats stay silent to avoid constant vibration. The Flame layer maps events through an injectable sink, and the Flutter adapter uses `HapticFeedback`; unsupported devices and platform failures must never interrupt the simulation. |

