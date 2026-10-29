---
name: up-tower-defense-phase-review
description: Review, verify and close out a phase of the UpTowerDefense tower defense project against PLAN.md — checking deliverables, acceptance criteria, tests, architecture compliance, documentation sync and the offline promise. This skill should be used when a phase needs a status check, when a change is being prepared for review or a pull request, when auditing whether a feature really meets its acceptance criteria, when the phase status in README needs updating, or when reviewing a change for layer-boundary violations and missing documentation. It encodes the definition of done, the phase and milestone map, the code-review checklist, and the docs that must stay in sync.
agent_created: true
---

# UpTowerDefense — phase review and close-out

`PLAN.md` §8 defines Phases 0–14 and §12 defines four milestones. Each phase
has deliverables and acceptance criteria. This skill is how a change is checked
against them before the phase is called done.

**A phase is not done because the code works.** It is done when the acceptance
criteria are met, the tests pass, the architecture holds, and the documentation
matches the behaviour.

---

## 1. Phase and milestone map

| Milestone | Phases | Gate |
|---|---|---|
| **A** — Technical prototype | 0–3 | Movement, timing, pause behaviour and content validation are reliable |
| **B** — Playable combat slice | 4–7 | Economy and combat tests pass; no duplicate rewards or invalid state transitions |
| **C** — Content-complete MVP | 8–9 | The full campaign is completable offline and progress survives relaunch |
| **D** — Release-quality game | 10–13 | Release checklist passes on target devices; critical bugs and data-loss risks resolved |

Current status in this repo: **Phase 4 complete**. Phases 0–4 are done; Phase 5
(targeting, attacks, projectiles, damage) is next.

**Do not start a later content-heavy phase while an earlier phase's acceptance
criteria are failing.** In particular, do not author the 10-level campaign
(Phase 8) before the combat slice is proven.

---

## 2. The review procedure

### Step 1 — Establish the scope

Read the phase's **Deliverables** and **Acceptance criteria** in `PLAN.md`.
Read the corresponding **rules** in `docs/GAME_DESIGN.md`. List what the change
actually touched, then check each acceptance criterion against the code — not
against the commit message.

### Step 2 — Run the gates

```bash
dart format --line-length 80 lib test
flutter analyze
env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy flutter test
```

The `env -u` prefix is **required in the sandboxed IDE shell**: the proxy
variables intercept `flutter_tester`'s local WebSocket and every test fails with
`Unable to connect to flutter_tester process: WebSocketException: Invalid
WebSocket upgrade request`. That is an environment problem, not a code problem.
`flutter analyze` is unaffected.

Targeted runs while iterating:

```bash
flutter test test/unit/level_session_test.dart
flutter test test/unit/content_assets_test.dart
flutter test test/widget/build_tower_test.dart
```

### Step 3 — Check the architecture

| Check | How |
|---|---|
| Domain imports no Flutter or Flame | `Grep` for `package:flutter` and `package:flame` under `lib/features/gameplay/domain/**` |
| No gameplay rule in a Flame component | read `lib/features/gameplay/flame/**` — components must read the session, not decide |
| Rendering never touches saves or unlocks | same |
| No wall-clock time in the domain | `Grep` for `DateTime.now`, `Timer`, `Future.delayed` under `lib/features/gameplay/domain/**` |
| Definitions immutable, runtime state separate | no mutation of a shared definition |
| Per-frame state not in global providers | check `Riverpod` providers for entity-level state |

### Step 4 — Check the simulation invariants

- Each enemy resolves once; the kill reward is paid once; the leak penalty is
  applied once.
- A refused economy operation leaves gold and occupancy untouched.
- Waves never overlap.
- Victory only when every wave spawned and no enemy is active or pending.
- Defeat only when core health reaches zero, and only once.
- Results are frame-rate independent, and a test proves it.
- Pausing freezes every simulation-bound timer.

### Step 5 — Check the offline promise

- The **release** manifest declares **no permissions**:
  `android/app/src/main/AndroidManifest.xml` must contain no `<uses-permission`.
- Debug and profile manifests keep `INTERNET` for the Flutter VM service.
- No gameplay path calls a network or account API.

`test/unit/offline_guard_test.dart` enforces the manifest rules — do not weaken
it to make a change pass.

