# Content authoring

Content ships as data files inside the app bundle; nothing is downloaded. This
page covers the formats that exist today: maps, the enemy catalog, the tower
catalog, and levels (with their waves and starting gold). Tower upgrade stats
join the tower format in Phase 6.

Every file goes through `flutter test test/unit/content_assets_test.dart`, which
loads **all** shipped content through the production repositories. A malformed or
invalid file fails the test run instead of the player's session.

## Maps

Maps live in `assets/data/maps/` and are listed in `pubspec.yaml` under
`flutter/assets`. `ContentCatalog.mapAssetsById` lists every map id the levels may
reference.

### Format

```json
{
  "id": "meadow_gate",
  "displayName": "Meadow Gate",
  "world": [1280, 720],
  "buildPadRadius": 34,
  "route": [[0, 500], [300, 500], [300, 260]],
  "core": [1150, 500],
  "buildPads": [
    { "id": "pad_a", "label": "A", "center": [180, 360] }
  ]
}
```

| Field | Type | Meaning |
|---|---|---|
| `id` | non-empty string | Stable map id, used by levels and saves. |
| `displayName` | non-empty string | Player-facing name (localisation keys arrive with the codex phase). |
| `world` | `[width, height]` | Playfield size in world units. Both must be positive. |
| `buildPadRadius` | number > 0 | Radius of every build pad on this map. |
| `route` | list of `[x, y]` | Ordered enemy waypoints. At least two, all inside the world, no zero-length steps. |
| `core` | `[x, y]` | The protected core. Must sit on the final waypoint. |
| `buildPads` | list of pads | Predefined tower spots. At least one. |

Coordinates are in **world units**, not pixels. The camera renders the map at a
fixed resolution and letterboxes off-ratio screens, so a map looks the same on
every device instead of stretching.

### Validation rules

`MapValidator` runs before a map is used and reports every problem at once.
`MapRepository` turns them into a `ContentLoadException`, which the gameplay
screen shows with a retry action and, in debug builds, the full diagnostics.

- `id` and `displayName` are not blank.
- World dimensions and `buildPadRadius` are positive.
- Route: ≥ 2 waypoints, consecutive waypoints ≥ 1 unit apart, all inside bounds.
- Core: inside bounds and on the final waypoint (± 0.5 units).
- Pads: unique ids, non-empty labels, at least 8 units of clearance from the map
  edge and from the route (measured from the pad edge), at least 8 units between
  pads, and clear of the core.
- At least one pad.

Two rules sit outside `MapValidator`, because both are facts about the shipped
game rather than about map geometry, and `content_assets_test` enforces them on
every shipped map:

- **Reach.** Every pad must sit within the base range of the **shortest**-ranged
  tower. Validation alone would pass a pad that is clear of the route yet still
  beyond every tower's reach — a spot where the player pays build gold for a
  tower that can never fire — so the content gate closes it instead.
- **Top HUD strip.** A pad's top edge must stay below the top **25% of the map**.
  The gameplay HUD (back button, level chip, gold/health/wave chips, pause,
  speed) is an overlay pinned to the top of the screen, and the camera fits the
  map to the full screen height on any screen at least as wide as the world, so
  the strip it covers is the same fraction of the map as of the screen — about
  88 px of a 360 px landscape screen, status bar included. A widget there takes
  the tap as well as the view, so a pad behind one can be neither seen nor
  opened: ember's pads E and F shipped at `y=60`/`y=110` and were reported as
  "the level name covers the tower spot".

Because only pads can be selected, and pads are validated to stay clear of the
route, enemy pathing can never be blocked by player building.

### Adding a map

1. Add `assets/data/maps/<id>.json`. The `assets/data/maps/` directory is already
   declared in `pubspec.yaml`, so no manifest change is needed.
2. Keep the file ASCII, 2-space indented, one pad per line, as in the sample.
3. Run `flutter test test/unit/content_assets_test.dart`. It loads **every**
   shipped map through the repository and checks the catalog lists them all, so a
   malformed or invalid file fails the test run.
4. Play it once on a device in landscape before calling the map done.

### Drawing notes

The renderer draws a grid every 80 world units, a 36-unit-wide route with a
lighter centre line, the core at `core`, and pads at their centres labelled with
`label`. Keep routes at least ~24 units from the world edge so the stroked path
stays on screen. Enemies are drawn at their exact route distance, so waypoints
must be far enough from pads that a passing enemy never hides a pad label.

