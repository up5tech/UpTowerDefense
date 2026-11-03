# QA Scenarios — Phase 12

Repeatable manual QA scenarios for the Phase 12 acceptance criteria in
[`PLAN.md`](../PLAN.md) §8. Each scenario states its preconditions, steps,
expected result and the acceptance criterion it covers, so any run produces the
same evidence twice.

Automated coverage is *not* repeated here: `flutter test`, `flutter analyze`,
`dart format`, `tool/validate_content.dart`, the two stress tests
(`stress_frame_cost_test` for simulation, `stress_fx_cost_test` for effects) and
`restart_navigation_leak_test` are the scripted half of Phase 12. This document
covers what only a real device can show; where a scenario's core rule is already
pinned by a test, the manual step shrinks to a spot-check of the same behaviour
on real hardware.

**V2-0 baseline run (2026-10-29):** Flutter 3.47.8 / Dart 3.13.7, Flame
1.38.2, macOS arm64 test host. These are harness wall-clock timings, not
release-mode device frame times; the device-only graphics profile stays open for
the V2-6 hardware pass, and memory was measured on the emulator in §9.

| Scenario | Configuration | Average | p95 | Worst | Result |
|---|---|---:|---:|---:|---|
| Normal simulation | `meadow_03`, six Ranger plan, to victory; 4,646 frames | 0.002 ms | 0.003 ms | 0.674 ms | Pass; host harness only |
| Crowded simulation | 3,000 measured frames after warm-up; 23/23 towers, peak 5,077 enemies, 10,263 pending spawns | 0.179 ms | 0.398 ms | 2.518 ms | Pass; 4 ms average budget |
| Effects, real stress stream | 3,000 frames; peak 64 effects, 232 events/frame, 8,498 events total | 43.6 µs | 87.0 µs | 1,001 µs | Pass; 1 ms average budget |
| Effects, saturated | 1,500 frames at 64-effect cap | 46.0 µs | 64.0 µs | 209 µs | Pass; 1.5 ms average budget |

The numbers are representative of this local harness run only; compare like
hosts/build modes when trending them. Do not infer GPU/rasterization or physical
device battery/memory behaviour from these tests.

## 1. How to run this pass

- **Build:** one release-candidate build per platform
  (`flutter build apk --release`, `flutter build ios --release` or equivalent),
  installed fresh on the device under test.
- **Network:** airplane mode on for every scenario unless the scenario says
  otherwise. The offline promise is a product rule, so network-disabled is the
  *default* state of the pass, not a special case.
- **Devices:** at least one low-end and one mid/high device if available. Note
  the model, OS version and build number with each result.
- **Recording:** copy the table for the run and fill in Pass/Fail plus notes.
  Any Fail gets a severity (blocker / high / medium / low) and is logged in the
  Known Issues section before the phase closes.

```text
Scenario | Device / OS | Build | Result | Notes
---------|-------------|-------|--------|------
```

## 2. Offline validation — covers AC "core gameplay passes with network disabled"

| # | Steps | Expected |
|---|---|---|
| O1 | Enable airplane mode. Launch the app cold. | App launches to the main menu with no error dialog, no loading hang. Save status line reads normally. |
| O2 | Play a full level from menu → level select → gameplay → victory or defeat → result. | Every screen opens; the level runs to completion; the result panel appears; audio and effects work. |
| O3 | Win a level, return to the map, and confirm the next level unlocked. | Unlock persists across a relaunch, still in airplane mode. |
| O4 | Open Settings, toggle music/SFX/motion, back out, relaunch the app. | Toggles keep their values; no network error appears anywhere. |
| O5 | Disable airplane mode, then repeat O2 once with the network *on*. | Behaviour is identical — no scenario may depend on connectivity either way. |
| O6 | While in airplane mode, check the release Android manifest declares no permissions (`android/app/src/main/AndroidManifest.xml`). | `<uses-permission>` list is empty (debug/profile may keep `INTERNET`). |

## 3. Interruption — covers "test app interruption, incoming calls, screen lock"

Preconditions: start from the main menu, then repeat the gameplay variants with
a level in progress at ~50% wave.

| # | Steps | Expected |
|---|---|---|
| I1 | During gameplay, press Home (background the app), wait 10 s, return. | The level is frozen while backgrounded and continues from the exact frame on return — no enemies skipped, no wave delivered at once (frame deltas clamp). System return resumes the level by design (D30); a pause the player chose is the case I2 covers, and it must survive. |
| I2 | Pause the level explicitly, background the app, return. | The level is **still paused** — system resume must not override the player's pause. |
| I3 | Background the app from a menu screen, wait, return. | Menu state intact; orientation still correct. |
| I4 | During gameplay, trigger an incoming call / another app's full-screen interruption, dismiss it, return. | Same as I1: no lost progress, no double wave, no crash. |
| I5 | During gameplay, let the screen lock (power button), unlock 30 s later. | Same as I1; music resumes or stays paused according to the music toggle, no audio stutter. |
| I6 | Repeat I1 three times in quick succession. | No accumulated pause state, no frozen-but-resumed mismatch, no leaked timer. |

