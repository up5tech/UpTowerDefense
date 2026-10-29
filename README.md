# UpTowerDefense

Offline-first 2D tower defense for Android and iOS, built with Flutter and Flame.
No account, no server, no network access required to play.

| | |
|---|---|
| Platform | Android, iOS |
| Engine | Flutter 3.47.8 (stable) · Dart 3.13.7 · Flame 1.38.2 |
| Shell | Riverpod 3.4.3 · go_router 18.1.1 · shared_preferences 2.5.6 |
| App ID / bundle ID | `com.uptowerdefense.game` (`…game.RunnerTests` for the iOS test bundle) |
| Orientation | Landscape gameplay, responsive menus |
| Phase status | **Phases 0–11 complete; Phase 12 automated half done; Phase 13 (release prep) in progress** — Phase 12 added the QA scenario doc, restart/navigation leak tests, paired stress frame-cost tests (simulation + effects) and a splash broad-phase optimization; its manual device pass is still outstanding. Phase 13 so far: release signing via `android/key.properties`, launcher icons, dark splash, store listing + release checklist docs, package-licence audit and a repository-level save-upgrade test; release APK and iOS simulator builds verified. Still needs developer accounts: signed store uploads and the archive/TestFlight path. Haptics are wired for builds, upgrades and core leaks; manual device QA and store-signing/archive gates remain outstanding. V2-0 has refreshed host-side baselines and Flutter 3.47.8/Dart 3.13.7; device QA remains a gate |

Version pins above reflect the stable toolchain verified for V2-0 on
2026-10-29. Flutter 3.47.8 / Dart 3.13.7 includes the required Flutter/Dart
security remediation; Flame 1.38.2 is the latest stable package. See
[`docs/V2_PLAN.md`](docs/V2_PLAN.md) for the remaining device-QA gate.

## Documentation

- [`PLAN.md`](PLAN.md) — product specification, architecture and the phased plan.
- [`docs/V2_PLAN.md`](docs/V2_PLAN.md) — the version 2 plan: scope, phases
  V2-0 to V2-6, acceptance criteria and the save/version policy.
- [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md) — the game rules and the decisions
  / deviations log.
- [`docs/adr/0001-flutter-flame-layer-boundaries.md`](docs/adr/0001-flutter-flame-layer-boundaries.md)
  — why gameplay rules stay outside Flame components.
- [`docs/CONTENT_AUTHORING.md`](docs/CONTENT_AUTHORING.md) — map, enemy, tower and
  level JSON formats, validation rules and how to add content.
- [`docs/ASSET_ATTRIBUTIONS.md`](docs/ASSET_ATTRIBUTIONS.md) — required record for
  every external asset and package licence.
- [`docs/QA_SCENARIOS.md`](docs/QA_SCENARIOS.md) — repeatable manual QA scenarios
  for the Phase 12 pass: offline, interruption, orientation, process kill.
- [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md) — release gates,
  signing setup, upgrade verification and the rollback/patch procedure.
- [`docs/STORE_LISTING.md`](docs/STORE_LISTING.md) — store copy, privacy and
  age-rating answers, screenshot plan.

Read `GAME_DESIGN.md` before changing gameplay rules; keep its decisions log in
sync with the code.

## Requirements

- Flutter 3.47.8 or later with Dart 3.13.7 or later for Android, Windows and
  Linux (`flutter --version`); Apple-only builds should also stay current with
  stable.
- Xcode with an iOS simulator for iOS builds.
- Android SDK with an emulator or device for Android builds.
- CocoaPods (`pod --version`) for iOS.

## Setup

```bash
flutter pub get
```

## Run

```bash
flutter devices                 # list connected devices / running simulators
flutter run                     # debug build on the selected device
flutter run -d "iPhone 17 Pro"  # example: target a specific simulator
```

## Test, analyse, format

```bash
flutter test                    # unit + widget tests
flutter analyze                 # static analysis (flame_lint rules)
dart format --line-length 80 lib test tool
dart run tool/validate_content.dart   # decode + validate every shipped asset
```

All three of `analyze`, `test` and `format` must pass before a phase is
considered done. `tool/validate_content.dart` is the fast content loop for
authors; `test/unit/campaign_assets_test.dart` is the same gate inside the suite.
There is no hosted CI service configured yet; when one is added, it should run
exactly these commands.

## Build

```bash
flutter build apk --debug         # Android debug APK
flutter build ios --simulator     # iOS simulator app (no signing)
flutter build apk --release       # release APK (debug-signed unless
                                  # android/key.properties exists)
```