## Enemies

The enemy catalog lives in `assets/data/enemies/enemies.json` and is shared by
every level. Add an enemy here once; levels reference it by `id`.

### Format

```json
{
  "enemies": [
    {
      "id": "grunt",
      "displayName": "Grunt",
      "maxHealth": 100,
      "speed": 80,
      "coreDamageOnLeak": 1,
      "rewardGold": 10,
      "radius": 14,
      "color": "#D96B5B"
    }
  ]
}
```

| Field | Type | Meaning |
|---|---|---|
| `id` | non-empty string | Stable id used by waves and saves. Unique in the catalog. |
| `displayName` | non-empty string | Player-facing name (used by the codex later). |
| `maxHealth` | number > 0 | Health a fresh instance starts with. |
| `speed` | number > 0 | Movement speed in **world units per second**. |
| `coreDamageOnLeak` | integer > 0 | Core health removed when this enemy reaches the end of the route. |
| `rewardGold` | integer ≥ 0 | Gold granted when this enemy is defeated. Leaking pays nothing. |
| `radius` | number > 0 | Draw radius in world units; also the body size players aim at. |
| `color` | `#RRGGBB` or `#AARRGGBB` | Body colour. Colour is never the only cue; health bars carry state. |

### Validation rules

`EnemyValidator` reports every problem at once:

- The catalog is not empty.
- `id` is not blank and is unique.
- `displayName` is not blank.
- `maxHealth`, `speed`, `radius` and `coreDamageOnLeak` are positive.
- `rewardGold` is not negative (zero is allowed for an enemy that only exists to
  drain core health).

### Adding an enemy

1. Add an entry to `enemies.json` (2-space indent, one enemy per object).
2. Run `flutter test test/unit/content_assets_test.dart`; it decodes the shipped
   catalog through `EnemyRepository`.
3. Give it a wave in a level and play that level before calling it done.

Speeds are in world units per second against routes of roughly 1.5k–2k units, so
`40`–`160` covers slow tanks to fast runners on the current maps.

## Towers

The tower catalog lives in `assets/data/towers/towers.json` and is shared by
every level: it is the list of towers the player may build. Build cost, refund
rate, and every per-level stat — damage, range, fire cooldown, projectile speed,
blast radius and slow — come from here, so balancing never touches gameplay or UI
code.

A tower holds an ordered `levels` array. Index 0 is the freshly built tower and
the last entry is the maximum level; each entry carries the `upgradeCost` of
reaching the level *after* it, so the last level omits that field.

### Format

```json
{
  "towers": [
    {
      "id": "ranger",
      "displayName": "Ranger Tower",
      "role": "Fast single target",
      "description": "Cheap, quick shots that pick off the leading enemy.",
      "buildCost": 70,
      "sellRefundRate": 0.6,
      "color": "#4FD1C5",
      "levels": [
        { "damage": 18, "range": 210, "fireCooldownSeconds": 0.7, "projectileSpeed": 600, "upgradeCost": 60 },
        { "damage": 27, "range": 225, "fireCooldownSeconds": 0.66, "projectileSpeed": 600, "upgradeCost": 95 },
        { "damage": 40, "range": 245, "fireCooldownSeconds": 0.6, "projectileSpeed": 600 }
      ]
    }
  ]
}
```

Effects are optional per level. `splashRadius` spreads a hit — and any `slow`
the projectile carries — to every enemy in the blast; the Cannon and the
Frost both ship one. A Frost level adds a `slow` object:

```json
{
  "damage": 34,
  "range": 200,
  "fireCooldownSeconds": 1.6,
  "projectileSpeed": 380,
  "splashRadius": 70,
  "upgradeCost": 90
}
```

```json
{
  "damage": 4,
  "range": 190,
  "fireCooldownSeconds": 1.2,
  "projectileSpeed": 420,
  "slow": { "magnitude": 0.4, "durationSeconds": 2.5, "minSpeedRatio": 0.4, "damageAmp": 0.25 },
  "upgradeCost": 65
}
```

Top-level fields:

| Field | Type | Meaning |
|---|---|---|
| `id` | non-empty string | Stable id used by builds and saves. Unique in the catalog; never rename a shipped id. |
| `displayName` | non-empty string | Shown in the build and tower panels. |
| `role` | non-empty string | Short role line, for example `Fast single target`. |
| `description` | non-empty string | One sentence explaining what the tower is for. |
| `buildCost` | integer > 0 | Gold deducted when the tower is built. |
| `sellRefundRate` | number in [0, 1] | Share of total invested gold returned on sell; `0.6` is the MVP default. |
| `color` | `#RRGGBB` or `#AARRGGBB` | Body colour; the panel also shows the role text, so colour is not the only cue. |
| `levels` | non-empty array | One entry per level, index 0 = level 1. |

