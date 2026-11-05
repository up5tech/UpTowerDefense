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
across fifteen hand-built levels in three regions — Meadow Reach, Ember
Pass and Hollow Court — against grunts, runners, brutes, bulwarks,
splitters and bosses that surge forward once they are nearly dead.

Every tower has a real role, and every number in the codex is the number
the simulation uses: rangers pick off the fastest targets, cannons splash
whole crowds, frost chills a push you can't out-damage, arc towers chain
damage across a line, and a beacon buffs every tower inside its aura.

• Fifteen campaign levels across three regions, each with two goals and up
  to three stars
• Five tower families with four upgrade levels and switchable targeting
• Six enemy types, including a boss that speeds up when it is nearly dead
• Normal and Hard: Hard opens per region once you clear that region on
  Normal, and each mode keeps its own stars
• A daily challenge picked from the date — the same level for everyone
  that day, and no server involved
• Ten achievements plus a progress screen with campaign totals, endless
  best and today's challenge
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

**v2 re-check (2.0.0).** The new content does not change any answer above: more
stylised enemy silhouettes (bulwark, splitter and its two small children), one
boss that moves faster below half health, an arc lightning chain and a beacon
aura ring. No blood, gore, weapons pointed at people, gambling, purchases, chat
or external links are added, so the classification stays everyone / PEGI 3–7
equivalent (cartoon fantasy combat). Re-state the answers on the store's form
rather than assuming the previous submission carries over.

## 5. Monetization statement

Free, one-time download, no ads, no IAP, no subscriptions, no rewarded
video. Any future monetisation is a Phase 14 decision and requires updating
this file, the age-rating answers and the privacy disclosure together.

## 6. Screenshots plan

Take on the reference device profile (§QA_SCENARIOS pass hardware) from the
**release** build, after the QA pass so the build is known-good:

1. Main menu (shows the campaign summary, fully offline).
2. Level select on Normal with the difficulty switch and the goals on each row.
3. Gameplay mid-wave on Hollow Court with towers firing, effects visible and
   the `Goals n/2` chip in the HUD.
4. The pause overlay over a busy field, listing the level's two goals.
5. The result panel: stars, goals met, and what the win unlocked.
6. The codex — tower page (real stats), including arc and beacon.
7. The progress screen: campaign totals, endless best, daily best and the ten
   achievements.
8. The daily challenge running, with the HUD naming the mode.

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
| Version | `2.0.0` (build `2.0.0+2`); a store upload requires a strictly higher `versionCode` than anything already uploaded |

## 8. Release notes — 2.0.0

Short form for the store's "what's new" field:

```
Version 2 adds a third region, two towers, two enemies, per-level goals,
Normal and Hard campaigns, a daily challenge and ten achievements. Still
fully offline: no account, no ads, no permissions.

Your progress, stars, settings and endless best are kept when you update.
```

Long form (store page or community post):

```
Version 2 doubles the reasons to come back without changing the promise:
the game still runs entirely offline, with no account and no permissions.

• Region 3 — Hollow Court: five new levels on a new switchback map, with
  the boss's new speed surge as its signature pressure.
• Two new towers: the Arc chains damage between nearby enemies, and the
  Beacon buffs the range of every tower in its aura.
• Two new enemies: the Bulwark shrugs off weak hits, and the Splitter
  breaks into two smaller enemies when it dies.
• Goals and stars: every campaign level now carries two objectives, and a
  run scores one star for finishing plus one per goal met (a defeat is 0).
• Normal and Hard: Hard fields more waves for less starting gold and opens
  per region once that region is cleared on Normal.
• A daily challenge picked by the date, offline, with its own record that
  never touches campaign progress.
• Ten achievements and a Progress screen over campaign totals, endless
  best and today's challenge.
• Accessibility: the HUD and panels fit larger system text, HUD facts and
  panel actions read out, and every enemy has a distinct silhouette.

Progress, stars, settings and your endless best are kept when you update.
A 1.0 save opens in 2.0 unchanged; nothing is reset.
```
