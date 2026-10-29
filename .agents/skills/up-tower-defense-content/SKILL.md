---
name: up-tower-defense-content
description: Author, validate and debug UpTowerDefense game content — maps, enemies, towers, levels and waves — as the JSON assets under assets/data/. This skill should be used whenever a map, enemy, tower, level, wave, build pad, route or balance value is added, changed, tuned or debugged in the UpTowerDefense repo, or when a "level won't load", "content failed validation", "enemy not spawning" or "map not showing" problem needs diagnosing. It encodes the exact JSON schemas, the validator thresholds (route clearance, pad spacing, core-on-waypoint), the catalog registration step and the content test gate.
agent_created: true
---

# UpTowerDefense — content authoring and validation

Content is data, not code. Towers, enemies, maps, levels and waves live as JSON
under `assets/data/`, and the game reads them at load time. Balancing therefore
never touches gameplay or UI code.

Full field-by-field format reference: `docs/CONTENT_AUTHORING.md` in the repo.
This skill carries the operational rules and the validator thresholds that the
reference documents state but do not spell out numerically.

---

## 1. Where things live

| Kind | Path | Registry |
|---|---|---|
| Map | `assets/data/maps/<id>.json` | `ContentCatalog.mapAssetsById` — **must be registered** |
| Enemy | `assets/data/enemies/enemies.json` (one shared catalog) | self-registered |
| Tower | `assets/data/towers/towers.json` (one shared catalog) | self-registered |
| Level | `assets/data/levels/<id>.json` | `assets/data/campaign.json` — **must be listed**, in play order |
| Campaign | `assets/data/campaign.json` | `ContentCatalog.campaign` |

The four data directories and `campaign.json` are declared in `pubspec.yaml`
under `flutter/assets`, so **adding a file needs no manifest change**. A *new map*
needs a `ContentCatalog` entry; a *new level* needs a campaign entry.

A level's id **is** its file name: `ContentCatalog.levelAssetFor(id)` derives the
path, and `campaign_assets_test` asserts the campaign lists exactly the level
files that ship.

---

## 2. The content gate

`test/unit/content_assets_test.dart` loads **every shipped file** through the
production repositories. It fails the test run — not a player's session — when:

- any shipped file fails to decode or validate;
- a shipped map is missing from `ContentCatalog.mapAssetsById`;
- a level's `mapId` or any `enemyId` does not resolve;
- a level's starting gold cannot afford **any** tower in the catalog.

`test/unit/campaign_assets_test.dart` is the campaign gate: the campaign must
cover exactly the shipped level files, every level must load, campaign names must
match level names, each level must give the player gold, at least two pads, a
build window before wave one and at least 8 seconds of route for its fastest
enemy, and the boss must be the finale.

Fast authoring loop (pure Dart, no emulator, no asset bundle):

```bash
dart run tool/validate_content.dart
```

Always run the gates after a content edit:

```bash
flutter test test/unit/content_assets_test.dart test/unit/campaign_assets_test.dart
```

In the sandboxed IDE shell the proxy variables break `flutter_tester`; run the
suite with the proxy unset:

```bash
env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy \
  flutter test test/unit/content_assets_test.dart
```

---

## 3. Map authoring

### Schema

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

### Validator thresholds (`MapValidator`)

These are exact. `MapValidator` reports **every** problem at once, so one run
tells the whole story.

| Rule | Threshold | Failure message shape |
|---|---|---|
| World dimensions | `> 0` | `world must have positive dimensions` |
| Build pad radius | `> 0` | `buildPadRadius must be positive` |
| Route waypoints | `>= 2` | `route needs at least two waypoints` |
| Consecutive waypoint distance | `>= 1` unit | `route[i] ... duplicates route[i-1]` |
| Waypoints inside world | required | `route[i] ... lies outside the world bounds` |
| Core on final waypoint | `<= 0.5` units | `core ... must sit on the final waypoint` |
| Pad edge to map border | `>= buildPadRadius + 8` | `build pad ... is too close to the map edge` |
| Pad edge to route | `>= buildPadRadius + 8` | `build pad ... overlaps the enemy route` |
| Pad centre to core | `>= buildPadRadius + 8` | `build pad ... is too close to the core` |
| Pad centre to pad centre | `>= buildPadRadius * 2 + 8` | `build pads ... are too close` |
| Pad ids | unique | `build pad id "..." is duplicated` |
| Pad labels | non-blank | `build pad "..." needs a label` |
| Pad count | `>= 1` | `map needs at least one build pad` |