Release signing, launcher icons and the store procedure live in
[`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md); icons regenerate with
`dart run tool/generate_launcher_icon.dart && dart run flutter_launcher_icons`.

## Project layout

```text
lib/
  main.dart                     bootstrap: settings load + provider container
  app/
    app.dart                    MaterialApp.router shell
    router.dart                 GoRouter routes (all nested under the menu)
    routes.dart                 route path constants
    lifecycle/                  orientation policy
    theme/                      app theme
  core/constants/               app identity constants
  features/
    main_menu/presentation/     Play / Campaign / Settings / Credits
    campaign/
      domain/                   campaign order, progress, unlock rule, star rating
      data/                     campaign JSON decoder and repository
      application/              campaign and progress providers
    level_select/presentation/  campaign picker (regions, locks, best stars)
    settings/                   domain model, storage, controller, screen
    credits/presentation/       credits and open-source licences
    gameplay/
      domain/                   map/enemy/tower/level models, geometry, validation,
                                economy, upgrades and selling, targeting, damage,
                                status effects, level flow and LevelSession
      data/                     JSON decoders, repositories, content catalog
      application/              content providers, pad selection, LevelController
      flame/                    game entry point, map/tower/enemy/projectile
                                rendering, combat effects, hit testing
      presentation/             gameplay screen (loading, HUD, wave control,
                                pause and result overlays, build and tower
                                panels, back)
  shared/layout/                responsive menu frame
assets/data/campaign.json       region and level order, and each level's name
assets/data/maps/               authored map definitions (JSON)
assets/data/enemies/            shared enemy catalog (JSON)
assets/data/towers/             shared tower catalog and its balance (JSON)
assets/data/levels/             authored levels with their waves and gold (JSON)
tool/validate_content.dart      decodes + validates every shipped asset
test/
  helpers/                      app/gameplay harnesses, map and content fixtures
  unit/                         content decoding/validation, campaign order and
                                progress, geometry, session, combat, level flow,
                                economy, controller, settings, save codec and
                                repository, offline guard
  widget/                       navigation, settings, map selection, build, HUD,
                                pause/speed/restart, result flow, level picker
  integration/                  multi-screen flows (campaign → level → result →
                                next; save survives a relaunch)
docs/                           design doc, ADRs, attributions, checklists
```

Folders are created when they hold real code — do not add empty abstractions
ahead of a phase that needs them.

## Conventions

- **Dependency direction:** Flutter presentation → application → domain;
  Flame components read domain state and never own gold, outcomes, costs, or
  unlocks. Domain code imports no Flutter or Flame APIs
  ([ADR 0001](docs/adr/0001-flutter-flame-layer-boundaries.md)).
- **Imports:** package imports (`package:up_tower_defense/...`) rather than
  relative imports, per `flame_lint`.
- **State and navigation:** Riverpod providers own shell state and dependencies;
  screens read it through `ConsumerWidget`/`ref`. Navigation goes through
  `go_router` helpers (`context.go`, `context.pop`) and never through ad-hoc
  `Navigator` calls, so the back stack stays predictable.
- **Settings:** every change is applied immediately and saved in the background;
  there is no save button. A failed write is logged and keeps the session value.
  Preferences live inside the versioned save, beside campaign progress
  ([D41](docs/GAME_DESIGN.md#14-decisions-and-deviations-log)).
- **Saves:** one document with a `schemaVersion` holds progress and settings,
  written by a single repository when something changes — never per frame.
  Loading never writes: an unreadable payload is kept as `save.damaged`, the
  backup is tried next, and only then does the session start fresh, with the
  outcome shown on the menu — only when a load degraded, never as routine
  noise — and always in Settings. Reset progress lives in Settings
  too, behind a confirmation
  ([D40](docs/GAME_DESIGN.md#14-decisions-and-deviations-log)).
- **Analysis:** `flame_lint` with strict casts/inference/raw types. Fix warnings
  rather than suppressing them; if a suppression is genuinely required, explain
  why on the line.
- **Formatting:** `dart format --line-length 80`.
- **World units:** map layout, hit testing and (later) enemy movement use world
  units defined by each map, never screen pixels. Screen conversion happens only
  in the Flame/Flutter presentation layers.
- **Simulation time:** gameplay advances only through delta time passed into the
  domain layer; never wall-clock timers, and clamp large deltas after lifecycle
  interruptions.
- **Content over constants:** balance values live in data definitions, not in
  widgets or combat code.
- **Stable IDs, deterministic tie-breaking:** required for saves, unlocks, and
  reproducible tests.
- **Asset provenance:** every external asset is recorded in
  [`docs/ASSET_ATTRIBUTIONS.md`](docs/ASSET_ATTRIBUTIONS.md) before it ships.

## Offline promise

The shipped Android manifest declares no permissions, and no gameplay path calls
a network or account API. `test/unit/offline_guard_test.dart` fails if a
permission is added to the release manifest; the debug/profile manifests keep the
`INTERNET` permission only so the Flutter VM service can attach during
development.
