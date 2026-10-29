# Store listing materials — Phase 13

Source copy for both stores, kept in the repo so it can be reviewed with code.
Update it in the same change as any shipped behaviour — the acceptance
criterion is that store materials *accurately* represent the offline
gameplay and the monetization model.

## 1. Short description (Play, ≤80 chars)

```
Offline tower defense. No wifi, no accounts, no ads — just build and defend.
```

## 2. Full description (Play / App Store)

```
UpTowerDefense is a complete tower defense game that works entirely offline.

Build towers on map pads, upgrade them between waves, and hold the line
against runners, brutes, tanks and bosses across a ten-level campaign.
Every tower has a real role — rangers pick off the fastest targets,
cannons splash whole crowds, frost slows a push you can't out-damage —
and every number you see in the codex is the number the simulation uses.

• Ten hand-built campaign levels with a difficulty curve that teaches one
  idea at a time
• Three tower families with four upgrade levels and switchable targeting
• A bestiary that shows the real stats of every enemy you face
• Pause, restart and 2x speed any time; a level remembers nothing between
  tries and everything after you win
• Play on a plane, underground, anywhere: the game has no network access,
  no account and no permissions

No ads. No purchases. No account. No internet permission. Progress and
settings are stored on your device only, with a built-in backup copy if
a save is ever damaged.
```

## 3. Privacy disclosures

- **Data collection:** none. The app declares no network permission and
  contains no analytics, crash reporting or advertising SDKs (pinned by
  `offline_guard_test`).
- **Data shared with third parties:** none.
- **Data stored on device:** campaign progress and settings, in local
  storage only; never transmitted. No export leaves the device.
- **Account / sign-in:** none.
- **Kids' privacy (COPPA-style answers):** no data is collected from anyone,
  including children; nothing to disclose to a data-collection service.
- Store privacy forms should therefore declare **"Data not collected"** and
  link here or restate it verbatim.

## 4. Age rating answers (typical questionnaire items)

| Question | Answer |
|---|---|
| Violence / conflict | Cartoon tower-defense combat: stylised sprites and simple effects; no blood, gore, weapons pointed at people, or realistic violence. |
| Horror / fear / mature themes | None. |
| Gambling / betting / prizes | None. |
| Ads or in-app purchases | None — no monetisation of any kind ships in this build. |
| User interaction / chat / sharing | None; no multiplayer, no sharing, no external links in gameplay. |
| Unrestricted web access / network | None; the release manifest declares no permissions at all. |
| Medical / location / personal data | None collected or used. |

Expected classification: everyone / PEGI 3–7 equivalent (cartoon fantasy
combat). Confirm per-store questionnaire wording at submission time.

## 5. Monetization statement

Free, one-time download, no ads, no IAP, no subscriptions, no rewarded
video. Any future monetisation is a Phase 14 decision and requires updating
this file, the age-rating answers and the privacy disclosure together.

## 6. Screenshots plan

Take on the reference device profile (§QA_SCENARIOS pass hardware) from the
**release** build, after the QA pass so the build is known-good:

1. Main menu (shows the campaign summary, fully offline).
2. Level select with locked/unlocked progression.
3. Gameplay mid-wave with towers firing and effects visible.
4. The pause overlay over a busy field.
5. The codex — tower page (real stats).
6. The result panel naming what it unlocked.

Sizes: Android phone 1080×1920 (portrait screenshots are accepted even for
landscape games; also capture 1920×1080 for the feature graphic and tablet
slots), iOS 6.7" and 6.5" screenshots from the archive. Keep the device
status bar honest (airplane mode icon is a feature here, not a mistake).

## 7. Metadata

| Field | Value |
|---|---|
| App name | UpTowerDefense |
| Short name | UpTowerDefense |
| Package / bundle id | `com.uptowerdefense.game` |
| Category | Action / Strategy (games) |
| Contact | project maintainer contact at submission time |
| Data safety form | "No data collected" per §3 |