Per-level fields:

| Field | Type | Meaning |
|---|---|---|
| `damage` | number > 0 | Damage per hit. Splash applies this same value to every victim. |
| `range` | number > 0 | Attack radius in **world units**, measured from the pad centre. |
| `fireCooldownSeconds` | number > 0 | Simulation-time gap between shots at this level. |
| `projectileSpeed` | number > 0 | Shot speed in **world units per second**. A slow shot (Cannon) stays visible in flight longer. |
| `splashRadius` | number >= 0, optional | Blast radius in **world units**; omitted or `0` means the hit only touches its target. |
| `slow` | object, optional | Slow applied by this level's hits; omitted means the tower only damages. |
| `slow.magnitude` | number in (0, 1] | Fraction of base speed removed, so `0.4` means 60% speed. |
| `slow.durationSeconds` | number > 0 | Simulation seconds the slow lasts; refreshed by an equal or stronger hit. |
| `slow.minSpeedRatio` | number in (0, 1] | Floor for the slowed speed as a fraction of base speed; no stack of slows can go below it. |
| `slow.damageAmp` | number in [0, 1], optional | Extra damage fraction a chilled target takes from **every** source while the slow is active, so `0.25` turns a 26-damage shell into 32.5 health removed. Omitted or `0` means the chill only moves it. |
| `upgradeCost` | integer > 0, optional | Gold to reach the next level. Required on every level except the last, and forbidden on the last. |

### Validation rules

`TowerValidator` reports every problem at once:

- The catalog is not empty.
- `id` is not blank and is unique.
- `displayName`, `role` and `description` are not blank.
- `buildCost` is a positive integer; `sellRefundRate` is in [0, 1].
- `levels` is not empty, and every level has positive `damage`, `range`,
  `fireCooldownSeconds` and `projectileSpeed`.
- `splashRadius` is not negative.
- `slow.magnitude` and `slow.minSpeedRatio` are in (0, 1]; `durationSeconds` is
  positive; `damageAmp`, when present, is in [0, 1].
- Every level except the last has a positive `upgradeCost`; the last level omits
  it.

### Adding a tower

1. Add an entry to `towers.json` (2-space indent, one level object per line).
2. Run `flutter test test/unit/content_assets_test.dart`; it decodes and validates
   the shipped catalog, and checks that every level can afford at least one tower
   with its starting gold.
3. Build it in a level and play a wave with it before calling it done — including
   one upgrade, so the level-2 stats are exercised too.

### Balance notes

- The build panel lists towers cheapest first, so the intended opening choice is
  the first row.
- Ranges are in world units on a 1280x720 field with routes around 1.5k units
  long; `180`–`260` covers one corner of the map and is a readable circle at
  gameplay scale.
- A tower costs roughly 6–8 grunt kills (`70` gold against `10` gold per grunt),
  so the opening minutes are about deciding where the first tower goes rather
  than about grinding for the second.
- Upgrades are priced below the build cost on purpose: reinvesting in a placed
  tower is the cheaper way to scale, which keeps the early pads relevant.
- The refund is `sellRefundRate × (build + every upgrade)`, floored. A tower sold
  after two upgrades therefore returns 60% of everything spent on it, not 60% of
  the build cost, so the panel's `Sell for` number is the exact payout.
- Every tuning change can be measured headlessly:
  `dart run tool/balance_probe.dart` replays all ten levels through the real
  session under fixed build plans and prints outcome, core health, leaks and
  kills per strategy — judge a tweak on those numbers, not on feel. Its
  order-matched control strategies exist so a support tower is compared against
  a damage tower in the *same* pad slot, which is the question a balance change
  actually has to answer.

### Tuning workflow

When you change balance data (`towers.json`, `enemies.json`, a level or a map):

1. **Validate, then measure:** `dart run tool/validate_content.dart`, then
   `dart run tool/balance_probe.dart`.
2. **Read the `Simulated outcomes` table against the right control.** Each
   strategy is judged against the control that builds the *same pads in the same
   order* — `frost control` against `rangers only`, and any custom plan against
   its all-ranger twin. A comparison across different pad orders measures the
   build order, not the tower (D56: order alone moves ember_03 by 4 core).