**Distance to the route is measured from the pad *edge*, so the required
pad-centre distance is `buildPadRadius + 8`.** Getting this wrong is the most
common authoring error — a pad at exactly 40 units from the route line passes a
naive eyeball check but fails validation at 34 + 8 = 42.

### Coordinate discipline

- Coordinates are **world units, not pixels**. The camera renders the map at a
  fixed resolution and letterboxes off-ratio screens.
- The renderer draws a grid every 80 units, a 36-unit-wide route, and pads at
  their centres with their `label`.
- Keep routes at least ~24 units from the world edge so the stroked path stays
  on screen.
- Keep waypoints far enough from pads that a passing enemy never hides a pad
  label.
- The **core must sit on the final waypoint** (±0.5). "Reached the end of the
  route" and "reached the core" are the same event by design.

### Adding a map

1. Create `assets/data/maps/<id>.json`.
2. Register it in `ContentCatalog.mapAssetsById` — **required**; the catalog test
   asserts the map list matches the shipped files exactly.
3. Reference it from a level's `mapId`.
4. Run `flutter test test/unit/content_assets_test.dart`.
5. Play it on a device in landscape before calling it done.

---

## 4. Enemy catalog

One shared file, `assets/data/enemies/enemies.json`. Levels reference enemies
by `id`.

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

| Field | Rule |
|---|---|
| `id` | non-blank, unique in the catalog |
| `displayName` | non-blank |
| `maxHealth` | `> 0` |
| `speed` | `> 0`, **world units per second** |
| `coreDamageOnLeak` | `> 0` |
| `rewardGold` | `>= 0` (zero is allowed for a pure core-drain enemy) |
| `radius` | `> 0`, world units |
| `color` | `#RRGGBB` or `#AARRGGBB` |

Colour is never the only cue — health bars and silhouettes carry the state too.

**Balance scale:** routes run roughly 1500–2000 units, so `speed` 40–160 spans
slow tanks to fast runners. A grunt at 80 units/s crosses the opening map in
about 20 seconds.

**Economy scale:** `rewardGold` is paid exactly once, on defeat. A leaked enemy
pays nothing, so a leak costs both core health and income. At 10 gold per
grunt, a 70-gold tower is roughly 6–8 kills.

---

## 5. Tower catalog

One shared file, `assets/data/towers/towers.json`. The build panel lists towers
cheapest first, so the cheapest tower is the intended opening choice.

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

| Field | Rule |
|---|---|
| `id` | non-blank, unique |
| `displayName`, `role`, `description` | non-blank |
| `buildCost` | integer `> 0` |
| `sellRefundRate` | in `[0, 1]`; refunds `floor(rate × invested gold)` |
| `color` | `#RRGGBB` or `#AARRGGBB` |
| `levels` | non-empty; index 0 is the built tower, the last entry is max level |
| `levels[].damage`, `range`, `fireCooldownSeconds`, `projectileSpeed` | all `> 0` |
| `levels[].splashRadius` | optional, `>= 0`; 0 or absent means single target |
| `levels[].slow` | optional `{ magnitude (0,1], durationSeconds > 0, minSpeedRatio (0,1] }` |
| `levels[].upgradeCost` | positive on every level except the last; omitted on the last |

**Every stat is read from the current level.** Cooldowns, range checks, the drawn
range circle and the panel all go through `TowerInstance.stats`; reading the
definition's base level anywhere makes an upgrade cosmetic in that place.

**Balance scale:** `range` 180–260 covers a readable corner of a 1280×720 field.
Upgrade costs sit below the build cost so reinvesting in a placed tower is the
cheaper way to scale.

---

