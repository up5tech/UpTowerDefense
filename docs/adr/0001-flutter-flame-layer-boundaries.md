# ADR 0001 — Flutter/Flame layer boundaries

- **Status:** Accepted (Phase 0)
- **Date:** 2026-10-25
- **Deciders:** Project owner, implementation agent
- **Related:** [`PLAN.md` §5](../../PLAN.md), [`docs/GAME_DESIGN.md`](../GAME_DESIGN.md)

## Context

UpTowerDefense is a 2D, single-player, offline tower defense game for Android and
iOS. The gameplay rules that decide whether a level is won — gold, waves, damage,
death, leaks, upgrades, unlocks — are the parts most likely to change during
balancing and the parts that are hardest to debug when they are entangled with
rendering.

Flame is a component framework: components own their own update loop, they hold
references to each other, and their lifecycle is tied to the game tree. That is
excellent for rendering and input, and dangerous as a source of truth, because
rules living in components can only be tested by running a game, they break when
components are removed, and they make reward duplication or stale-target bugs
easy to introduce.

Flutter widgets provide the rich, accessible, localisable UI the plan requires
for menus, HUD panels, dialogs, and the result screen. Re-implementing those as
canvas components would cost accessibility and text layout for no benefit.

## Decision

The project is split into five layers with a strict direction of dependency:

1. **Domain / gameplay (plain Dart, no Flutter imports).** Immutable content
   definitions plus explicit mutable run state and the systems that advance it:
   wave scheduling, path progress, targeting, damage, status effects, economy,
   outcome evaluation, rewards. Deterministic, simulation-time based, and tested
   with no engine running.
2. **Application layer.** Coordinates a level attempt: start/restart,
   pause/resume, result handling, unlock updates, save requests. Owns the level
   state machine and its legal transitions.
3. **Game presentation (Flame).** `FlameGame` entry point, world/camera/viewport,
   map, towers, enemies, projectiles, effects. Reads simulation state and
   visualises it, and forwards input intent (pad tapped, tower tapped) inward.
4. **Flutter presentation.** Menus, level select, HUD panels, settings, dialogs,
   result screens. Converts input into explicit application commands and renders
   state exposed by the layers below.
5. **Data layer.** Save repository, settings repository, content/config loading
   and asset manifest integration. No frame-by-frame gameplay logic.

Rules that follow from this split:

- **Flame components are never the sole source of truth** for gold, level
  outcome, upgrade costs, or campaign unlocks.
- Domain code must not import `package:flutter/*` or `package:flame/*`, and must
  not read screen dimensions. Screen-space concerns live in the presentation
  layers.
- Rendering code must not read or write save files or decide unlocks.
- Definitions (tower/enemy/level/map config) are immutable and shared; mutable
  per-instance state (`TowerInstance`, `EnemyState`, `PlayerRunState`) is separate
  and never written back into a definition.
- Time enters the simulation as an explicit `dt` and a speed multiplier; nothing
  in the domain layer reads wall-clock time.
- High-frequency per-frame entity state is not pushed through global UI state
  providers; the HUD subscribes to coarse, intentionally published values.

## Consequences

**Positive**

- Core rules are unit-testable without a renderer, including edge cases such as
  simultaneous deaths, duplicate rewards, leaks, and pause/speed interaction.
- Balancing lives in data definitions, so tuning does not touch combat code.
- Widget tests can exercise HUD logic against a fake application layer.
- The simulation can later support deterministic replays without redesign.

**Negative / costs**

- Some state is mapped twice: domain entities and their Flame components, with an
  explicit synchronisation step each frame. This is accepted for testability.
- Input must travel widget/component → application command → domain, which is more
  indirection than a component mutating fields directly.
- Discipline is required to keep Flame components thin; review should reject
  gameplay decisions added to components.

## Alternatives considered

- **All logic inside Flame components.** Fastest to a prototype, but untestable
  rules and fragile lifecycle. Rejected.
- **Flutter widgets only, custom painter for the world.** Loses Flame's component
  lifecycle, effects, and input helpers, and pushes the game loop into widget
  rebuilds. Rejected.
- **ECS library on top of Flame.** Not justified before a real performance or
  structural problem appears (per the plan's "no premature abstraction" rule).
  Revisit in Phase 12 if profiling demands it.

## Compliance checks

- `lib/features/gameplay/domain/**` imports no Flutter or Flame APIs.
- Domain tests construct state and call systems directly, never `pumpWidget`.
- `flutter analyze` with `flame_lint` remains clean.
- Code review rejects gameplay rules added to `lib/features/gameplay/flame/**`
  components that are not already expressed by the domain layer.
