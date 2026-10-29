# UpTowerDefense — Product and Implementation Plan

**Document type:** Product specification and phased engineering plan  
**Project name:** UpTowerDefense  
**Target:** Offline-first 2D tower defense game built with Flutter and Flame  
**Initial platforms:** Android and iOS  
**Primary language:** Dart  
**Status:** Proposed baseline; validate package versions and platform requirements during implementation

---

## 1. Product Vision

UpTowerDefense is a polished, single-player 2D tower defense game in which players build and upgrade defensive towers, manage limited resources, and stop successive enemy waves from reaching a protected core. The campaign progressively climbs through more challenging regions, introducing new enemy combinations, maps, and tactical choices.

The game must remain fully playable without an internet connection. All gameplay assets, level definitions, progression, settings, and saved games are stored locally. No account, remote API, cloud service, or online validation is required for the core game loop.

### 1.1 Product goals

1. Deliver a responsive and readable tower defense experience on mobile devices.
2. Make the first playable level easy to understand without a lengthy tutorial.
3. Create meaningful strategic choices through tower roles, enemy traits, limited build resources, and upgrade paths.
4. Support a campaign that can be extended by adding data-driven levels instead of rewriting game logic.
5. Keep game simulation, rendering, UI, content definitions, and persistence clearly separated.
6. Ship a stable offline game with reliable local saves and graceful handling of app pause/resume.

### 1.2 Design pillars

- **Readable tactics:** towers, enemies, projectiles, ranges, status effects, and warnings must be visually distinguishable on a small screen.
- **Fast decisions:** tower placement, upgrade, selling, speed control, and pausing should require very few taps.
- **Earned progression:** new campaign regions and tower upgrades are earned through play; avoid pay-to-win systems in the initial release.
- **Replay value:** stars, optional objectives, multiple viable tower combinations, and difficulty levels create reasons to replay.
- **Offline by design:** no gameplay path may block on network access.

### 1.3 Working theme and naming assumptions

The working theme is a stylized fantasy-tech world in which the player protects an energy core while ascending through increasingly dangerous regions. “Up” represents campaign ascent and the upward progression of the player’s defenses. The visual theme can be replaced without changing core systems.

Use **UpTowerDefense** as the internal project and package display name. The final public-facing app name, icon, bundle identifiers, store copy, and trademark availability must be checked before release.

---

## 2. Scope and Non-Goals

### 2.1 MVP scope

The first release candidate must include:

- A main menu and settings screen.
- A playable campaign with at least 10 hand-authored levels across 2 visual regions.
- A fixed-route map with predefined build pads; tower placement cannot block enemy paths.
- At least 3 distinct tower types.
- At least 3 basic enemy types and 1 boss archetype.
- Data-driven waves, enemy stats, tower stats, map definitions, rewards, and level objectives.
- Build, target, attack, damage, status effect, death, leak, wave, win, and loss systems.
- Tower upgrades and selling with clear refund rules.
- Pause, resume, restart, game speed controls, and a visible wave summary.
- Local campaign progress, settings, unlocks, and best results.
- Basic sound effects, music controls, animation, impact feedback, and visual effects.
- Automated unit tests for core rules and integration/widget tests for important flows.
- A documented build and release process for Android and iOS.

### 2.2 Explicitly out of scope for the initial release

Do not implement these before the core game is stable:

- Multiplayer, PvP, co-op, clans, chat, leaderboards, cloud saves, or server APIs.
- Mandatory sign-in or account creation.
- Real-money purchases, premium currency, loot boxes, or ad-gated progression.
- A level editor for end users.
- Procedurally generated campaign maps.
- 3D gameplay or a physics-heavy simulation.
- User-generated content or online mod downloading.
- Remote configuration or gameplay that requires live services.

These may be considered in separate post-release phases, but the product must remain enjoyable without them.

### 2.3 Target platforms and orientation

- Primary targets: current supported Android and iOS devices.
- Recommended gameplay orientation: **landscape** to provide space for the route, build pads, and tactical HUD.
- Menus should adapt to different aspect ratios and safe areas.
- Do not assume a specific screen size. Use responsive Flutter layouts and a consistent logical game coordinate system.
- Decide minimum OS versions and final device support after checking the current stable Flutter toolchain and dependencies.

---

## 3. Core Gameplay Specification

### 3.1 Primary game loop

1. The player opens a level and reviews the map, core health, available lives, initial gold, and available towers.
2. The player spends gold to build towers on valid build pads.
3. The player starts the next wave, or the next wave starts automatically according to the chosen UX rule.
4. Enemies spawn in configured groups and follow the route to the protected core.
5. Towers acquire targets and attack based on range, cooldown, damage type, and target priority.
6. Defeated enemies grant rewards; enemies that reach the exit reduce core health or lives.
7. Between waves, the player repositions their strategy by building, upgrading, or selling towers.
8. The level ends when all waves are completed and no active enemies remain, or when core health reaches zero.
9. The player receives a result summary and unlock/reward updates; progress is saved locally.

**Design decision:** use predefined build pads rather than free placement for the initial release. This makes path validation predictable, improves touch accuracy, and reduces the chance of players accidentally blocking the route. Free placement may be evaluated after MVP.

### 3.2 Controls

- Tap a build pad to open the build selection panel.
- Tap a tower to open its detail panel with stats, upgrade, target priority, and sell actions.
- Tap the selected tower again or tap an empty region to dismiss its panel.
- Provide large touch targets and clear selected/disabled states.
- Pause/resume must be available at all times during gameplay.
- Provide speed settings: `1x` and `2x` for MVP; consider `3x` only after performance and balance tests.
- The game simulation must stop while paused, while the application is inactive, or while blocking dialogs are open.