3. **Run the gate:** `flutter test test/unit/balance_regression_test.dart`
   fails whenever the data moved the pinned numbers — opening pacing, or any of
   the 28 pinned campaign outcomes (`meadow_04`…`ember_05` × 4 strategies,
   each pinned as `(victory, coreHealth, leaks)`).
4. **Update the pins in the same change as the data:** edit the
   `_pinnedOutcomes` table in `test/unit/balance_regression_test.dart` only
   after re-reading the probe's table — the pin is a record of a decision, so a
   failing pin means re-measure and decide, never edit it to silence the test.
   Intentional balance moves also get a row in the GAME_DESIGN decisions log
   (the D54–D57 pattern).

## Campaign

`assets/data/campaign.json` orders the campaign. Regions group levels for
pacing and presentation; the **flattened order** is the unlock order — a level
opens once the level before it is completed, including across a region boundary.

### Format

```json
{
  "regions": [
    {
      "id": "meadow",
      "displayName": "Meadow Reach",
      "levels": [
        { "id": "meadow_01", "displayName": "First Light" },
        { "id": "meadow_02", "displayName": "Quick Feet" }
      ]
    },
    {
      "id": "ember",
      "displayName": "Ember Pass",
      "levels": [
        { "id": "ember_01", "displayName": "Cinder Gate" }
      ]
    }
  ]
}
```

| Field | Type | Meaning |
|---|---|---|
| `regions` | non-empty list | Play order; each region is shown as a section in the picker. |
| `regions[].id` | non-empty string | Stable region id; unique. |
| `regions[].displayName` | non-empty string | Region heading in the picker. |
| `regions[].levels` | non-empty list | Ordered levels; this order is the unlock order. |
| `levels[].id` | non-empty string | Level id and file name (`assets/data/levels/<id>.json`); unique across the campaign. |
| `levels[].displayName` | non-empty string | Shown in the picker. Must match the level file's `displayName`. |

The name lives here so the picker renders the whole campaign without loading a
bundle per level; both the content test and the validator fail if it drifts from
the level file.

### Validation rules

`CampaignValidator` (and `tool/validate_content.dart`) reports:

- At least one region; region ids are not blank and are unique.
- Every region has at least one level.
- Level ids are not blank, are unique across the whole campaign, and resolve to a
  shipped level file.
- Every shipped level file appears in the campaign exactly once.
- Each entry's `displayName` matches the level file.

## Levels

Levels live in `assets/data/levels/`, one file per level, and bundle a map id,
the starting core health, the wave pacing, and the ordered waves. A level's id is
its file name and it must be listed in `campaign.json`; the Play button opens the
campaign's first unfinished level.

### Format

```json
{
  "id": "meadow_01",
  "displayName": "First Light",
  "mapId": "meadow_gate",
  "coreHealth": 20,
  "startingGold": 160,
  "waveTransitionSeconds": 5,
  "waves": [
    {
      "id": "wave_01",
      "groups": [
        {
          "enemyId": "grunt",
          "count": 5,
          "spawnIntervalSeconds": 1.4,
          "initialDelaySeconds": 2.0
        }
      ]
    }
  ]
}
```

