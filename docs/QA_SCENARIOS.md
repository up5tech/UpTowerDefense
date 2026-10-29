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
release-mode device frame times; the device-only graphics and memory profile
below is still outstanding.

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
| I1 | During gameplay, press Home (background the app), wait 10 s, return. | Game is paused on return; the pause overlay is shown or the level is visibly frozen; tapping resume continues from the exact frame — no enemies skipped, no wave delivered at once (frame deltas clamp). |
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

## 9. Known issues

Record every non-blocking defect found by this pass here, with severity and the
build it was found on. Phase 12's acceptance criterion is that **no blocker or
data-loss defect remains** — a known issue may ship only if it is neither.

| Severity | Scenario | Description | Build | Status |
|----------|----------|-------------|-------|--------|

## 10. Sign-off checklist

- [ ] `flutter analyze`, `dart format`, `flutter test` all clean on the RC build
- [ ] `tool/validate_content.dart` passes
- [ ] Both stress tests pass; simulation and effects distributions recorded
- [ ] `restart_navigation_leak_test` passes (automated half of Section 7)
- [ ] Sections 2–8 executed on at least one device; results table filled in
- [ ] Offline pass (Section 2) completed with network disabled end to end
- [ ] Known Issues reviewed: no blocker, no data-loss defect
- [ ] High-severity findings fixed and re-verified before Phase 13 begins