### Step 6 — Check the documentation is in sync

| Document | Update when |
|---|---|
| `docs/GAME_DESIGN.md` | A gameplay rule changes |
| `docs/GAME_DESIGN.md` §14 decisions log | **Any** intentional deviation from PLAN.md — with the reason and the phase |
| `docs/CONTENT_AUTHORING.md` | A JSON data format changes |
| `docs/ASSET_ATTRIBUTIONS.md` | An external asset or package licence is added |
| `README.md` | The phase status, layout, commands or conventions change |
| `docs/adr/` | A new architectural decision is made (new ADR, accepted status) |
| `AGENTS.md` | An operating rule changes |

A rule implemented without a decisions-log row is an incomplete change.

---

## 3. Definition of done

A phase is complete only when all of these hold:

1. The phase's deliverables exist and can be demonstrated.
2. The acceptance criteria in PLAN.md are met.
3. Relevant automated tests pass.
4. `flutter analyze` and `dart format` are clean.
5. No new critical error or resource leak is known.
6. README and design docs are updated where behaviour, setup or architecture
   changed.
7. The app is runnable from a clean checkout.

---

## 4. Code review checklist

### Correctness

- [ ] The rule is expressed in the domain layer, not in a component or widget.
- [ ] Results do not depend on the frame rate.
- [ ] No `double` where an integer is required (gold especially).
- [ ] No unbounded collection growth per frame.
- [ ] Every listener, timer and notifier is disposed.
- [ ] The engine, controller and selection are released when leaving the screen.

### Transactions and state

- [ ] Money operations are atomic.
- [ ] Refusals are typed and leave state untouched.
- [ ] No reward or penalty can fire twice.
- [ ] Invalid state transitions are rejected, not silently tolerated.

### UI

- [ ] The UI never reports success before the domain operation succeeded.
- [ ] Disabled and unaffordable states are visually distinct.
- [ ] Touch targets are large; state is not conveyed by colour alone.
- [ ] Safe areas are respected.
- [ ] The HUD does not cover the route or make build pads hard to tap.

### Content

- [ ] Every new or changed content file passes
      `flutter test test/unit/content_assets_test.dart`.
- [ ] A new map is registered in `ContentCatalog.mapAssetsById`.
- [ ] Balance values live in JSON, not in widgets or combat code.
- [ ] External assets are recorded in `docs/ASSET_ATTRIBUTIONS.md`.

### Tests

- [ ] New behaviour has a test.
- [ ] Domain tests do not pump a widget.
- [ ] Fixtures are reused from `test/helpers/` rather than reinvented.
- [ ] Tests assert the exact rule, not merely the absence of an effect.
- [ ] Time-based behaviour is tested at more than one frame rate.

---

## 5. Reporting a review

Report in this shape:

```markdown
## Phase N — <name>

**Verdict:** complete / incomplete / blocked

**Acceptance criteria**
- [x] <criterion> — <where it is satisfied>
- [ ] <criterion> — <what is missing>

**Gates**
- `flutter analyze` — clean
- `flutter test` — 155 passed
- `dart format --line-length 80 lib test` — clean

**Architecture**
- Domain imports no Flutter/Flame: pass
- No gameplay rule in Flame components: pass
- Offline promise intact: pass

**Docs updated**
- GAME_DESIGN §<n>, decisions log D<n>
- README phase status

**Remaining risks**
- <risk> — <mitigation or next step>

**Next phase prerequisites**
- <what must be true before Phase N+1>
```

Be explicit about criteria that are **not** met. A review that claims
completeness while criteria are open is worse than no review.

---

## 6. Scope discipline

The plan is explicit: implement the smallest vertical slice that proves a
feature end to end, and **do not implement later-phase features** unless they
are explicitly requested or needed to unblock the current phase.

Concretely, while in Phase 5 (targeting, attacks, projectiles, damage):

- Do not add the Cannon and Frost towers — that is Phase 6.
- Do not add tower upgrades or selling — Phase 6.
- Do not add the result screen or rewards — Phase 7.
- Do not author the 10-level campaign — Phase 8.
- Do not add the save repository — Phase 9.

An opportunistic extra feature is a review finding even when it works, because
it expands the surface that must be verified and it pulls later-phase content
into an unfinished phase.
