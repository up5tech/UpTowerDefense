# V2-6 phase report — balance, QA and the 2.0 build

Evidence for the last phase of [`V2_PLAN.md`](V2_PLAN.md). It records what ran,
the two balance outcome tables in full, and exactly which release gates still
need hardware or store accounts. Written 2026-11-05 against build `2.0.0+2`.

**State: automated gates green and the Android binaries are release-signed;
the device and iOS gates are open.** V2-6 is not signed off until the hardware
pass, the on-device 1.0 → 2.0 upgrade and an iOS archive exist (§6).

## 1. What ran

| Gate | Command | Result |
|---|---|---|
| Full suite | `env -u HTTP_PROXY -u HTTPS_PROXY flutter test` | **565 passing**, 0 failing |
| Analysis | `flutter analyze` | **No issues found** |
| Formatting | `dart format --line-length 80 --set-exit-if-changed lib test tool` | **0 changed** (200 files) |
| Content | `dart run tool/validate_content.dart` | **Content OK** — 3 maps, 6 enemies, 5 towers, 15 levels, 2 difficulties, 3 regions |
| Offline guard | inside the suite (`offline_guard_test`) | Green: the release manifest still declares no permissions |
| Normal probe | `dart run tool/balance_probe.dart` | 15 levels × the four plans (plus the capped opening plan): **every level won** |
| Hard probe | `dart run tool/balance_probe.dart --difficulty=hard` | 15 levels: **nine rows lose, every level is still winnable** |
| Release APK | `flutter build apk --release` | ✓ `build/app/outputs/flutter-apk/app-release.apk` (56.2 MB) — **release-signed**, cert `CN=UpTowerDefense`, confirmed by `apksigner verify --print-certs` |
| Play bundle | `flutter build appbundle --release` | ✓ `build/app/outputs/bundle/release/app-release.aab` (54.4 MB) — jar-signed by the same cert (`keytool -printcert -jarfile` shows `CN=UpTowerDefense`) |
| iOS simulator | `flutter build ios --simulator` | ✓ `build/ios/iphonesimulator/Runner.app` |

**Re-pin outcome: no edits were needed.** Both pinned tables —
`test/unit/balance_regression_test.dart` and
`test/unit/balance_hard_regression_test.dart` — matched this run value for value,
so V2-3's pins still describe the shipped data. That is the expected result of a
release phase that changes no balance data; a mismatch here would have meant a
data edit landed without its pin.