| Field | Type | Meaning |
|---|---|---|
| `id` | non-empty string | Stable level id used by saves, unlocks and the campaign; it is also the file name. |
| `displayName` | non-empty string | Shown in the gameplay HUD and the campaign picker; the campaign entry must use the same name. |
| `mapId` | non-empty string | Must resolve in `ContentCatalog.mapAssetsById`. |
| `coreHealth` | integer > 0 | Core health the attempt starts with. |
| `startingGold` | integer ≥ 0 | Gold the attempt starts with, before any kills. |
| `waveTransitionSeconds` | number > 0 | Optional (default `5`); simulation seconds between a cleared wave and the next one starting on its own. The player can always start early. |
| `objectives` | list of objectives | Optional; 0 or exactly 2. Every campaign level must declare 2, the endless level none, fixtures may skip them. See [Objectives](#objectives). |
| `objectives[].kind` | one of `noLeaks`, `maxTowers`, `deadlineSeconds`, `coreAbove` | The goal; the player-facing sentence is derived from it, never authored. |
| `objectives[].value` | integer | Required for every kind except `noLeaks`, which takes no value. |
| `waves` | list of waves | Ordered; at least one. |
| `waves[].id` | non-empty string | Unique within the level. |
| `waves[].groups` | list of groups | At least one per wave. |
| `groups[].enemyId` | non-empty string | Must resolve in the enemy catalog. |
| `groups[].count` | integer > 0 | How many enemies this group spawns. |
| `groups[].spawnIntervalSeconds` | number > 0 | Gap between two spawns of the group. |
| `groups[].initialDelaySeconds` | number ≥ 0 | Optional (default `0`); delay before the group's first spawn, measured from the wave start. |

Groups inside one wave spawn independently on the same simulation clock, so a
wave can mix a slow trickle with a late burst.

### Validation rules

`LevelValidator` runs after the level's map and enemy catalog are loaded and
reports every problem at once:

- `id` and `displayName` are not blank; `coreHealth` is positive and
  `startingGold` is not negative.
- `waveTransitionSeconds` is positive.
- `mapId` matches the map that was loaded (an unknown map fails earlier, in
  `LevelRepository`).
- At least one wave; wave ids are unique and not blank.
- Every wave has at least one group.
- Every `enemyId` resolves; `count` and `spawnIntervalSeconds` are positive;
  `initialDelaySeconds` is not negative.
- `objectives` holds 0 or exactly 2 entries, with no repeated kind; the endless
  level declares none, because its run can only end in defeat.
- `maxTowers` is at least 1 and no more than the map's pad count;
  `deadlineSeconds` is positive and no shorter than the level's minimum spawn
  duration (the sum of each wave's longest group, since waves never overlap);
  `coreAbove` is at least 1 and strictly below `coreHealth`, so it can never
  restate `noLeaks`.
- The content gate also checks that `maxTowers` is affordable from the level's
  starting gold at the cheapest tower's build cost.

### Objectives

A level can declare two goals beyond finishing it (D68). They are data, and the
text a player reads is derived from the kind and value, so an authored goal can
never disagree with the rule it names:

```json
"objectives": [
  { "kind": "noLeaks" },
  { "kind": "maxTowers", "value": 2 }
]
```

| Kind | Value | Reads as | Authoring advice |
|---|---|---|---|
| `noLeaks` | none | Take no leaks | Use on levels where the route is already understood; it is the strictest goal. |
| `maxTowers` | towers ≥ 1 | Never have more than N towers standing | Keep `N × cheapest tower cost` within `startingGold`; the gate enforces it. Selling does not lower the count. |
| `deadlineSeconds` | seconds > 0 | Finish within N seconds | Must clear the level's minimum spawn duration; that is a floor, not a target — aim well above it. |
| `coreAbove` | health ≥ 1 | Keep at least N core health | Must stay below `coreHealth`, so it can never duplicate `noLeaks`. |

Because stars are `1 + met`, a campaign level with two goals has an unbroken
2- and 3-star ladder; a level with a single goal would cap at two stars and is
rejected. Pair goals that pull in different directions (defence and economy,
speed and safety) rather than two that fail together.

Status: the goals are authored and validated now; the star rule, HUD and result
lines that read them land with V2-3. Until then the shipped build still rates
core health and does not show the goals.

### Adding a level

1. Add `assets/data/levels/<id>.json` (the directory is already declared in
   `pubspec.yaml`). The file name **is** the level id.
2. Reference an existing `mapId` and existing enemy ids only.
3. Add the level to `assets/data/campaign.json` in the position it should be
   played — a level that is not in the campaign can never be opened.
4. Run `dart run tool/validate_content.dart`, then
   `flutter test test/unit/campaign_assets_test.dart`; between them they check
   that the level loads, its references resolve, its campaign name matches, and
   it gives the player gold, pads and time before the first enemy.
5. Play it on a device in landscape, including one full run to victory.

### Wave design notes

- Waves never overlap: the next wave starts only after the previous one has no
  enemies left on the field, so total enemy count per wave is the real difficulty
  lever.
- A grunt crosses the opening map in about 20 seconds at `80` units/s; keep a
  wave's spawn window in that order of magnitude so the field stays readable.
- Leaked enemies cost `coreDamageOnLeak`, not a share of the core: `coreHealth`
  and the leak damage together define how many mistakes a level forgives.
- Gold is earned per kill (`rewardGold`), never per wave, so a wave that leaks
  pays less than one that is cleared. `startingGold` decides how many towers the
  player can place before the first wave; with the shipped `ranger` at `70` gold,
  `150` allows two towers or one tower and a reserve.