### 3.3 Level states

Represent gameplay state with a well-defined enum or sealed type, not a collection of unrelated booleans.

Suggested states:

- `loading`
- `ready`
- `playing`
- `waveTransition`
- `paused`
- `victory`
- `defeat`
- `disposed`

Define allowed transitions and reject invalid transitions. For example, a defeated level cannot spawn additional waves until restarted.

### 3.4 Victory and defeat conditions

- **Victory:** all configured waves have spawned and every enemy from those waves has been defeated or otherwise resolved, with no enemies still active.
- **Defeat:** core health reaches zero.
- A level cannot show victory while an enemy is still active or waiting to spawn.
- Restarting a level resets transient level state but preserves campaign data that was saved before the attempt.
- Completing a level must write progress only once, even if multiple callbacks fire in the same frame.

### 3.5 Economy rules

Use integer currency values to avoid floating-point rounding errors.

- Player gold is earned from enemy kills and level rewards.
- Building and upgrading towers consumes gold.
- Selling a tower refunds a configurable percentage of the total gold invested in that tower; initial recommendation: 60%.
- A tower cannot be built or upgraded when the player lacks sufficient gold.
- An upgrade must be atomic: deduct gold only if the upgrade can be applied successfully.
- All cost and reward values come from data/configuration, not scattered constants.
- Show costs, refunds, range, damage, attack speed, and effect changes before the player confirms an action.

### 3.6 Wave system

A level contains ordered wave definitions. A wave may have one or more spawn groups. Each group defines enemy type, count, delay between spawns, and optional delay before the group begins.

Required behavior:

- Waves execute in deterministic order.
- Enemy spawns must use simulation time, not arbitrary wall-clock timers.
- Pause and game speed must affect wave timing consistently.
- The next wave is available only when the current wave is complete, unless the level explicitly allows overlap.
- MVP should not allow overlapping waves by default; add an optional “Start Next Wave Early” bonus only after basic balance is complete.
- A wave is complete only after all configured enemies have spawned and all enemies from that wave are resolved.

### 3.7 Enemy movement and path

- Each map has a validated ordered list of waypoints.
- Enemies move along the route at their configured speed, using elapsed simulation time.
- Enemy movement must remain consistent at different frame rates and game speeds.
- Reaching the route endpoint causes a single leak event and removes the enemy from active combat.
- Do not use real-time network calls for movement, targeting, damage, or any other gameplay calculation.
- Maps are authored in game-world coordinates and converted consistently to screen coordinates.

### 3.8 Tower targeting

MVP target policies:

- **First:** target the enemy furthest along the route.
- **Strongest:** target the living enemy with the most current health.

If a tower's target becomes invalid, the tower must reacquire a valid target without crashing or retaining a disposed entity. Define deterministic tie-breaking so tests are reliable.

### 3.9 Initial tower roster

Implement three towers first. A fourth tower may be added in a later content phase if balance and production quality justify it.

| Tower | Role | Suggested behavior | Tactical use |
|---|---|---|---|
| Ranger Tower | Fast single target | Moderate damage, high fire rate, low cost | Reliable early-game defense |
| Cannon Tower | Area damage | Slow projectile, splash damage, slow fire rate | Groups of low-health enemies |
| Frost Tower | Control/support | Low or no damage; applies a capped slow effect | Slows durable enemies and improves other towers' damage uptime |

Each tower definition must include:

- Stable ID and localized display name key.
- Description and role.
- Build cost and sell refund policy.
- Range, attack cooldown, targeting policies, and upgrade levels.
- Damage type and damage values where relevant.
- Projectile/effect configuration.
- Asset references and optional sound references.
- Upgrade cost per level and stat changes per level.

Use configuration-driven stat definitions so balancing does not require editing combat logic.

### 3.10 Initial enemy roster

| Enemy | Role | Suggested behavior |
|---|---|---|
| Grunt | Standard | Balanced speed and health |
| Runner | Fast | Low health, high speed |
| Brute | Tank | High health, low speed |
| Region Boss | Boss | Higher health and a simple special rule, introduced after basic enemies work |

Enemy definitions should support health, movement speed, armor/resistance, reward, core damage on leak, visual variant, status resistance, and optional abilities. Avoid implementing a general-purpose ability framework until a real enemy requires it.

### 3.11 Damage and status effects

- Damage is applied through a single domain rule path.
- Use explicit damage types only when at least one gameplay mechanic depends on the distinction.
- Clamp remaining health at zero and dispatch death once.
- Splash damage uses a defined radius and a clear rule for whether damage falls off with distance; MVP should use simple fixed splash damage.
- Frost slow effects must have a configured magnitude, duration, stacking/refresh rule, and minimum movement speed cap.
- Prevent repeated application of a death reward or leak penalty.
- Status effects must expire using simulation time and pause correctly.

### 3.12 Game speed and timing

- Use the Flame game loop for rendering and simulation updates.
- Apply game speed to simulation delta time, not to UI animations or system timers indiscriminately.
- Clamp unusually large frame deltas after lifecycle interruptions to prevent teleporting enemies or instant wave completion.
- On app resume, pause first or reconcile explicitly; never silently advance a level based on wall-clock time.
- Keep simulation rules independent of rendering frame rate and test them with varied delta-time inputs.

---

## 4. UX and Screen Design

### 4.1 Main menu

Include:

- Play / Continue campaign.
- Level selection or campaign map.
- Tower codex/tutorial access.
- Settings.
- Credits and legal notices.