## 4. Orientation and layout — covers "orientation/layout edge cases"

| # | Steps | Expected |
|---|---|---|
| R1 | Launch the app and rotate the device through portrait → landscape left → landscape right on the main menu, level select, settings and credits. | Menus accept every orientation and re-layout without clipped text or overflow errors. |
| R2 | Enter a level, then attempt to rotate. | The screen stays landscape-locked; rotation has no effect while gameplay is open. |
| R3 | Leave gameplay (back to menu), rotate to portrait. | Menu unlocks to portrait immediately; no stale landscape lock. |
| R4 | Enter gameplay from portrait, complete the level, return to the map, rotate to portrait. | Lock applies on entry and releases on exit every time — repeat 3×. |
| R5 | On a notched device, check HUD edges and the pause/result panels in both landscape directions. | Nothing sits under the notch or system bars; the letterboxed camera keeps the map centred. |

## 5. Process termination and data loss — covers AC "no known blocker or data-loss defect"

| # | Steps | Expected |
|---|---|---|
| P1 | Win level N, force-kill the app (swipe away from recents), relaunch. | Level N's victory and the unlock of N+1 are present. |
| P2 | Change settings (music off, volume moved), force-kill, relaunch. | Settings persisted exactly. |
| P3 | Force-kill the app *mid-level*, relaunch. | The in-progress attempt is dropped (expected — progress saves at the outcome), but **all previously recorded wins, unlocks and settings survive**. No crash on startup. |
| P4 | Force-kill immediately after the victory banner appears, before leaving the result screen. | The win is recorded — the record happens when the level ends, not when the player taps on. |
| P5 | Corrupt the save payload deliberately (edit/zero the stored save bytes in a debug build), relaunch. | App launches; the menu shows the degraded save status line; the damaged payload is preserved, not silently overwritten; the game runs on defaults or restores from the backup copy. |
| P6 | Relaunch 5 times in a row quickly. | No accumulating state: menu counters, providers and audio all start clean each time. |

## 6. Audio interruptions — covers "audio interruptions"

| # | Steps | Expected |
|---|---|---|
| A1 | Background the app during gameplay with music on; return. | Music paused while backgrounded and resumed on return (or respects the music toggle); no overlapping second loop. |
| A2 | Toggle music off/on in Settings while a level plays. | Music stops/starts live through the same controller; no restart from the beginning of the track, no crash. |
| A3 | Toggle SFX off during gameplay. | Sound effects stop immediately; combat continues normally. |
| A4 | Route audio to a Bluetooth device (or plug/unplug wired headphones) mid-level, then play 1 min. | No crash; audio continues or resumes; game timing unaffected. |
| A5 | On a device that supports haptics, enable Haptics; build/upgrade a tower and allow one enemy to leak. Repeat with Haptics disabled. | Build/upgrade gives a light acknowledgement and a leak gives a stronger warning when enabled; routine shots/hits do not buzz. Disabled produces no haptics; gameplay remains unchanged. Record device support and result. |

## 7. Repeated restart and navigation — covers AC "restart and repeated navigation do not accumulate stale components or timers"

**Automated first:** `test/widget/restart_navigation_leak_test.dart` already
runs 10 restarts and 10 menu↔level cycles in CI and asserts an exact snapshot
(recursive component count, session state, widget element count) after each
cycle — it also fails outright if a timer is left pending at teardown. M1–M4
below are the on-device half: they repeat the same cycles where real time,
real memory and real audio exist.

| # | Steps | Expected |
|---|---|---|
| M1 | In one level, use restart 10 times in a row. | Each restart begins a clean attempt (gold, waves, towers reset); the pad count and enemy count return to baseline; no duplicated HUD elements. |
| M2 | Cycle menu → level → back → level → menu 10 times. | Every level opens in a working state; no ghost components from the previous session (stray sprites, sounds still playing from the abandoned level). |
| M3 | Complete M1 + M2, then check memory (Xcode Instruments / Android Profiler, or `adb shell dumpsys meminfo`). | Memory returns to near the baseline after leaving gameplay — no monotonic growth across the cycles. |
| M4 | Play 3 full levels back-to-back without killing the app. | Frame pacing stays stable; memory stable; no slowdown creep. |

## 8. Stress and performance — covers AC "representative stress tests meet the frame-rate and memory targets"

Scripted half — both run and print their distribution before this section is
touched by hand:

