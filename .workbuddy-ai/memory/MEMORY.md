# UpTowerDefense — project memory

## Project

Offline-first 2D tower defense, Flutter + Flame, Android and iOS. No account, no
server, no network on any gameplay path. App ID `com.uptowerdefense.game`.

Current status: **Phase 8 complete** — campaign of 10 levels across 2 regions
with a boss, level picker with locks and stars, in-memory progress. Phase 9
(versioned local save) is next.

## Toolchain

Flutter 3.47.7 · Dart 3.13.5 · Flame 1.38.2 · Riverpod 3.4.3 · go_router 18.1.1 ·
shared_preferences 2.5.6 · meta 1.18.3 · flame_lint 1.4.4.

## Commands

```bash
flutter analyze
env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy flutter test
dart format --line-length 80 lib test
```

The `env -u` prefix is **required** in the sandboxed IDE shell: the proxy
variables intercept `flutter_tester`'s local WebSocket and every test fails with
`Unable to connect to flutter_tester process: WebSocketException: Invalid
WebSocket upgrade request`. `flutter analyze` and `dart format` are unaffected.

## Non-negotiable architecture rule

ADR 0001 (`docs/adr/0001-flutter-flame-layer-boundaries.md`): five layers, one
dependency direction — Flutter presentation → Flame presentation → application
→ domain (plain Dart) → data.

- Domain imports no Flutter, no Flame, no screen dimensions.
- Flame components never own gold, outcome, upgrade costs or unlocks.
- Time enters the domain only as an explicit `dt`.
- Per-frame entity state never flows through global UI providers.

## Conventions

- `package:up_tower_defense/...` imports, never relative.
- `dart format --line-length 80`.
- `flame_lint` with strict casts/inference/raw-types; fix warnings, don't
  suppress.
- Every public class and non-obvious member gets a `///` doc comment explaining
  *why*.
- Balance values live in JSON under `assets/data/`, never in widgets or combat
  code.
- Stable ids everywhere; they go into saves, so never rename a shipped id.

## Gates

`flutter analyze`, `flutter test` and `dart format` must all pass before a
phase is done. Baseline at 2026-10-26 (after Phase 8): analyze clean, 286 tests
passing, 116 files formatted. Content gate: `dart run tool/validate_content.dart`.

## Campaign rules (Phase 8)

- `assets/data/campaign.json` orders regions → levels; the flattened order is the
  unlock order (a level opens when the previous one is completed).
- A level id **is** its file name (`assets/data/levels/<id>.json`); the campaign
  must list exactly the shipped level files (`campaign_assets_test`).
- Stars: 3 = core untouched, 2 = at least half, 1 = finished, 0 = defeat. One
  global rule, not per-level data.
- Progress is in memory until Phase 9; `CampaignProgress` is already the shape
  that gets persisted.
- `/play` resumes the first unfinished level; `/play/:levelId` is a sibling route
  so back is one step to the menu.
- Widget tests must override `campaignProvider` and `levelBundleProvider` with
  fixtures: real asset loading inside `pumpAndSettle` never settles.

## Level flow rules (Phase 7)

- Phases: `ready`, `playing`, `waveTransition`, `victory`, `defeat`. Pause is not
  a phase — it withholds time (`LevelController.isPaused` + engine pause).
- Every phase change goes through `LevelSession._enterPhase`, which asserts
  `LevelPhaseTransitions.isLegal`. Add an edge there before adding a rule.
- Waves auto-start after `LevelDefinition.waveTransitionSeconds`; the same HUD
  control starts early. Terminal phases consume no time and hold no spawns/shots.
- Restart resets the session in place; the game clears `fxLayer` and the pad
  selection, which it owns.

## Tower stats rule (learned the hard way in Phase 6)

Every stat is read from `TowerInstance.stats` (the current level), never from
`TowerDefinition.baseStats`. Phase 5 shipped two places that read the base value
— the shot cooldown and the drawn range circle — so upgrades silently bought
damage only. Any new consumer of tower stats goes through the instance.

## Content pipeline

`test/unit/content_assets_test.dart` loads every shipped JSON through the
production repositories — it is the content gate. `test/unit/offline_guard_test.dart`
enforces that the release Android manifest declares no permissions. Do not
weaken either to make a change pass.

## Agents

- `AGENTS.md` at the repo root — the operating contract for coding agents.
- Project skills in `.workbuddy-ai/skills/`: `up-tower-defense-content`,
  `up-tower-defense-gameplay-feature`, `up-tower-defense-phase-review`,
  `flutter-dev` (pinned copy of the user-level Flutter guide; also still exists
  at user level by the user's choice).
- `.agents/skills/` mirrors those same four skills for other coding agents
  (committed, not ignored). Two copies of each skill now exist — keep them in
  sync, or symlink `.agents/skills/<name>` at the `.workbuddy-ai` original.
  Claude Code / Kiro / Windsurf read their own paths (`.claude/skills/`,
  `.kiro/steering/`, `.windsurf/rules/`), so mirror there if one of them does
  not pick up `.agents/skills/`.

## Docs that must stay in sync

`PLAN.md` (scope and phases) · `docs/GAME_DESIGN.md` (rules + the decisions
log §14, one row per intentional deviation) · `docs/CONTENT_AUTHORING.md` (JSON
formats) · `docs/ASSET_ATTRIBUTIONS.md` (every external asset and licence) ·
`README.md` (phase status, layout, commands).

## Git

The repo had **no commits** on `main` as of 2026-10-25. No commit-message
convention has been established yet.