Do not make a login screen or network connection part of first launch.

### 4.2 Gameplay HUD

The HUD should show:

- Core health/lives.
- Current gold.
- Current wave and total waves.
- Play/pause control.
- Game speed control.
- Current level objective.
- Build selection when a build pad is selected.
- Tower details and actions when a tower is selected.
- Clear feedback for insufficient gold, invalid actions, leaks, and wave completion.

The HUD must not obscure critical route segments or make build pads difficult to tap. On narrow landscape screens, use compact panels and collapsible details.

### 4.3 Tower detail panel

Show:

- Tower name, level, role, and short description.
- Damage, range, fire rate/cooldown, and active effect.
- Next upgrade's cost and changes.
- Target priority setting.
- Sell button with refund displayed before confirmation if appropriate.

### 4.4 Level result screen

Show:

- Victory/defeat state.
- Waves cleared.
- Remaining core health.
- Enemies defeated and leaks.
- Gold earned or result score.
- Stars or medal rating if enabled.
- Replay, next level, and level-select actions.

Do not create a large ranking system before the basic result loop is stable.

### 4.5 Settings

Store settings locally:

- Music volume and enable/disable.
- Sound-effects volume and enable/disable.
- Haptics enable/disable, where available.
- Left/right-handed or HUD layout preference only if the design truly needs it.
- Reduced motion option if effects are intense.
- Language selection once localization is implemented.
- Reset local progress with a clear confirmation and warning.

### 4.6 Accessibility and mobile usability

- Use sufficiently large touch targets and readable text at normal phone viewing distance.
- Do not convey tower/enemy differences by color alone; use silhouettes, icons, and effects.
- Provide sound controls and visual equivalents for important audio cues.
- Respect system safe areas and display cutouts.
- Support a reduced-motion setting for major effects.
- Verify text scaling in menus and dialogs; gameplay HUD may use bounded scaling when unrestricted scaling would hide critical controls.

---

## 5. Technical Architecture

### 5.1 Technology choices

- **Flutter + Dart:** application shell, menus, HUD panels, settings, navigation, accessibility, and platform integration.
- **Flame:** 2D game loop, component lifecycle, sprites, animation, camera/viewport, and rendering support.
- **State management:** Riverpod is the recommended default for Flutter-side UI and dependency injection. Do not push high-frequency per-frame entity state through global UI providers.
- **Navigation:** GoRouter or a small typed navigation layer. Choose one and use it consistently.
- **Local settings:** a simple key-value store such as `shared_preferences` for non-sensitive preferences only.
- **Local campaign saves:** versioned JSON save files using a supported local application directory, or a lightweight local database if the save model grows substantially. For this game, start with a versioned JSON save because campaign progress is small.
- **Audio:** Flame-compatible audio package or Flutter audio package selected after compatibility review.
- **Serialization:** handwritten immutable model serialization or `json_serializable`; avoid introducing code generation unless the project benefits from it.
- **Testing:** Dart unit tests, Flutter widget tests, and integration tests for critical game flows.

Verify current stable versions and compatibility before adding packages. Do not pin stale versions merely because they appear in an old example.

### 5.2 Layer boundaries

**Flutter presentation layer**
- Menus, level select, settings, HUD overlays, dialogs, result screens.
- Converts user input into explicit commands.
- Displays state exposed by game/application services.

**Game presentation layer (Flame)**
- Map rendering, towers, enemies, projectiles, damage indicators, animations, and effects.
- Reads simulation state and visualizes it.
- Sends input intent to game services; it must not own campaign-save rules.

**Domain/gameplay layer (plain Dart where practical)**
- Wave scheduling, path progress, targeting, damage, economy, status effects, victory/defeat evaluation, and rewards.
- Does not import Flutter widgets or depend on screen dimensions.
- Uses deterministic and testable inputs.

**Application layer**
- Coordinates level start/restart, pause/resume, result handling, unlocks, and save requests.
- Connects gameplay results to local persistence.

**Data layer**
- Local save repository, settings repository, content/config loaders, and asset manifest integration.
- Contains no rendering or frame-by-frame gameplay logic.

### 5.3 Important architecture rule

Do not make Flame components the sole source of truth for player gold, level result, upgrade costs, or campaign unlocks. Components are visual/game-world representations. Keep authoritative gameplay rules in game/domain services or well-defined game-state objects that can be tested without rendering.

### 5.4 Suggested project structure

```text
lib/
  main.dart
  app/
    app.dart
    router.dart
    theme/
    lifecycle/
  core/
    constants/
    errors/
    logging/
    result/
  features/
    main_menu/
      presentation/
    campaign/
      domain/
      data/
      presentation/
    gameplay/
      application/
      domain/
        models/
        systems/
        rules/
      data/
      flame/
        up_tower_defense_game.dart
        world/
        components/
        effects/
        input/
        overlays/
      presentation/
    settings/
      domain/
      data/
      presentation/
    codex/
      presentation/
  shared/
    widgets/
    localization/
assets/
  images/
    towers/
    enemies/
    projectiles/
    maps/
    effects/
    ui/
  audio/
    music/
    sfx/
  data/
    towers/
    enemies/
    levels/
    waves/
    localization/
test/
  unit/
  widget/
  integration/
docs/
  GAME_DESIGN.md
  CONTENT_AUTHORING.md
  RELEASE_CHECKLIST.md
```

Adapt this layout to the repository's conventions if a codebase already exists. Avoid creating empty abstractions or folders without a concrete use.

### 5.5 Core domain models

Use stable IDs and explicit value types. Suggested models include:

- `TowerDefinition`: immutable configuration for a tower type.
- `TowerInstance`: placed tower ID, tower definition ID, build-pad ID, current level, target priority, and invested currency.
- `EnemyDefinition`: immutable stats and visual references.
- `EnemyState`: runtime health, path progress, status effects, and wave ownership.
- `ProjectileDefinition`: movement mode, speed, direct damage, splash configuration, and visual reference.
- `WaveDefinition`: ordered spawn groups and completion rules.
- `SpawnGroupDefinition`: enemy ID, count, spawn interval, and initial delay.
- `LevelDefinition`: map ID, waves, starting gold, starting core health, reward, objective, and unlock requirements.
- `MapDefinition`: world dimensions, route waypoints, build pads, background/theme, and exit/core locations.
- `PlayerRunState`: current gold, core health, wave state, active enemies, and placed towers for the current attempt.
- `LevelResult`: outcome, enemies defeated, leaks, waves cleared, remaining health, earned reward, and rating.
- `CampaignProgress`: unlocked level IDs, completion results, best ratings, and permanent progression flags.
- `GameSettings`: audio, haptics, reduced motion, language, and gameplay preferences.

Separate static definitions from mutable runtime state. Never mutate a shared tower or enemy definition to represent the state of one instance.

### 5.6 Game services/systems

Use focused systems with well-defined contracts. Avoid a single giant `GameManager` containing all rules.

- `LevelSessionService`: creates and resets a level attempt.
- `WaveSystem`: schedules spawn groups and tracks wave completion.
- `EnemyMovementSystem`: advances enemies on validated waypoint paths.
- `TargetingSystem`: filters candidates and applies target-priority rules.
- `TowerCombatSystem`: cooldowns, attacks, and projectile creation.
- `ProjectileSystem`: projectile movement and hit resolution.
- `DamageSystem`: health reduction, armor rules, death resolution, and status application.
- `StatusEffectSystem`: timing and application of slow/effect rules.
- `EconomySystem`: build/upgrade/sell validation, gold deductions, rewards, and refunds.
- `LevelOutcomeSystem`: victory and defeat evaluation.
- `CampaignProgressService`: unlocks, results, stars, and local progression updates.
- `SaveRepository`: versioned save read/write, validation, migration, and recovery.

These do not all need to be separate classes on day one. Introduce a service when it provides a clear boundary or test value.

### 5.7 Data-driven content

Tower, enemy, wave, and level tuning should be stored in validated JSON or equivalent Dart data definitions. The MVP can use JSON assets decoded at load time, with strong validation and readable error messages.

Example conceptual level structure (not a complete schema):

```json
{
  "id": "region_01_level_01",
  "mapId": "meadow_gate",
  "startingGold": 180,
  "coreHealth": 20,
  "waves": [
    {
      "id": "wave_01",
      "groups": [
        {
          "enemyId": "grunt",
          "count": 6,
          "spawnIntervalSeconds": 1.2,
          "initialDelaySeconds": 0.0
        }
      ]
    }
  ],
  "completionReward": 60,
  "nextLevelId": "region_01_level_02"
}
```

Requirements for content loading:

- Validate IDs, references, values, wave ordering, route definitions, and asset paths.
- Reject negative costs, invalid speeds, non-positive health, and invalid spawn counts.
- Surface developer-readable diagnostics in debug builds.
- Provide a test that loads every shipped definition successfully.
- Do not load remote content in the MVP.

### 5.8 Local save format and migration

Store a `schemaVersion` in every save. Suggested top-level shape:

```json
{
  "schemaVersion": 1,
  "campaign": {
    "unlockedLevelIds": ["region_01_level_01"],
    "completedLevels": {},
    "bestResults": {}
  },
  "settings": {
    "musicEnabled": true,
    "sfxEnabled": true,
    "reducedMotion": false
  }
}
```

- Validate saves before use; handle missing, invalid, or partially written files safely.
- Use write-to-temporary-file then atomic replacement where supported by the platform/file API.
- Keep a last-known-good backup if implementation complexity is reasonable.
- When schema versions change, migrate forward explicitly; never silently reinterpret incompatible data.
- If save parsing fails, preserve the damaged file for diagnosis when feasible and offer safe recovery rather than crashing at startup.
- Save progress after level completion, campaign unlock changes, and settings updates. Avoid writing to disk every frame.
- The core game must remain playable when save data is unavailable; apply a safe default campaign state and report the issue clearly.

---

## 6. Rendering, Assets, and Performance

### 6.1 Rendering rules

- Use Flame components for game-world objects and Flutter widgets/overlays for rich menus and panels.
- Use sprite sheets or atlases for related animation frames when appropriate.
- Keep map, entity, projectile, effect, and UI coordinate spaces consistent and documented.
- Prefer reusable, data-driven components over one-off drawing logic for each level.
- Keep text-heavy controls in Flutter UI instead of implementing every panel as a game canvas component.
- Avoid rebuilding the full Flutter widget tree for every simulation tick.

### 6.2 Asset strategy

For the first playable prototype, simple placeholder art is acceptable. Before content lock:

- Define a consistent art direction, palette, silhouette language, and pixel/vector resolution strategy.
- Ensure each tower and enemy can be identified at gameplay scale.
- Create assets for idle, attack, damage, death, and special states only when required by gameplay.
- Optimize image dimensions and use atlases where helpful.
- Keep licenses and source attribution for all third-party assets in a central file.
- Do not ship assets with unclear or incompatible licenses.

### 6.3 Performance targets