- `flutter test test/unit/stress_frame_cost_test.dart` — simulation, measured
  2026-10-29 on the local host: **avg 0.179ms, p95 0.398ms, worst 2.518ms**
  per `advance` on a peak 5,077-enemy field (23 towers, 10,263 queued spawns),
  against a 4ms average budget. The same run also measures the normal `meadow_03`
  simulation baseline above.
- `flutter test test/unit/stress_fx_cost_test.dart` — effects, measured
  2026-10-29 on the local host: publish+update+render recording at **avg 43.6µs,
  p95 87µs, worst 1,001µs** under the wave's real event stream and **avg 46µs,
  p95 64µs, worst 209µs** at the saturated 64-cue cap, against 1ms and 1.5ms
  average budgets respectively.

On-device half (point the profiler at the same shape of load):

| # | Steps | Expected |
|---|---|---|
| S1 | Build out a late level (every pad built, all maxed) and let a dense late wave run 60 s with the device profiler open. | Sustained frame rate meets the target on the low-end device; host-harness simulation (~0.18ms) plus effects recording (~0.04ms) are known and small, so a shortfall here points at rasterisation and sprite/particle draw — record where the time goes. The known remaining simulation hotspot is the per-tower targeting scan (23 × full enemy list per ready volley); if the device profile agrees, note it in Known Issues rather than assuming rendering. |
| S2 | Same run, watch memory over 60 s. | No unbounded growth: event queues drain every frame and components are reused, so the graph is flat, not climbing. |
| S3 | Repeat S1 at 2× game speed. | Frame pacing holds; effects scale with the same time source as the simulation. The host-side timings above are not a substitute for this device frame-pacing check. |

## 9. Run record — V2-0 device pass (2026-11-02)

This is the pass V2-0's exit gate requires. Everything below ran against one
build; the scenarios that this host cannot produce are listed separately with
the reason and the automation that covers them instead.

| | |
|---|---|
| Device | Android emulator AVD `Medium_Phone_API_35` — Android 15 (API 35), 1080×2400, `-gpu swiftshader_indirect` |
| Build | `flutter build apk --release` from `e870fe2` (55.9 MB). Debug-signed because `android/key.properties` is absent, so the **release** manifest is what ran |
| Install | `adb install -r` onto a fresh profile |
| Automated half | `flutter analyze` clean · `dart format --set-exit-if-changed` 0 changed · `flutter test` 450 passing · `tool/validate_content.dart` Content OK (2 maps, 4 enemies, 3 towers, 10 levels, 2 regions) |
| Input | `adb shell input tap/keyevent`; captures kept in the gitignored `build/qa_shots/` |
| Haptics evidence | `adb shell dumpsys vibrator_manager`, filtered to `com.uptowerdefense.game` |
| Audio evidence | `adb shell dumpsys audio`, filtered to the app uid |
| Network | Airplane mode on for every scenario except O5 |

| # | Result | Evidence |
|---|---|---|
| O1 | Pass | Cold launch in airplane mode reached the menu with no dialog, hang or error. |
| O2 | Pass | `meadow_01` played menu → level → 3/3 waves → victory offline: "All waves cleared / Unlocked: Two Roads / 2 stars". |
| O3 | Pass | Force-kill after the win, relaunch still offline: "1 of 10 levels cleared · 2 of 30 stars", and the unlocked level started normally. |
| O4 | Pass | Music off, SFX 50%, haptics on, reduced motion on all survived a force-kill exactly. |
| O5 | Pass | Airplane mode off, replay of `meadow_03`: identical behaviour, no error. The release package declares no `INTERNET` permission at all, so connectivity cannot reach a code path. |
| O6 | Pass | `dumpsys package` lists only AndroidX's `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` signature permission. |
| I1 | Pass | Backgrounded at wave 2/3 for 10 s: the level was still frozen on return, then continued from that exact frame — no skipped enemies, no wave dumped at once. |
| I2 | Pass | Player pause plus 12 s in the background: still paused on return, gold/core/wave identical (120 g, 18/20, 3/3). |
| I3 | Pass | Home from the menu, 10 s away, return: same process (pid unchanged), same menu, portrait layout intact. |
| I5 | Pass | Screen off for 20 s mid-wave: no time jump, no enemy teleported past a tower, no extra leaks. |
| I6 | Pass | Three background/return cycles in quick succession: consistent state, no accumulated pause, no leaked timer. |
| R1 | Pass | Portrait menu re-laid out without clipping; landscape and reverse-landscape menu and settings render fully. |
| R2 | Pass | Gameplay stayed landscape with `user_rotation` forced to 0. |
| R3 | Pass | Leaving gameplay released the lock immediately — the menu rotated to portrait. |
| R4 | Pass | Three enter/leave cycles: the lock applied and released every time. |
| P1 | Pass | Win → force-kill → relaunch: victory and unlock present (same evidence as O3). |
| P2 | Pass | Settings changes survived a force-kill (same evidence as O4). |
| P3 | Pass | Force-kill mid-level: clean menu on relaunch, the attempt dropped, every recorded win kept, no crash. |
| P4 | Pass | Killed the process on the victory panel before touching anything: relaunch showed "2 of 10 levels cleared · 4 of 30 stars" — the win is written when the level ends, not when the player taps on. |
| P6 | Pass | Five force-stop/relaunch cycles: menu counters, providers and audio identical each time. |
| A2 | Partial | Exactly one `MediaPlayer` at all times; toggling music off then on replaced it (`paused` → `idle`) instead of adding a second player, so no overlapping loop. Audibility is not measurable here. |
| A3 | Partial | SFX run through one pooled `SoundPool`; no audio errors in logcat with SFX toggled. Audibility is not measurable here. |
| A5 | Pass | Haptics on: build and upgrade each logged one `performHapticFeedback(constant=4)` (TEXTURE_TICK, ~105 ms). Six core leaks logged a distinct, longer effect (`constant=6`, 247 ms) and routine combat logged nothing. Haptics off: the entry count did not move across builds and upgrades. |
| M1 | Pass | Ten restarts: each began at 170 g, wave 0/3, core 20/20, no towers, clean HUD. |
| M2 | Partial | Ten menu↔level cycles opened a working level each time with no stray sprites or residue in the captures; the exact component-count assertion belongs to `restart_navigation_leak_test`, not to a screenshot. |
| M3 | Pass | PSS 95,283 KB → 104,639 KB (after 10 restarts) → 105,242 KB (after 10 menu↔level cycles) → 104,980 KB (5 more cycles): a one-time warm-up, then flat. |