**Amended 2026-11-08 — the V2-2 roster actually spawns now.** Bulwark and
Splitter were defined in `enemies.json` but referenced by no level and not by
the endless template, so the "6 enemies" the codex and store copy describe
could never appear in play. They now spawn in `hollow_03`–`hollow_05` (the
Region 3 finale levels, matching how D69's surge debuts there) and in the
endless template's later waves; `content_assets_test` gained a coverage rule
that fails when a catalog enemy is spawned nowhere. The §2 table above is the
re-run Normal probe after that change — every level still wins under every
plan, with `hollow_03`–`hollow_05` closer to the edge — and the §3 Hard table
is unchanged value for value, including its nine pinned losses.

**Amended 2026-11-09 — the probe measures arc and beacon at last.** V2-2's
same-slot control criterion was asserted but never measured: the probe only
built ranger/cannon/frost plans. Three order-matched plans close the gap —
`arc slot` and `beacon slot` (one slot swapped against `rangers only`) and
`cannon arc mix` (one slot swapped against `cannon crossfire`). Normal: arc
beats its control on seven levels and loses on two; beacon wins only
`meadow_05` and loses six — the weakest slot in the roster, now pinned.
Hard: pinned losses grow from nine rows to fourteen, but `hollow_03`–`hollow_05`
are no longer `cannon crossfire`-only — `arc slot` also wins the first two and
`cannon arc mix` wins all three, so no level requires a single strategy. The
§2/§3 tables above are the pre-amendment runs; the current pins live in the
two `balance_*_regression_test.dart` files (D81).

## 2. Outcome table — Normal

`DifficultyProfile(normal, waves 100%, gold 100%)`, naive fill-then-upgrade
policy, waves started as soon as allowed. Stars are `1 + goals met`, defeat 0.

| Level | Plan | Result | Core | Leaks | Goals | Stars |
|---|---|---|---:|---:|---:|---:|
| meadow_01 | rangers only | win | 20 | 0 | 1/2 | 2 |
| meadow_01 | cannon crossfire | win | 20 | 0 | 1/2 | 2 |
| meadow_01 | frost control | win | 20 | 0 | 1/2 | 2 |
| meadow_01 | capped starter | win | 20 | 0 | 2/2 | **3** |
| meadow_01 | no-frost control | win | 20 | 0 | 1/2 | 2 |
| meadow_02 | rangers only | win | 20 | 0 | 1/2 | 2 |
| meadow_02 | cannon crossfire | win | 20 | 0 | 1/2 | 2 |
| meadow_02 | frost control | win | 20 | 0 | 1/2 | 2 |
| meadow_02 | capped starter | win | 20 | 0 | 2/2 | **3** |
| meadow_02 | no-frost control | win | 20 | 0 | 1/2 | 2 |
| meadow_03 | rangers only | win | 18 | 0 | 2/2 | **3** |
| meadow_03 | cannon crossfire | win | 18 | 0 | 2/2 | **3** |
| meadow_03 | frost control | win | 18 | 0 | 2/2 | **3** |
| meadow_03 | capped starter | win | 18 | 0 | 2/2 | **3** |
| meadow_03 | no-frost control | win | 18 | 0 | 2/2 | **3** |
| meadow_04 | rangers only | win | 18 | 0 | 1/2 | 2 |
| meadow_04 | cannon crossfire | win | 18 | 0 | 1/2 | 2 |
| meadow_04 | frost control | win | 18 | 0 | 1/2 | 2 |
| meadow_04 | no-frost control | win | 18 | 0 | 1/2 | 2 |
| meadow_05 | rangers only | win | 14 | 1 | 1/2 | 2 |
| meadow_05 | cannon crossfire | win | 16 | 0 | 1/2 | 2 |
| meadow_05 | frost control | win | 14 | 1 | 1/2 | 2 |
| meadow_05 | no-frost control | win | 16 | 0 | 1/2 | 2 |
| ember_01 | rangers only | win | 16 | 0 | 2/2 | **3** |
| ember_01 | cannon crossfire | win | 16 | 0 | 2/2 | **3** |
| ember_01 | frost control | win | 16 | 0 | 2/2 | **3** |
| ember_01 | no-frost control | win | 16 | 0 | 2/2 | **3** |
| ember_02 | rangers only | win | 15 | 0 | 1/2 | 2 |
| ember_02 | cannon crossfire | win | 14 | 1 | 1/2 | 2 |
| ember_02 | frost control | win | 15 | 0 | 1/2 | 2 |
| ember_02 | no-frost control | win | 15 | 0 | 1/2 | 2 |
| ember_03 | rangers only | win | 9 | 3 | 1/2 | 2 |
| ember_03 | cannon crossfire | win | 13 | 1 | 1/2 | 2 |
| ember_03 | frost control | win | 9 | 3 | 1/2 | 2 |
| ember_03 | no-frost control | win | 13 | 1 | 1/2 | 2 |
| ember_04 | rangers only | win | 6 | 3 | 0/2 | 1 |
| ember_04 | cannon crossfire | win | 12 | 0 | 1/2 | 2 |
| ember_04 | frost control | win | 2 | 5 | 0/2 | 1 |
| ember_04 | no-frost control | win | 10 | 1 | 0/2 | 1 |
| ember_05 | rangers only | win | 10 | 1 | 1/2 | 2 |
| ember_05 | cannon crossfire | win | 12 | 0 | 1/2 | 2 |
| ember_05 | frost control | win | 12 | 0 | 1/2 | 2 |
| ember_05 | no-frost control | win | 10 | 1 | 1/2 | 2 |
| hollow_01 | rangers only | win | 18 | 1 | 1/2 | 2 |
| hollow_01 | cannon crossfire | win | 20 | 0 | 1/2 | 2 |
| hollow_01 | frost control | win | 18 | 1 | 1/2 | 2 |
| hollow_01 | no-frost control | win | 18 | 1 | 1/2 | 2 |
| hollow_02 | rangers only | win | 16 | 2 | 1/2 | 2 |
| hollow_02 | cannon crossfire | win | 20 | 0 | 1/2 | 2 |
| hollow_02 | frost control | win | 18 | 1 | 1/2 | 2 |
| hollow_02 | no-frost control | win | 16 | 2 | 1/2 | 2 |
| hollow_03 | rangers only | win | 3 | 12 | 1/2 | 2 |
| hollow_03 | cannon crossfire | win | 20 | 0 | 2/2 | **3** |
| hollow_03 | frost control | win | 7 | 10 | 1/2 | 2 |
| hollow_03 | no-frost control | win | 18 | 1 | 2/2 | **3** |
| hollow_04 | rangers only | win | 15 | 5 | 2/2 | **3** |
| hollow_04 | cannon crossfire | win | 20 | 0 | 2/2 | **3** |
| hollow_04 | frost control | win | 17 | 3 | 2/2 | **3** |
| hollow_04 | no-frost control | win | 1 | 17 | 1/2 | 2 |
| hollow_05 | rangers only | win | 2 | 6 | 1/2 | 2 |
| hollow_05 | cannon crossfire | win | 14 | 0 | 2/2 | **3** |
| hollow_05 | frost control | win | 2 | 6 | 1/2 | 2 |
| hollow_05 | no-frost control | win | 4 | 5 | 1/2 | 2 |

Read across each level: Cannons beat the pure-ranger control on the four
crowded levels (`hollow_03`, `hollow_05`, `ember_04`, `meadow_05`), Frost ties
the ranger build wherever the chill reaches the same targets, and no plan loses
anywhere — the campaign is completable on Normal with every one of them.

## 3. Outcome table — Hard

`DifficultyProfile(hard, waves 125%, gold 90%)`, same plans and policy. The
goals and core health are the authored values, unscaled.

| Level | Plan | Result | Core | Leaks | Goals | Stars |
|---|---|---|---:|---:|---:|---:|
| meadow_01 | rangers only | win | 20 | 0 | 1/2 | 2 |
| meadow_01 | cannon crossfire | win | 16 | 4 | 0/2 | 1 |
| meadow_01 | frost control | win | 20 | 0 | 1/2 | 2 |
| meadow_01 | capped starter | win | 20 | 0 | 2/2 | **3** |
| meadow_01 | no-frost control | win | 20 | 0 | 1/2 | 2 |
| meadow_02 | rangers only | win | 19 | 1 | 1/2 | 2 |
| meadow_02 | cannon crossfire | win | 15 | 5 | 2/2 | **3** |
| meadow_02 | frost control | win | 19 | 1 | 1/2 | 2 |
| meadow_02 | capped starter | win | 19 | 1 | 2/2 | **3** |
| meadow_02 | no-frost control | win | 20 | 0 | 1/2 | 2 |
| meadow_03 | rangers only | win | 16 | 2 | 1/2 | 2 |
| meadow_03 | cannon crossfire | win | 18 | 0 | 2/2 | **3** |
| meadow_03 | frost control | win | 16 | 2 | 1/2 | 2 |
| meadow_03 | capped starter | win | 16 | 2 | 1/2 | 2 |
| meadow_03 | no-frost control | win | 18 | 0 | 2/2 | **3** |
| meadow_04 | rangers only | win | 18 | 0 | 1/2 | 2 |
| meadow_04 | cannon crossfire | win | 18 | 0 | 1/2 | 2 |
| meadow_04 | frost control | win | 18 | 0 | 1/2 | 2 |
| meadow_04 | no-frost control | win | 18 | 0 | 1/2 | 2 |
| meadow_05 | rangers only | win | 14 | 1 | 1/2 | 2 |
| meadow_05 | cannon crossfire | win | 14 | 1 | 1/2 | 2 |
| meadow_05 | frost control | win | 14 | 1 | 1/2 | 2 |
| meadow_05 | no-frost control | win | 16 | 0 | 1/2 | 2 |
| ember_01 | rangers only | win | 16 | 0 | 2/2 | **3** |
| ember_01 | cannon crossfire | win | 16 | 0 | 2/2 | **3** |
| ember_01 | frost control | win | 16 | 0 | 2/2 | **3** |
| ember_01 | no-frost control | win | 16 | 0 | 2/2 | **3** |
| ember_02 | rangers only | win | 15 | 0 | 1/2 | 2 |
| ember_02 | cannon crossfire | win | 14 | 1 | 1/2 | 2 |
| ember_02 | frost control | win | 15 | 0 | 1/2 | 2 |
| ember_02 | no-frost control | win | 15 | 0 | 1/2 | 2 |
| ember_03 | rangers only | win | 9 | 3 | 1/2 | 2 |
| ember_03 | cannon crossfire | win | 7 | 4 | 0/2 | 1 |
| ember_03 | frost control | win | 9 | 3 | 1/2 | 2 |
| ember_03 | no-frost control | win | 11 | 2 | 1/2 | 2 |
| ember_04 | rangers only | win | 4 | 4 | 0/2 | 1 |
| ember_04 | cannon crossfire | win | 12 | 0 | 1/2 | 2 |
| ember_04 | frost control | win | 2 | 5 | 0/2 | 1 |
| ember_04 | no-frost control | win | 6 | 3 | 0/2 | 1 |
| ember_05 | rangers only | win | 8 | 2 | 1/2 | 2 |
| ember_05 | cannon crossfire | win | 12 | 0 | 1/2 | 2 |
| ember_05 | frost control | win | 12 | 0 | 1/2 | 2 |
| ember_05 | no-frost control | win | 8 | 2 | 1/2 | 2 |
| hollow_01 | rangers only | win | 14 | 3 | 0/2 | 1 |
| hollow_01 | cannon crossfire | win | 20 | 0 | 1/2 | 2 |
| hollow_01 | frost control | win | 14 | 3 | 0/2 | 1 |
| hollow_01 | no-frost control | win | 14 | 3 | 0/2 | 1 |
| hollow_02 | rangers only | win | 14 | 3 | 1/2 | 2 |
| hollow_02 | cannon crossfire | win | 20 | 0 | 1/2 | 2 |
| hollow_02 | frost control | win | 14 | 3 | 1/2 | 2 |
| hollow_02 | no-frost control | win | 13 | 4 | 0/2 | 1 |
| hollow_03 | rangers only | **LOSE** | 0 | 18 | 0/2 | 0 |
| hollow_03 | cannon crossfire | win | 20 | 0 | 2/2 | **3** |
| hollow_03 | frost control | **LOSE** | 0 | 18 | 0/2 | 0 |
| hollow_03 | no-frost control | **LOSE** | 0 | 19 | 0/2 | 0 |
| hollow_04 | rangers only | **LOSE** | 0 | 20 | 0/2 | 0 |
| hollow_04 | cannon crossfire | win | 20 | 0 | 2/2 | **3** |
| hollow_04 | frost control | **LOSE** | 0 | 20 | 0/2 | 0 |
| hollow_04 | no-frost control | **LOSE** | 0 | 20 | 0/2 | 0 |
| hollow_05 | rangers only | **LOSE** | 0 | 7 | 0/2 | 0 |
| hollow_05 | cannon crossfire | win | 14 | 0 | 2/2 | **3** |
| hollow_05 | frost control | **LOSE** | 0 | 7 | 0/2 | 0 |
| hollow_05 | no-frost control | **LOSE** | 0 | 7 | 0/2 | 0 |

**The nine losses are intended and pinned as losses.** Hard multiplies wave
counts by 1.25 and cuts starting gold to 90%, while the probe's plans still fill
every pad with one tower family; `hollow_03`–`hollow_05` are the crowded Region 3
levels where that plan no longer answers the wave. `cannon crossfire` wins all
three, which is the property that matters: **no level is a dead end on Hard**,
and every earlier level is still won by every plan. The gate also checks that no
Hard row leaves more core than its Normal counterpart, so the profile can never
make a level easier by accident.

## 4. What the probe prints beyond these tables

Kills, gold earned and simulated seconds per run are in the probe's own output
and are not pinned, because they move with harmless timing changes. The pinned
claims are the ones the phase gates actually need: win or loss, core left, leaks,
and (in `balance_regression_test`) the opening levels' three-star run.

To reproduce either table:

```bash
dart run tool/balance_probe.dart
dart run tool/balance_probe.dart --difficulty=hard
```

A deliberate data change re-runs the probe, reviews the whole table, and edits
the matching pin in the same commit. A pin edited to silence a surprise is the
failure mode those tests exist to catch.

## 5. QA scenarios added

[`QA_SCENARIOS.md`](QA_SCENARIOS.md) gained the four v2 surfaces V2-6 requires:

| Section | Covers |
|---|---|
| §12 Daily challenge (D1–D6) | Date-seeded selection, campaign isolation, midnight boundary, a dropped run |
| §13 Difficulty switching (H1–H6) | Per-region Hard unlock, separate records per mode, identical goals/core |
| §14 Achievements and progress (C1–C6) | Ten ids, unlock-once, persistence across a force-kill, endless/daily awards |
| §15 Save upgrade from 1.0 (U1–U5) | Over-install keeps progress/settings/endless best, stars stay authoritative, damaged save still recovers |

Sections 12–15 are written and **not yet executed on hardware**; §16 records the
run and says so.

## 6. Release gates still open

**Android signing closed 2026-11-05.** `android/key.properties` (git-ignored,
needs its own backup) points at the release keystore with subject
`CN=UpTowerDefense, OU=Mobile, O=UpTowerDefense, L=Ho Chi Minh City, ST=HCMC,
C=VN`. Both `app-release.apk` and `app-release.aab` verify against it, so the
Play upload artifact exists. **Keep the keystore and its passwords backed up
outside the repo** — losing them means this listing can never be updated again.

| Gate | Why it is open | What closes it |
|---|---|---|
| Release tag | The repo has no git tags, and V2_PLAN §10.7 requires a tagged commit as the build source for the store-ready APK and iOS archive | Tag the frozen release commit (e.g. `v2.0.0`) once content and binaries are final, and push the tag |
| Hardware pass | No physical device in this workspace: audio audibility (A1–A4), release-mode GPU frame pacing and thermal/memory behaviour (S1–S3, M4) cannot be observed on a software-rasterising AVD | Run those scenarios on a supported Android phone and an iPhone in release mode, record the table in `QA_SCENARIOS.md` §9 |
| 1.0 → 2.0 over-install | No archived 1.0 artifact or 1.0 save exists on this host and no device is attached, so §15 U1–U5 is currently a one-shot test that cannot be repeated | Build and archive the 1.0 baseline APK from `d3ec282` (the last commit before V2-0) release-signed with the same key, plus a captured `save.current` payload (schema v3) from a played 1.0 session; then execute U1–U5 on a device |
| iOS archive / TestFlight | No Apple account or team on this host, so there is no archive and no `flutter build ipa`; the simulator build only proves it compiles | Export from Xcode with the team's distribution certificate, then `flutter build ipa` |
| Store upload | Nothing has been uploaded; the Android binaries are signed but unpublished | Upload the AAB to Play Console (closed testing first) and the archive to TestFlight |
| Region 3 eyes-on play | The campaign unlocks in order, so the emulator pass never reached `hollow_01`–`hollow_05` (§V2-1 "Remaining manual step") | Play the five new levels once in landscape on a device |
| Store screenshots | `STORE_LISTING.md` §6 requires captures from a known-good **release** build on the QA device | Take the eight shots after the hardware pass |

## 7. Acceptance criteria — state at hand-off

| V2-6 criterion | State |
|---|---|
| `dart format` clean, `flutter analyze` clean, full suite green | **Met** (0 changed · no issues · 565 passing) |
| `offline_guard_test` green; release manifest declares no permissions | **Met** |
| Save upgrade verified on a device (1.0 → 2.0, damaged save recovers) | **Not met** — automated halves pass; the over-install needs an archived 1.0 build/save and a device |
| Tagged release commit (V2_PLAN §10.7) | **Not met** — the repo has no git tags; `v2.0.0` must point at the commit the store artifacts are built from |
| No known blocker, data-loss defect or resource leak | **Met for gameplay.** The open items are the distribution gate and two unmeasured environmental areas (audio audibility, GPU pacing) |
| Store assets describe the build that actually ships | **Met** — `STORE_LISTING.md` rewritten for fifteen levels / five towers / six enemies / goals, difficulties, daily and achievements, with a v2 age-rating re-check and 2.0.0 release notes |
| Release APK and iOS archive path built | **Met for Android** — release APK (56.2 MB) and AAB (54.4 MB), both verified against the release cert. **Open for iOS** — simulator app only, no archive/export |

V2-6 remains **in progress** until the gates in §6 close. No gameplay,
content or balance work is outstanding.
