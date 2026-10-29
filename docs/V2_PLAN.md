# UpTowerDefense v2 — Product and Delivery Plan

Plan for the release after 1.0: what version 2 adds, in what order, and how each
step is judged done. It extends [`PLAN.md`](../PLAN.md) §8 ("Phase 14 — Post-MVP
Enhancements") rather than replacing it; the architecture rules in
[`AGENTS.md`](../AGENTS.md) and
[ADR 0001](adr/0001-flutter-flame-layer-boundaries.md) apply unchanged.

**What "version 2" means here.** A product release (`2.0.0`), not a dependency
bump. The toolchain re-verification is one small phase inside it (V2-0), because
a store update is also the moment we are forced to re-check Flutter, Flame and
platform requirements.

**Status.** The plan is proposed; no v2 phase is complete. Work landed ahead of
V2-3: all ten campaign levels now declare objectives, and the decoder, content
gate and `CONTENT_AUTHORING.md` cover their format and authoring constraints.
Objective evaluation, stars, HUD/results and save v4 remain unimplemented.
Planned scope decisions are recorded in [`GAME_DESIGN.md`](GAME_DESIGN.md) §14
(D63–D70); implementation-specific decisions still to be logged are listed in
§8 below.

---

## 1. Baseline — what 1.0 ships

Read from the shipped code and content, not from older phase notes.

| Area | Today |
|---|---|
| Campaign | 10 levels, 2 regions (Meadow Reach, Ember Pass), 1 map each |
| Towers | 3 (`ranger`, `frost`, `cannon`); upgrade to level 3, sell at a rate |
| Enemies | 4 (`grunt`, `runner`, `brute`, `boss`) |
| Modes | Campaign, plus Endless with a persisted best (D62) |
| Rating | Global star rule from core health (D35); objective data authored but not yet scored |
| Meta | Unlock-by-order (D33), tutorial (D52), codex (D53), credits (D51) |
| Save | One versioned document, schema v3 (`results`, `settings`, `endlessBest`) |
| Settings | Music/SFX switches + sliders, reduced motion, haptics switch |
| Offline | Release manifest declares no permissions; `offline_guard_test` pins it |
| Balance | `tool/balance_probe.dart` + pinned `balance_regression_test` table |
| Release | APK and iOS simulator builds verified; store accounts still pending |

**Known gaps 1.0 carries into v2, and must close in it:**

1. The haptics switch is persisted and shown but drives nothing.
2. Phase 12's manual device pass is not signed off.
3. Phase 13 still needs signed store uploads and the iOS archive path.

---

## 2. Goals

1. **More to come back for** without a second campaign's worth of new rules.
   Target: 15 campaign levels across 3 regions, 5 towers, 6 enemy types.
2. **Reasons to replay the levels we already have**: per-level objectives,
   difficulty modes, a daily seeded challenge, local achievements.
3. **No regression of the offline promise**: still zero permissions, zero
   network calls, zero account, and no wall-clock reads inside the domain.
4. **No save loss on upgrade.** A 1.0 save opens in 2.0 with progress, settings
   and endless best intact.

Non-goals for v2 (unchanged from PLAN §2.2): accounts, cloud saves, multiplayer,
leaderboards that need a server, ads, purchases, user-generated content, a level
editor, procedural campaign maps, 3D, and any remote configuration.

---

## 3. Themes

| Theme | Contents | Why it is in v2 |
|---|---|---|
| A. Content | Region 3 and five levels; one new map; boss phases | The cheapest depth: the formats, validator and probe already exist |
| B. Roster | Tower 4 and 5; enemies 5 and 6 | Each answers a gap the current roster has, and each is measured against a control (D55–D60 method) |
| C. Modes | Objectives, difficulty, daily challenge | Turns the same levels into more than one evening's play |
| D. Meta | Local achievements, progress screen | Gives long-tail goals without a currency (D39 stays intact) |
| E. Foundation | Haptics wiring, toolchain re-verification, save v4/v5, QA | Closes 1.0's gaps and pays down the risk of a second major release |

---

## 4. Phases

Sizes are indicative engineering effort for one developer already fluent in the
repo: **S** ≈ 1–2 days, **M** ≈ 3–5, **L** ≈ 6–10. They exist to sequence work,
not to promise a calendar.

Each phase follows the definition of done in AGENTS.md §9: deliverables,
acceptance criteria, tests, `flutter analyze` + `dart format`, docs updated in
the same change, app runnable from a clean checkout.

### Delivery stages

Keep the seven numbered phases as the work units; group them into these five
milestones so each stage has a reviewable outcome and a clear dependency gate.
Do not start a later stage by skipping an unmet gate.

| Stage | Phases | Outcome | Exit gate |
|---|---|---|---|
| 1. Foundation | V2-0 | Verified toolchain, signed-off device QA, performance baseline, working haptics switch | V2-0 acceptance criteria pass; no platform permission added |
| 2. Content and roster | V2-1 → V2-2 | Third region plus final five-tower/six-enemy roster | V2-1 passes with the original three towers; V2-2 passes mechanic and same-slot tests, then pins the full 15-level roster probe |
| 3. Replay systems | V2-3 | Objectives, Normal/Hard campaign, deterministic daily challenge; save v4 | V2-1 and V2-2 probe gates pass; both difficulty columns are pinned; v1.0 save compatibility remains covered |
| 4. Progression and usability | V2-4 → V2-5 | Achievements, progress screen, save v5, accessibility/tutorial updates | Achievement facts are persisted once; large-text, labels and reduced-motion criteria pass on the completed V2 UI |
| 5. Release | V2-6 | QA evidence and store-ready 2.0 build | Every earlier stage is signed off; all V2-6 release acceptance criteria pass |

**Critical order:** V2-0 → V2-1 → V2-2 → V2-3 → V2-4 → V2-5 → V2-6.
V2-2 re-runs the probe after its new roster lands; that final table is the gate
for V2-3. V2-4 consumes the daily results and save-v4 model from V2-3. V2-5
comes after the relevant UI and mechanics exist, so its accessibility pass tests
the actual 2.0 surfaces rather than placeholders.

### V2-0 — Foundations and the 1.0 promise (S)

**Goal:** start v2 from a build that has no known broken switch and a verified
toolchain.

Tasks:

- Wire the haptics switch through a two-method sink, the same shape as the SFX
  sink (D47): gameplay cues ask the sink, the sink decides, tests never touch a
  platform channel. Cues limited to build, upgrade, sell, leak, victory, defeat.
- Re-verify Flutter/Dart/Flame against current stable and record the versions in
  README and AGENTS.md. Bump only with a green suite and a device run.
- Re-run the performance baseline (both stress tests) on the release build and
  write the numbers into the QA doc, so v2's content has a before picture.
- Sign off Phase 12's manual device pass or shrink it to what still applies.

Acceptance criteria:

- Toggling haptics off produces no platform call; toggling on produces one per
  configured cue. A unit test asserts the cue mapping, not the vibration.
- No platform permission or new `Info.plist` usage key was added.
- The baseline table exists and covers a stress level plus a normal level.

### V2-1 — Region 3: the third act (M)

**Goal:** 15 campaign levels across 3 regions, with no new subsystem; the
single bounded boss phase below is the only new combat rule in this phase.

Tasks:

- Author `assets/data/maps/` entry for the region (one map, new route shape;
  topology and pacing only, no palette field and no hazard — D63).
- Author five levels with cresting difficulty; extend `campaign.json` and give
  each new campaign level exactly two objectives using the already-authored D68
  format. This is content authoring only; V2-3 still implements objective scoring
  and presentation. Every level must remain completable with the three towers
  already shipped; the two V2-2 towers may add options but must not become a
  progression requirement.
- Give the existing boss one data-driven speed-surge phase with validated fields
  `speedSurgeHealthRatio` (0.5; valid range `(0, 1]`),
  `speedSurgeMultiplier` (1.5; must be `> 1`) and
  `speedSurgeDurationSeconds` (3; must be positive). It triggers once when
  health first reaches or drops below the threshold and uses simulation time,
  never wall-clock time.
- Teach the speed surge in one level before it is required.

Acceptance criteria:

- `content_assets_test`, `campaign_assets_test` and
  `tool/validate_content.dart` all pass; every pad is reachable, clear of the
  top HUD band (D62 rule), each new campaign level has two feasible objectives,
  and the level leaves enough gold to build.
- With the three currently shipped towers, the balance probe runs 15/15 levels
  under all four strategies; update the pinned table in `balance_regression_test`
  in the same change as the data.
- The boss phase is covered by domain tests for its threshold, one-time trigger,
  duration and frame-rate independence; all three named fields are validated for
  bounds and are accepted only on the boss definition.
- No new package and no new content field that the validator does not check.

**Risk to watch:** a third map tempts extra mechanics. The boss speed surge above
is the sole V2-1 exception and is fixed by D69; any other new rule belongs in a
separately scoped phase, not in this content pass.

### V2-2 — Roster: two towers and two enemy families (L)

**Goal:** depth in the existing systems; each addition has a job the current
roster cannot do, proven with the probe.

Tower 4 — **Arc** (chain): hits its target, then arcs to the nearest enemy
within a jump radius for decaying damage.

- New mechanic, so: fields in the tower schema (`chainCount`, `chainRadius`,
  `chainFalloff`), validated; the jump order is deterministic (distance, then
  id) so a replay and a test agree; each victim is damaged once per shot.
- Splash and chain must not both apply to the same victim twice; that rule is
  asserted, not assumed.

Tower 5 — **Beacon** (support aura): buffs the range of towers in radius
instead of dealing damage (D64).

- Every reader goes through one `LevelSession` accessor for effective stats
  (target check, drawn range circle, tower panel and its `Next:` preview), so
  no consumer can miss the buff and disagree with another (AGENTS.md §3). The
  accessor answers for a level, `TowerLevelStats` gains `copyWith`, and
  `_TowerDetails` takes the values from `_PadPanel`, which already holds the
  session.
- Only the strongest aura covering a tower applies; two Beacons never compound.
  A test pins the rule.
- AGENTS.md §3's stats wording becomes "the session's effective stats, derived
  from the instance" in the same change.

Enemies 5 and 6:

- **Bulwark** — flat per-hit damage reduction, so many weak hits underperform
  and splash/chain gain value.
- **Splitter** — on death, spawns two smaller enemies at the same route progress
  (and skips the frame's movement, per the spawn rule). Each child resolves
  exactly once through the existing single resolution path; the parent's reward
  is paid once.

Acceptance criteria:

- Each new mechanic has a domain test at `1/60`, `1/30` and a coarse step.
- The probe includes a same-slot control for both new towers (D55's method), and
  each new tower beats that control somewhere and never loses everywhere.
  If a tower cannot reach that bar, it is not shipped with a number tweak alone;
  the structural cause is reported first (D54/D56 precedent).
- Codex picks the new content up from data, with no prose that is not derived
  from fields.
- Every sprite added is recorded in `ASSET_ATTRIBUTIONS.md` before it ships.
- Before V2-2 closes, rerun the full 15-level probe with the expanded five-tower
  roster under all four strategies and update the pinned regression table. V2-3's
  balance gate uses this final table.

### V2-3 — Modes: objectives, difficulty, daily (M–L)

**Goal:** more than one way to play the levels that exist.

**Per-level objectives (supersedes D35, D68).** Every campaign level declares
exactly two objectives as data (the ten existing levels already do; scoring and
presentation remain to be implemented):

```json
"objectives": [
  { "kind": "noLeaks" },
  { "kind": "maxTowers", "value": 3 }
]
```

Four kinds in v2: `noLeaks`, `maxTowers`, `deadlineSeconds`, `coreAbove`.
`maxTowers` means never exceeding N simultaneously standing towers; it measures
peak concurrent occupancy, not total towers built. Text is derived from kind and
value, never authored, and `coreAbove` must sit below
the level's core so it cannot restate `noLeaks`. Stars are `1 + met`, defeat is
0, and a level without objectives (fixtures, endless) keeps the 1.0 ladder.

- Authoring half is in: all ten campaign levels declare their two goals, the
  format is documented in `CONTENT_AUTHORING.md`, and the content gate checks
  shape, bounds and gold feasibility. The star rule, HUD and result lines are
  what remain.
- `LevelSession` exposes one objective status, including the highest number of
  towers that stood simultaneously; selling cannot lower this recorded peak.
  `LevelHudState` publishes `objectivesMet`, and the HUD, result panel and
  `LevelRating` all read that same value, so the displayed count and the awarded
  stars cannot disagree.
- HUD gains one `Goals n/2` chip; the pause panel, result panel and picker show
  the derived sentences.
- `LevelResult.objectivesMet` rides save v4 beside D65's difficulty keys;
  `stars` stays authoritative and is never recomputed on load, so 1.0 stars
  survive whatever the new objectives would have scored.
- Content gate: 0 or exactly 2 per level, two for every campaign level, none on
  endless; kinds, values and duplicates validated; feasibility checked at load
  (pad count, gold per shipped profile, deadline at least the level's minimum
  spawn duration); `balance_regression_test` pins three-star achievability for
  the opening levels and the probe reports stars for all of them.

**Difficulty modes (revisits D61).** Normal and Hard as one data profile in
`assets/data/difficulties.json`, applied by `LevelRepository` when it resolves
the bundle, so the session never learns difficulty exists (D65). The profile
multiplies wave group counts and starting gold; core health stays authored so
the star rule keeps its meaning.

- Gate: start only when V2-1 and V2-2 pass the probe. D61 deferred modes because
  two campaigns would be tuned at once; that reason has not expired, so the cost
  must be paid explicitly: the pinned table gains a second column, and every
  balance claim names its mode.
- Unlock rule: Hard opens per region once that region's levels are cleared on
  Normal, so it can never strand a first-time player.
- Plumbing: the profile is an explicit `load` argument, never an ambient read,
  and it joins the bundle provider key and the `play/:levelId` route key —
  `GameplayScreen._gameFor` keeps the first game it builds, so a new bundle
  alone would be ignored.
- Save v4 keys results by level **and** difficulty (Normal default); the
  picker, campaign totals, unlock message and D67 achievements state which mode
  they read.
- The content gate runs its "starting gold affords a tower" assertion per
  shipped profile, validates the transformed level, and keeps gold arithmetic
  integer.
- `tool/balance_probe.dart` gains a difficulty argument, or V2-6 cannot produce
  the second column.

**Daily challenge (seeded, offline).**

- Presentation reads the local date as `yyyyMMdd` and passes it as a **seed**.
  A pure deterministic selector uses xorshift32 (`x ^= x << 13`, then
  `x ^= x >> 17`, then `x ^= x << 5`) with unsigned 32-bit arithmetic after
  each step; zero state maps to `0x6D2B79F5`. The resulting value modulo the
  campaign's stable ordered level-id list selects the daily level. Its
  authored map, waves and objectives run unchanged on Normal; the daily result
  updates only that date's daily record, never campaign results, stars or unlocks
  (D70).
- Reset is local midnight, and a run that started before midnight finishes
  under the seed it began with. A missed day is simply missed; nothing is
  unrecoverable and nothing needs a server. Best run per date is local.

Acceptance criteria:

- The selector produces the same campaign level id for a fixed date seed,
  asserted against pinned dates and expected ids; the selected run uses that
  level's authored map, waves and objectives unchanged, and only its daily-date
  record is updated.
- The offline guard still passes with no permission and no network dependency.
- Objectives do not soft-lock: any objective a player cannot satisfy is shown as
  failed immediately, not at the result screen.
- Hard mode cannot be entered before it is unlocked, and no level becomes
  unwinnable at the shipped difficulties (probe, both modes).

### V2-4 — Meta: local achievements and a progress screen (M)

**Goal:** long-tail goals with no currency, no account, no network.

Tasks:

- The ten achievements D67 fixes, each derived from facts the save already
  stores: first clear, untouched core, any three stars, one region cleared,
  one region three-starred, campaign cleared, campaign three-starred, endless
  wave 10, endless wave 20, one daily finished. Nothing is tracked per frame;
  the save stores ids.
- One progress screen: campaign totals, endless best, daily best, achievements.
  It reads from the same providers the menu already uses (D44 pattern) so two
  screens cannot count differently.
- Save **v5** adds `achievements` and daily results; loading a v3/v4 save fills
  defaults, and the repository-level upgrade test gains the new pairs.

Acceptance criteria:

- Achievements unlock exactly once, on the same single resolution path that
  records results; a restart or a replay cannot double-award.
- A v1 save still loads (firstVersion stays 1) and a v3 save keeps stars,
  settings and endless best.
- No achievement requires a rule the domain does not already own.

### V2-5 — Accessibility and difficulty of understanding (S)

- Large-text audit of the HUD, panels and result card at the largest system
  text scale; fix overflow rather than clipping.
- Screen-reader labels for the build panel, tower panel and HUD chips.
- Tutorial additions for the new mechanics (chain, aura, splitter), same
  step-card rule as D52: every step advances by its own button, no soft-lock.
- Colour-independence re-check for the new effects and enemy types (D46 rule:
  silhouette, never colour alone).

Acceptance criteria:

- Nothing in the gameplay HUD or a panel overflows at 1.3× text scale on the
  reference landscape size.
- Every interactive element has a label that names the action and its cost.
- Reduced motion removes motion from new effects but keeps the information.

### V2-6 — Balance, QA, release 2.0 (M)

Tasks:

- Full probe run over 15 levels × both difficulties × four strategies; re-pin
  the regression table; write the outcome table into the phase report.
- Extend `docs/QA_SCENARIOS.md` with the daily challenge, difficulty switching,
  achievement unlock and a save-upgrade-from-1.0 scenario.
- Bump `pubspec.yaml` to `2.0.0+<build>`; update store listing, screenshots and
  release notes; re-check the age rating for the new content.
- Build release APK and the iOS archive path; verify an upgrade install over a
  1.0 build with real progress.
- Update README phase/status line, AGENTS.md toolchain table and this document's
  status clause.

Acceptance criteria (all must hold to ship):

- `dart format` clean, `flutter analyze` clean, full suite green.
- `offline_guard_test` green; release manifest still declares no permissions.
- Save upgrade verified on a device: 1.0 → 2.0 keeps progress, settings, stars
  and endless best, and a damaged save still falls back safely.
- No known blocker, data-loss defect or resource leak.
- Store assets describe the build that actually ships.

---

## 5. Version and save policy

- **App version:** `2.0.0` at V2-6. Build number stays monotonic per store
  upload. Intermediate phases ship as internal builds (`1.1.0+*`) if they are
  installed on devices at all.
- **Save schema:** v4 lands with objectives/difficulty results (V2-3), v5 with
  achievements and dailies (V2-4). Both are additive and default-filled; the
  codec keeps `firstVersion = 1`, so every save ever written stays readable.
- A schema bump is never a repair: an unreadable field still refuses loudly
  (D42), and a load still never writes.
- A 2.0 save is not expected to open in 1.0. Forward compatibility is not
  promised, and the store release note says progress is kept on update.

## 6. Measurement plan

Nothing in v2 is accepted on reasoning alone; the 1.0 balance work set the bar.

| Claim | How it is checked |
|---|---|
| A tower has a job | Probe vs. same-slot control, order-matched (D55) |
| Difficulty modes are fair | Probe on both modes, both pinned |
| A mechanic is frame-rate independent | Same outcome at `1/60`, `1/30`, coarse step |
| Performance did not regress | Both stress tests plus the V2-0 baseline table |
| Content is valid | `content_assets_test` + `campaign_assets_test` + validator tool |
| Nothing online crept in | `offline_guard_test`, plus a manual airplane-mode run |
| Saves survive | Codec tests for every version pair, plus device upgrade test |

## 7. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| v2 scope grows into a second game | Release slips indefinitely | Themes are capped: 5 new levels, 2 towers, 2 enemies; everything else moves to a v3 list |
| Difficulty modes double the tuning surface | Balance gate becomes unmaintainable | Start only after V2-1/V2-2 pass; second pinned column, per-mode claims |
| A support tower cannot earn its slot | Fails the "useful situation" bar | Structural fixes measured first (D56/D60 method); ship fewer towers rather than a dead one |
| Chain/aura break deterministic combat | Replays and tests disagree; single-resolution rule broken | Deterministic tie-breaking, one damage application per victim, explicit tests |
| Save bumps lose progress | Trust damage worse than a missing feature | Additive fields, defaults, every version pair tested, device upgrade run |
| Toolchain bump breaks pinned Flame APIs | Mid-phase rework | Isolated in V2-0, with the suite and a device run as the gate |
| New art lacks provenance | Cannot ship | Attribution recorded before the asset lands, per AGENTS.md §5 |
| Daily challenge reads a clock in the wrong layer | Untestable, non-deterministic runs | Date is read in presentation and passed as a seed; domain stays clock-free |

## 8. Decisions logged, and still to log

Already in `docs/GAME_DESIGN.md` §14 as planned v2 rows:

- **D63** — region 3 is route topology and pacing (V2-1).
- **D64** — Beacon buffs range, one aura, one accessor (V2-2).
- **D65** — Hard is one load-time data profile, campaign only (V2-3).
- **D66** — the daily seeds from the local date, and a run keeps its seed
  (V2-3).
- **D67** — ten achievements, derived from stored facts (V2-4).
- **D68** — objectives replace core-health stars (V2-3).
- **D69** — the existing boss has one speed surge with a fixed threshold,
  multiplier and duration (V2-1).
- **D70** — a daily seed selects one existing campaign level deterministically;
  its authored content runs unchanged and records only a daily result (V2-3).

Still to log at the phase that introduces them:

- Haptics cue set and why it is cosmetic, not a rule.
- Chain targeting order and falloff shape.
- Splitter children and reward accounting under the single-resolution rule.
- Save v4/v5 field sets and their defaults.

## 9. Resolved questions

The plan's scope questions are answered; each answer is a decision in the log,
and the phases below are written against them.

1. **Region 3 identity** — neither a new palette nor a hazard: same field
   rendering, new route and pads (D63).
2. **Beacon's buff** — range, strongest single aura, read through one accessor
   (D64).
3. **Hard mode shape** — one global load-time profile, applied only to the
   campaign (D65).
4. **Daily reset boundary** — local midnight, date as the seed, in-flight run
   keeps its seed (D66).
5. **Achievements scope** — exactly ten, all derived from facts the save
   already holds (D67).
6. **Boss phase** — one speed surge at or below 50% health, at 1.5× speed for
   three simulation seconds, once per boss (D69).
7. **Daily run composition** — xorshift32 seeded by the local date selects one
   level from campaign order; its content and objectives remain unchanged, and
   the result is isolated from campaign progress (D70).

## 10. Definition of done for v2

1. All seven phases (V2-0 through V2-6) meet their acceptance criteria.
2. 15 levels, 3 regions, 5 towers and 6 enemies ship, with Normal/Hard campaign
   runs and one seeded daily selection of an existing campaign level.
3. Every tower beats an order-matched control somewhere and never loses
   everywhere.
4. `analyze`, `format`, the full suite and the content validator are clean.
5. 1.0 saves upgrade on a device without loss, and the offline promise is
   unchanged.
6. README, GAME_DESIGN decisions log, CONTENT_AUTHORING, QA scenarios, release
   checklist and store listing all describe the shipped build.
7. A tagged commit builds a store-ready APK and an iOS archive.