## 6. Levels and waves

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
          "count": 6,
          "spawnIntervalSeconds": 1.2,
          "initialDelaySeconds": 2.0
        }
      ]
    }
  ]
}
```

| Field | Rule |
|---|---|
| `id`, `displayName` | non-blank; `id` is the file name and must be in `campaign.json` |
| `mapId` | must resolve in the map catalog (fails earlier, in `LevelRepository`) |
| `coreHealth` | integer `> 0` |
| `startingGold` | integer `>= 0`, and must afford at least one tower |
| `waveTransitionSeconds` | `> 0`, default `5`; the countdown before the next wave auto-starts |
| `waves` | at least one; wave ids unique and non-blank |
| `waves[].groups` | at least one group per wave |
| `groups[].enemyId` | must resolve in the enemy catalog |
| `groups[].count` | integer `> 0` |
| `groups[].spawnIntervalSeconds` | `> 0` |
| `groups[].initialDelaySeconds` | `>= 0`, default `0` |

Groups inside one wave spawn independently on the same simulation clock, so a
wave can mix a slow trickle with a late burst.

### Design rules that follow from the engine

- **Waves never overlap.** The next wave starts only after the previous one has
  no enemies left, so *total enemy count per wave* is the real difficulty lever.
- **Waves auto-start after the countdown**; the player may start early from the
  HUD. Give wave one at least 1 second of `initialDelaySeconds` so there is time
  to place the first tower.
- **Gold is earned per kill, never per wave.** A wave that leaks pays less than
  one that is cleared.
- **`startingGold` decides how many towers exist before wave 1.** With the
  shipped 70-gold ranger, 160 gold allows two towers or one tower plus a reserve.
- **`coreHealth` and `coreDamageOnLeak` together define how many mistakes a
  level forgives.** A level is not hard because of a low core health alone.
- Keep a wave's spawn window in the order of 20 seconds so the field stays
  readable.
- A level must be beatable with the most basic tower, and must not require one
  hidden or undocumented placement.
- Stars are one global rule (core untouched = 3, at least half = 2, finished = 1,
  defeat = 0), so there is no per-level objective data to author.

### Adding a level

1. Create `assets/data/levels/<id>.json` — the file name is the level id.
2. Reference an existing `mapId` and existing enemy ids only.
3. Add `{ "id": "<id>", "displayName": "<same as the level>" }` to the right
   region of `assets/data/campaign.json`, in play order.
4. Run `dart run tool/validate_content.dart`, then the two content gates.
5. Play it on a device in landscape, including one full run to victory.

---

## 7. Diagnosing content problems

| Symptom | Likely cause | Fix |
|---|---|---|
| `Level could not be loaded` screen | decode or validation failure | read the debug-mode error text on the error screen; it carries every issue |
| `build pad ... overlaps the enemy route` | pad centre less than `radius + 8` from the route | move the pad outward |
| `core ... must sit on the final waypoint` | core authored off the route end | set the core to the last waypoint |
| `the catalog must list every shipped map` | new map not registered | add it to `ContentCatalog.mapAssetsById` |
| `... starts with too little gold to build anything` | `startingGold` below the cheapest tower cost | raise `startingGold` or lower the tower cost |
| Enemy never appears | `enemyId` typo, or the wave has not started | check ids; the first wave starts from the HUD, later ones after the countdown |
| Enemy spawns but stops short | `speed` too low for the route length | check `speed` in world units per second |
| Map renders but pads are untappable | pad outside the world bounds or behind the HUD | check pad placement against the HUD safe area |
| Content test passes but the level 404s | level file not in `assets/data/levels/` | move it into the declared directory |
| Level exists but the picker does not show it | not listed in `campaign.json` | add it to the right region in play order |
| `campaign.json: "x" is called "y" but the level file says "z"` | campaign name drifted | make the two names match |

---

## 8. House style for content files

- ASCII only.
- 2-space indentation.
- One enemy, tower, wave, group or pad object per line.
- One map per file; one level per file; one shared enemy catalog; one shared
  tower catalog; one campaign file ordering every level.
- Stable, descriptive ids (`meadow_gate`, `grunt`, `ranger`, `pad_a`). Ids go
  into saves, so **never rename an id that has shipped**.