### Not produced on this host

| # | Why | Covered instead by |
|---|---|---|
| I4 | An emulator has no call UI to interrupt with. | The same lifecycle path as I1 and I5, both of which passed. |
| P5 | The release APK is not debuggable and `adb root` is refused on this image ("production builds"), so the save bytes cannot be edited on the device. | `save_repository_test`'s "recovery" group: an unreadable save restores the backup, preserves the damaged payload and reports the load degraded; defaults when nothing is usable; a load never writes. |
| A1, A4 | No monitored audio output and no Bluetooth or headphone routing on this AVD. | The music controller/host tests pin the loop's pause, resume and toggle rules; the `dumpsys audio` check above pins single-player behaviour. |
| M4 | Needs three complete levels in one session with frame pacing observable. | `restart_navigation_leak_test` plus M1–M3. |
| S1–S3 | The AVD rasterises in software, so its frame times say nothing about a phone GPU. | Nothing on this host — this is the explicit V2-6 hardware item. |
| Haptic feel, battery, thermals | Platform proxies only; the measurement itself needs hardware. | The `dumpsys vibrator_manager` and `meminfo` evidence above. |

## 10. Known issues

Record every non-blocking defect found by this pass here, with severity and the
build it was found on. Phase 12's acceptance criterion is that **no blocker or
data-loss defect remains** — a known issue may ship only if it is neither.

| Severity | Scenario | Description | Build | Status |
|----------|----------|-------------|-------|--------|
| Low | A1–A4 | Music and SFX audibility is unverified: this host neither monitors the emulator's audio output nor has a Bluetooth route, so only player lifecycle (`dumpsys audio`) was measurable. | `e870fe2` release, 2026-11-02 | Open — verify on hardware in the V2-6 pass |
| Low | O1 | On Android 12+ the system splash paints white instead of the palette `#0D1117`: `values/styles.xml` sets a `windowBackground` *drawable*, which the platform's splash screen cannot use, and no `values-v31` theme sets `windowSplashScreenBackground`. One white flash before the first Flutter frame. | `e870fe2` release, 2026-11-02 | Open — cosmetic |

## 11. Sign-off checklist

Ticked against the 2026-11-02 run (§9) unless a note says otherwise.

- [x] `flutter analyze`, `dart format`, `flutter test` all clean on the RC build
- [x] `tool/validate_content.dart` passes
- [x] Both stress tests pass; simulation and effects distributions recorded
- [x] `restart_navigation_leak_test` passes (automated half of Section 7)
- [x] Sections 2–7 executed on a device, with Section 8's on-device half
  explicitly deferred to the V2-6 hardware pass (§9, "Not produced on this host")
- [x] Offline pass (Section 2) completed with network disabled end to end
- [x] Known Issues reviewed: no blocker, no data-loss defect — two low-severity
  items are open (audio audibility unverified, Android 12+ splash colour)
- [x] High-severity findings fixed and re-verified before Phase 13 begins — none
  were found

Not yet satisfiable on this host: everything in §9 "Not produced on this host".
They are the V2-6 hardware pass's input, not a Phase 12 regression.