- Target stable 60 FPS on representative supported devices; validate on physical low/mid-range devices, not only simulators.
- Define a representative stress level with many enemies, towers, projectiles, and effects.
- Avoid per-frame allocation of large temporary collections and repeated JSON/file operations.
- Reuse or pool high-volume transient objects only when profiling demonstrates a benefit.
- Prefer simple distance/range checks and direct projectile collision rules for tower defense; do not add a general physics engine unless the game mechanics require it.
- Profile before optimizing and record reproducible steps for performance tests.

---

## 7. Testing Strategy

### 7.1 Unit tests

At minimum, cover:

- Level/content JSON validation.
- Enemy waypoint progression and endpoint handling.
- Wave spawn order, spawn intervals, and wave completion.
- Target priority and deterministic tie-breaking.
- Tower cooldown and attack eligibility.
- Projectile hit handling and splash radius.
- Damage, armor, death-once semantics, and reward-once semantics.
- Slow effect duration, refresh, stacking rules, and speed cap.
- Build/upgrade/sell constraints and economy arithmetic.
- Core health loss and defeat transition.
- Victory conditions with no active/pending enemies.
- Pause and speed multiplier behavior.
- Campaign rewards, unlock logic, and best-result retention.
- Save validation, migration, invalid-save recovery, and atomic update behavior.

### 7.2 Widget tests

Cover:

- Main menu navigation.
- Level selection and locked/unlocked state.
- Settings changes and persistence.
- Build panel displays correct costs and disables unaffordable choices.
- Tower panel displays stats and correctly handles upgrade/sell actions.
- Pause menu and result dialog transitions.
- Accessibility labels and minimum touch target expectations for key controls.

### 7.3 Integration tests

At minimum, automate these flows:

1. Fresh install -> start level -> build a tower -> start a wave -> defeat an enemy -> win or intentionally lose.
2. Pause during enemy movement -> wait -> verify enemies and wave timing remain frozen -> resume.
3. Complete a level -> terminate/relaunch app -> verify the level unlock and result persist.
4. Restart a level -> verify transient state resets and campaign data does not incorrectly reset.
5. Disable network access -> launch app -> play a level -> complete it -> relaunch and verify saves.
6. Corrupt or remove a save file in a test environment -> verify safe recovery rather than a startup crash.

### 7.4 Balance tests

- Simulate or repeatedly play each level with a small set of standard strategies.
- Ensure the first level is beatable without upgrades beyond the tutorial path.
- Avoid levels that require one hidden or undocumented tower choice.
- Record completion rate, average remaining health, gold surplus/deficit, and the tower mix needed for success.
- Make difficulty increase gradually, with new mechanics introduced separately where possible.

---

## 8. Development Phases

Each phase has a concrete deliverable and acceptance criteria. Do not begin a later content-heavy phase while the core acceptance criteria of its dependencies are failing.

## Phase 0 — Product Decisions and Project Setup

### Tasks

- Confirm Flutter + Flame as the initial technology stack.
- Confirm 2D, single-player, offline-first, landscape gameplay, and fixed build pads.
- Create `docs/GAME_DESIGN.md` with the rules in this plan and record any intentional deviations.
- Choose a unique internal application ID and development bundle identifiers.
- Set up version control, formatting, linting, and CI checks if a CI service is already available.
- Review current stable Flutter, Flame, and plugin compatibility before adding dependencies.
- Add license and attribution tracking for any external assets.

### Deliverables

- Runnable Flutter skeleton on Android and iOS build targets.
- Repository conventions and a short README with run/test commands.
- Initial architecture decision record for Flutter/Flame boundaries.

### Acceptance criteria

- App launches on at least one Android emulator/device and one iOS simulator/device if the environment supports both.
- `dart format`, static analysis, and baseline tests pass.
- No network or account dependency is present.

## Phase 1 — Game Shell and Navigation

### Tasks

- Create app theme, responsive layout rules, and landscape gameplay orientation behavior.
- Implement main menu, level select placeholder, settings, credits, and navigation.
- Add a placeholder Flame game view that can be entered and exited cleanly.
- Handle app lifecycle events and device back/navigation behavior.
- Add local settings storage for audio toggles and other initial preferences.

### Deliverables

- Navigable application shell with a playable placeholder game screen.
- Settings survive app restart.

### Acceptance criteria

- No navigation loops or broken back behavior.
- Menus adapt to safe areas and common landscape aspect ratios.
- Leaving and re-entering gameplay does not leak game instances or audio resources.

## Phase 2 — Core Game World and Map Rendering

### Tasks

- Implement the `FlameGame` entry point and world/camera/viewport configuration.
- Define a game-world coordinate system independent of physical screen pixels.
- Implement map backgrounds, route rendering, the core/exit, build pads, and selection indicators.
- Load an initial map from data.
- Validate waypoint continuity and build-pad IDs.
- Implement hit testing for selecting build pads and existing towers.

### Deliverables

- One static map with tappable build pads and reliable selection feedback.

### Acceptance criteria

- Map layout is consistent across supported device aspect ratios.
- Touch selection aligns with the rendered pad/tower positions.
- No tower placement is possible on a route or invalid tile.

## Phase 3 — Enemy Movement and Wave Scheduling

### Tasks

- Implement enemy definitions and runtime state.
- Implement route-following movement through waypoints.
- Implement wave and spawn-group parsing.
- Add a debug control to start/advance waves during development.
- Implement enemy health display and route-end/leak handling.
- Add core health and defeat conditions.
- Ensure all timing is simulation-time based and respects pause and game speed.

### Deliverables

- Enemies spawn in a configured wave, traverse the route, and damage the core if they escape.

### Acceptance criteria

