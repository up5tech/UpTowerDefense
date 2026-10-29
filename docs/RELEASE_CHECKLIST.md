# Release checklist and rollback procedure — Phase 13

The repeatable path from a tagged commit to a shipped build, plus what to do
when a shipped build turns out to be wrong. Store-facing copy lives in
[`STORE_LISTING.md`](STORE_LISTING.md); the manual QA pass is
[`QA_SCENARIOS.md`](QA_SCENARIOS.md).

## 1. One-time setup

### 1.1 Release signing (Android)

Release signing lives outside the repo:

1. Generate the keystore once, somewhere outside the checkout
   (`keytool -genkey -v -keystore ~/keys/uptowerdefense-release.jks -keyalg
   RSA -keysize 2048 -validity 10000 -alias uptowerdefense`).
2. Copy [`android/key.properties.example`](../android/key.properties.example)
   to `android/key.properties` and fill in the four values. Both the
   properties file and `*.jks`/`*.keystore` are git-ignored.
3. Back the keystore up: **a lost release key means the app can never be
   updated again** — Play requires every update to be signed by the same key.

Without `key.properties`, release builds still compile — signed with the debug
key — so local `flutter run --release` and CI keep working. Such an artifact is
not store-ready. A store upload must always come from a machine with the real
key; verify with `apksigner verify --print-certs` before uploading.

**Current V1 gate status (2026-10-29): NOT SIGNED OFF.** The local full Flutter
test suite, analysis, formatting and content validator pass; Android release
APK and iOS Simulator builds are available. The local Flutter SDK was updated
to 3.47.8 / Dart 3.13.7 to include the published Flutter/Dart TLS certificate
remediation, and `pubspec.yaml` now requires Dart 3.13.7 or later. The local
release APK and iOS Simulator app build successfully, but the APK is debug-
signed because `android/key.properties` is absent. The Android App Bundle build
still fails in native-library symbol stripping; `flutter doctor` reports missing
Android command-line tools and unaccepted/unknown Android licences. The security
SDK update is therefore verified in local builds but has not been delivered as
a signed store binary. An iPhone 17 Simulator launch smoke check passed, but no physical
Android/iOS QA, airplane-mode gameplay pass, upgrade-over-previous-release
check, Android release certificate, signed iOS archive/TestFlight export or
store account upload has been verified. An unsigned `.xcarchive` exists, but is
not a distributable build. Do not treat this local status note as a
completed sign-off; finish the unchecked gates below with recorded device/build
evidence.

iOS signing is configured in Xcode (automatic signing with the development
team, or an exported `.p12` for CI). The bundle id is
`com.uptowerdefense.game` on both platforms and must never change after the
first store upload — it is the identity the store and all existing installs
are keyed to.

### 1.2 Launcher icons

Icons derive from two source files, never from the platform folders:

```bash
dart run tool/generate_launcher_icon.dart   # redraws tool/icon/*.png
dart run flutter_launcher_icons             # all Android/iOS sizes + adaptive
```

Edit the palette in `tool/generate_launcher_icon.dart` (it matches
`AppTheme`) and regenerate; hand-edited `mipmap-*` or `.appiconset` files are
overwritten and must not be committed as sources of truth.

## 2. Per-release checklist

### Content and quality gates (all must be green)

- [ ] `dart format --line-length 80 lib test tool` — 0 changed files
- [ ] `flutter analyze` — no issues
- [ ] `env -u HTTP_PROXY -u HTTPS_PROXY flutter test` — all pass
      (includes `content_assets_test`, `offline_guard_test`,
      `balance_regression_test`, the two stress tests, the leak tests)
- [ ] `dart run tool/validate_content.dart` — every shipped asset validates
- [ ] `docs/GAME_DESIGN.md` decisions log matches what shipped

### Versioning and metadata

- [ ] Bump `version:` in `pubspec.yaml` (`MAJOR.MINOR.PATCH+BUILD`);
      it drives `versionCode`/`versionName` and `CFBundleVersion`
- [ ] Release notes written for the version
- [ ] [`STORE_LISTING.md`](STORE_LISTING.md) still describes the build
      (screenshots match the shipped UI)

### Permissions and licences (acceptance: nothing undocumented ships)

- [ ] Release manifest still declares no permissions — pinned by
      `offline_guard_test`, so a green suite already proves this
- [ ] iOS `Info.plist` carries no usage-description keys unless a new API
      needs one (today: none; the game touches no protected API)
- [ ] New packages or assets are recorded in
      [`ASSET_ATTRIBUTIONS.md`](ASSET_ATTRIBUTIONS.md) with licences
      (runtime licences are listed in its *Package licences* section)

### Build and verify on hardware

- [ ] `flutter build apk --release` and install on a physical device:
      launches without dev tooling, icon and splash show, one full level plays
      offline (airplane mode), save survives a force-kill
- [ ] `apksigner verify --print-certs` shows the **release** cert
- [ ] `flutter build appbundle --release` (Play upload artifact)
- [ ] `flutter build ipa --release` / archive (macOS + Apple account required)
- [ ] Upgrade path: install the **previous** release, play and win a level,
      install the new build *over it* — progress, unlocks and settings
      survive. The automated half is `save_repository_test` (v1 → current
      schema) and `save_relaunch_test`; the on-device half is this step.

### Sign-off

- [ ] QA pass executed per [`QA_SCENARIOS.md`](QA_SCENARIOS.md); results
      table filled; Known Issues has no blocker and no data-loss defect

## 3. Rollback / patch procedure

**When a shipped build is bad, prefer a forward patch** — a hotfixed version
with a bumped `versionCode` — because stores cannot un-send an upload and
users who already updated cannot go back. Roll back only when the bad build
must stop being served while the patch is prepared.

### Forward patch (normal path)

1. Revert the offending change on a branch (or fix it directly) and land it
   with tests that fail on the bad build — a patch without a pin invites the
   same regression back.
2. Bump `version:` in `pubspec.yaml` (`+BUILD` at minimum; Android requires a
   strictly higher `versionCode` than anything uploaded).
3. Run the full gate from §2, build, verify the release cert, upload the new
   artifact (Play processes an update over the bad one; TestFlight promotes a
   new build).
4. Watch the first hours: crash reports, the save status line (a wave of
   `SaveOrigin.backup`/degraded reports means the codec regressed — roll the
   patch back forward, not the save data).

### Emergency rollback (build must stop being served)

- **Play:** upload a patched build as above; until it lands, roll back is not
  possible for already-installed users, so the patch is the rollback. Play's
  *halt rollout* stops distributing the bad version to new devices — use it
  while the patch is prepared.
- **App Store:** request expedited review of the patched build; Apple can also
  *remove* a version from sale (existing installs keep working).
- **Never ship a downgrade path.** Saves are forward-migrated
  (`SaveCodec`, `firstVersion`..`currentVersion`); an old build reading a
  newer payload must refuse it cleanly (pinned by `save_codec_test`) — data
  loss on rollback is the one unacceptable outcome.

### If the save layer is implicated

The save repository preserves unreadable payloads before writing and falls
back to the backup copy (pinned by `save_repository_test` recovery group).
Roll the **binary** back via a forward patch; do not touch user storage. Ask
affected users only after the patch is live.