- Enemy arrival times are acceptably consistent across frame rates.
- Enemies leak exactly once and are removed from active simulation.
- Pausing freezes enemy movement and wave scheduling.
- Defeat occurs once when core health reaches zero.

## Phase 4 — Tower Placement and Economy

### Tasks

- Implement tower definitions and build-pad occupancy.
- Add the first Ranger Tower with build cost, range, fire cooldown, and targeting behavior.
- Implement gold display and reward events.
- Add build selection UI with cost and affordability states.
- Implement build validation and transactional gold deduction.
- Add tower selection and basic tower information panel.

### Deliverables

- The player can build at least one tower and see its state on the map.

### Acceptance criteria

- Invalid builds never consume gold.
- Two towers cannot occupy the same pad.
- Tower state and pad occupancy remain consistent after repeated taps.
- Build cost and balance values are sourced from definitions.

## Phase 5 — Targeting, Attacks, Projectiles, and Damage

### Tasks

- Implement `TargetingSystem` with First priority.
- Implement tower range checks and cooldown logic.
- Add projectile movement and hit resolution.
- Add damage, enemy death, reward, and cleanup rules.
- Ensure target references are invalidated safely when enemies die or leak.
- Add attack/impact/death placeholder effects.

### Deliverables

- A tower autonomously targets and defeats enemies.

### Acceptance criteria

- Towers never target inactive/dead enemies.
- An enemy produces one death event and one kill reward only.
- Range and cooldown behavior are covered by tests.
- The game remains stable when several enemies die in the same update.

## Phase 6 — Tower Roster, Upgrades, and Status Effects

### Tasks

- Add Cannon Tower and area damage.
- Add Frost Tower and slow effects with explicit refresh and cap rules.
- Implement tower upgrade levels and costs.
- Implement selling and refund calculation.
- Add target priority selection (First and Strongest).
- Update tower details to show current and next-level stats.

### Deliverables

- Three distinct towers with meaningful tactical roles and complete economic actions.

### Acceptance criteria

- Splash damage affects exactly the enemies inside the defined radius.
- Slow effects expire correctly and cannot reduce speed below the configured cap.
- Upgrade and sell operations maintain correct invested-cost accounting.
- UI never displays a successful action before the domain operation succeeds.

## Phase 7 — Full Game-State and Level Flow

### Tasks

- Formalize legal gameplay state transitions.
- Implement wave transition and auto/manual next-wave behavior (choose and document one UX for MVP).
- Add pause/resume, restart, 1x/2x speed, victory, defeat, and result summary.
- Handle app backgrounding by pausing safely.
- Prevent late timers/events from modifying a completed or disposed session.

### Deliverables

- One complete level from launch through victory/defeat and replay.

### Acceptance criteria

- Victory cannot occur while a spawn is pending or an enemy remains active.
- Restart clears all transient state, timers, projectiles, and active effects.
- Pausing freezes every gameplay timer and effect that should be simulation-bound.
- No duplicate result/reward events occur.

## Phase 8 — Content Pipeline and Campaign MVP

### Tasks

- Finalize validated data formats for maps, towers, enemies, waves, and level rewards.
- Add at least 10 playable levels across 2 regions with increasing difficulty.
- Add the basic enemy set and at least one boss level.
- Add level objectives and optional star rating if the rules can be explained clearly.
- Add a level select screen with locked/unlocked, completed, and best-result states.
- Add a development content validator that loads every shipped level.

### Deliverables

- Data-driven campaign that can be extended without changing gameplay-system code.

### Acceptance criteria

- Every level loads and references valid assets and IDs.
- Campaign order and unlock requirements are validated.
- The opening levels teach core concepts progressively.
- No level is impossible due to incorrect initial gold, spawn timing, route data, or build-pad configuration.

## Phase 9 — Local Save and Offline Reliability

### Tasks

- Implement versioned `CampaignProgress` serialization.
- Implement save repository with safe writes and load validation.
- Add save migration support from version 1 onward as needed.
- Persist unlocked levels, completion results, best stars/ratings, and settings.
- Add reset-progress and error-recovery UX.
- Ensure gameplay never checks internet connectivity to proceed.
- Add network-disabled integration tests and app relaunch tests.

### Deliverables

- Reliable offline campaign progress and preferences.

### Acceptance criteria

- Progress survives force-close and relaunch.
- Invalid saves do not crash the app or silently overwrite a good backup.
- Saves are not written every frame.
- A clean install and a no-network launch both lead to a playable game.

## Phase 10 — Art, Animation, Audio, and Feedback

### Tasks

- Lock the visual direction and visual asset budget.
- Replace placeholders with production-quality map, tower, enemy, projectile, and effect assets.
- Add clear hit, death, leak, upgrade, build, and wave-transition feedback.
- Add sound effects and optional background music.
- Implement audio controls and reduced-motion handling.
- Optimize images, spritesheets, and audio assets for mobile deployment.
- Add a credits/licenses screen and asset attribution file.

### Deliverables

- Visually coherent and audibly complete gameplay experience.

### Acceptance criteria

- Every gameplay-relevant event is readable without relying on color alone.
- Audio settings persist and mute behavior is consistent.
- No asset license is unknown at release candidate time.
- Effects do not obscure enemies, projectiles, build pads, or essential HUD elements.

## Phase 11 — Tutorial, Balance, and Progression Polish

### Tasks

- Add a short, dismissible first-level tutorial.
- Add a tower/enemy codex that explains stats and special traits.
- Tune tower costs, enemy stats, wave schedules, rewards, and upgrade curves.
- Add campaign rewards and unlock messaging.
- Test strategy diversity: levels should not all require the same tower.
- Add optional difficulty modes only if the default campaign is already balanced.

### Deliverables

- New players can understand the game and experienced players have useful choices.

### Acceptance criteria

- Tutorial steps do not soft-lock when the user performs a valid alternative action.
- Each tower has at least one useful situation in the campaign.
- The first three levels teach mechanics at a manageable pace.
- No level relies on undocumented mechanics or a single mandatory placement with no warning.

## Phase 12 — QA, Performance, and Device Compatibility

### Tasks

- Run all unit, widget, and integration tests.
- Profile a stress level with many enemies, towers, projectiles, and effects.
- Test on representative low/mid/high performance devices where available.
- Test app interruption, incoming calls, screen lock/unlock, orientation/layout edge cases, audio interruptions, and process termination.
- Check memory growth and cleanup after repeated restart/level changes.
- Review crash logs and fix high-severity issues before adding new features.
- Perform a complete offline validation pass.

### Deliverables

- Release candidate with documented known issues and repeatable QA scenarios.

### Acceptance criteria

- No known blocker or data-loss defect remains.
- Representative stress tests meet the agreed frame-rate and memory targets.
- Level restart and repeated navigation do not accumulate stale components or timers.
- Core gameplay passes with network disabled.

## Phase 13 — Release Preparation

### Tasks

- Configure release app IDs, icons, splash screen, versioning, signing, and build flavors if needed.
- Prepare store screenshots, app description, privacy disclosures, and age/content rating answers.
- Audit permissions and remove unused ones.
- Review third-party package licenses and game asset licenses.
- Build and test Android release artifacts and iOS archive/TestFlight build as applicable.
- Test upgrade/install behavior and save compatibility for supported update paths.
- Create a release checklist and rollback/patch procedure.

### Deliverables

- Signed, store-ready Android and iOS builds, subject to the developer's accounts and build environment.

### Acceptance criteria

- Release builds launch and play without development tooling.
- No mandatory permission, account, or network access is present without a documented reason.
- Store materials accurately represent the offline gameplay and monetization model.

## Phase 14 — Post-MVP Enhancements (Optional)

Only start after the core game is stable and released or has passed a release-quality gate.
[`docs/V2_PLAN.md`](docs/V2_PLAN.md) is the concrete v2 slice of this section:
its phases, acceptance criteria, save-migration and measurement rules.

Possible enhancements:

- Additional regions, maps, towers, enemy families, and boss mechanics.
- Endless mode with a separate balance profile.
- Challenge levels and daily/weekly challenges that work from preinstalled local definitions.
- Achievements stored locally.
- Additional target priorities and tower-specific upgrade branches.
- Tower loadouts or a limited pre-level perk system.
- Replay/ghost data using local deterministic event logs, if feasible.
- Optional export/import of save files for device transfer.
- Optional cloud synchronization or cross-device features only as a separate, clearly non-essential online layer.
- Ads or purchases only after evaluating platform policy, user experience, privacy obligations, and whether they fit the offline-first promise.

---

## 9. Game Balance and Content Guidelines

### 9.1 Early balance principles

- A new player should be able to complete the first level using the most basic tower with understandable placement choices.
- Introduce one new tactical concept at a time: fast enemies, tanks, splash damage, control effects, then boss behavior.
- Every tower must have a distinct role; avoid towers that differ only by damage numbers.
- Enemy speed, health, and rewards should make intuitive sense and be visible in the codex.
- Do not use hidden stat changes to create difficulty spikes.
- Loss screens should offer useful feedback without forcing a tutorial or purchase.

### 9.2 Level authoring checklist

Every level must define:

- Unique level and map IDs.
- Valid route and exit location.
- Valid, reachable build pads placed with touchability in mind.
- Starting gold and core health.
- Ordered wave definitions with spawn groups.
- Enemy mix, spawn intervals, and boss timing where applicable.
- Completion reward, next-level/unlock rules, and optional objectives.
- Required art and audio asset references.
- Expected difficulty tier and intended learning objective.
- Test strategy or known viable tower placements for balance verification.

### 9.3 Balancing data

Prefer configuration values to magic numbers. Keep a development-only overlay or diagnostic log that can show:

- Active enemy count and pending spawn count.
- Current simulation speed.
- Gold earned/spent/refunded.
- Damage by tower and enemy type when a run ends.
- Frame time or FPS in profiling builds.

Do not ship debug overlays enabled by default.

---

## 10. Coding Standards and Agent Workflow

This plan is intended to be implementable by a human team or coding agent.

### 10.1 General coding rules

- Use sound null safety and current stable Dart/Flutter conventions.
- Run formatter, analyzer, and tests after every meaningful phase.
- Keep methods and classes focused; avoid god objects.
- Keep gameplay balance in data definitions, not UI widgets.
- Keep rendering classes free of persistence and campaign-unlock logic.
- Use immutable configuration objects and explicit mutable runtime state.
- Document non-obvious gameplay rules, especially event ordering and pause/speed semantics.
- Use stable IDs for content and deterministic tie-breaking for game logic.
- Avoid premature abstractions; add extension points when a second real use case appears.
- Do not add a package without stating why the built-in SDK or existing package is insufficient.
- Do not replace a working architecture or change public model contracts without updating tests, docs, and migration behavior.

### 10.2 Definition of done for every phase

A phase is complete only when:

1. All listed deliverables exist and can be demonstrated.
2. Acceptance criteria are met.
3. Relevant automated tests pass.
4. Static analysis and formatting pass.
5. No new critical error or resource leak is known.
6. README or design docs are updated where behavior, setup, or architecture changed.
7. Changes are integrated and the app remains runnable from a clean checkout.

### 10.3 Suggested coding-agent workflow

For each phase:

1. Inspect the existing repository before editing; do not assume it is empty.
2. Summarize the implementation approach and list files likely to change.
3. Implement the smallest vertical slice that proves the feature end to end.
4. Add or update tests alongside implementation.
5. Run format, static analysis, unit tests, and relevant integration tests.
6. Fix failures rather than suppressing analyzer warnings without explanation.
7. Report completed work, test commands/results, remaining risks, and the next phase's prerequisites.
8. Do not implement later-phase features unless explicitly requested or needed to unblock the current phase.

---

## 11. Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Game logic becomes coupled to Flame components | Hard to test and difficult to balance | Keep authoritative rules in domain/game services; components visualize and forward intent |
| Frame-rate-dependent movement or firing | Unfair gameplay on different devices | Use simulation delta time, clamp large deltas, and test variable frame rates |
| Save corruption or incompatible save formats | Lost campaign progress | Versioned saves, validation, safe writes, backup/recovery, migration tests |
| Levels become impossible due to content mistakes | Frustrating campaign progression | Data validation, automated content-load tests, and per-level balance checks |
| Too much content is created before the core loop works | Rework and schedule risk | Complete one polished vertical-slice level before producing the full campaign |
| Excessive visual effects reduce readability/performance | Poor UX and low frame rate | Asset budget, stress levels, performance profiling, and reduced-motion support |
| Package APIs or platform requirements change | Build failures or outdated setup | Verify current stable versions and official package docs during setup and release preparation |
| Offline promise is undermined by analytics/ads/network checks | App cannot be used in airplane mode or raises trust concerns | Keep network dependencies out of core gameplay and add explicit offline integration tests |
| Feature scope grows before launch | Delayed release | Lock MVP scope and move extra modes/features to Phase 14 |

---

## 12. Milestones and Release Gates

### Milestone A — Technical prototype

Complete Phases 0–3. One map loads, waves spawn enemies, enemies follow a route, and the core can be defeated.

**Gate:** movement, timing, pause behavior, and content validation are reliable.

### Milestone B — Playable combat slice

Complete Phases 4–7. The player can build, target, attack, upgrade/sell, pause, win, lose, and restart a level.

**Gate:** core economy and combat tests pass; no duplicate rewards or invalid state transitions.

### Milestone C — Content-complete MVP

Complete Phases 8–9. At least 10 levels are playable and campaign progress is saved locally.

**Gate:** full campaign can be completed offline and progress survives relaunch.

### Milestone D — Release-quality game

Complete Phases 10–13. Art/audio, tutorial, balance, QA, performance, and store preparation are complete.

**Gate:** release checklist passes on supported target devices; critical bugs and data-loss risks are resolved.

---

## 13. First Playable Vertical Slice

Before building all 10 levels, prove the complete core loop with a single level containing:

- One map and one route.
- Three build pads.
- One tower type.
- One enemy type.
- Three waves with different enemy counts or spawn intervals.
- Gold spending and kill rewards.
- Tower targeting, projectiles, enemy death, and enemy leaks.
- Core health, victory/defeat, pause, and restart.
- Basic result screen and a local completion flag.

This slice is the most important early checkpoint. If it is not fun, readable, stable, and easy to test, improve it before adding towers, enemies, or campaign content.

---

## 14. Release Acceptance Checklist

### Gameplay

- [ ] Build, attack, damage, death, leak, wave completion, victory, and defeat work reliably.
- [ ] Tower upgrades, selling, and target priorities behave as specified.
- [ ] Restart fully resets a level attempt.
- [ ] Pause, resume, and speed controls behave consistently.
- [ ] All campaign levels are completable and their content validates.

### Offline and persistence

- [ ] App launches and all core content loads without internet.
- [ ] A full level can be played with network disabled.
- [ ] Campaign progress and settings persist after force-close/relaunch.
- [ ] Invalid saves are handled safely.
- [ ] No required account or cloud dependency exists.

### Quality

- [ ] Automated tests pass.
- [ ] Static analysis and formatting pass.
- [ ] Performance is tested on representative physical devices.
- [ ] No known critical crash, soft lock, or data-loss defect remains.
- [ ] Accessibility and safe-area checks have been completed.
- [ ] Asset licenses and third-party attributions are documented.

### Release operations

- [ ] App IDs, icons, signing, version numbers, and release builds are configured.
- [ ] Store listing and screenshots are ready.
- [ ] Privacy disclosures and permission usage are accurate.
- [ ] Known issues and post-release patch process are documented.

---

## 15. Official Technical References

Use official documentation as the source of truth during implementation and verify the current released versions before selecting dependencies.

- Flutter application architecture: https://docs.flutter.dev/app-architecture/guide
- Flutter architecture recommendations: https://docs.flutter.dev/app-architecture/recommendations
- Flame engine documentation: https://docs.flame-engine.org/latest/
- Flame game loop and lifecycle: https://docs.flame-engine.org/latest/flame/game.html
- Flame components: https://docs.flame-engine.org/latest/flame/components/components.html
- Flame collision detection: https://docs.flame-engine.org/latest/flame/collision_detection.html

---

## Final Implementation Principle

Build UpTowerDefense as a **small, complete, offline playable game first**, not as a large collection of unfinished systems. The highest priority is a deterministic and testable core loop. Once one level is enjoyable and stable, expand through data-driven towers, enemies, waves, and campaign content. Keep online features optional and outside the critical gameplay path.
