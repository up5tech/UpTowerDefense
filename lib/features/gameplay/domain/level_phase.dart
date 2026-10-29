/// Lifecycle of one level attempt.
///
/// `ready` means no wave has started yet, `waveTransition` is the visible pause
/// between a cleared wave and the next one, and `victory`/`defeat` are terminal.
/// Pause is deliberately *not* a phase: it freezes the clock rather than the
/// level's rules, so it belongs to the engine (see `LevelController`).
enum LevelPhase { ready, playing, waveTransition, victory, defeat }

/// The legal level-flow transitions, in one place.
///
/// The table exists so the state machine can be read, tested and reviewed
/// without simulating a level, and so an illegal move fails a debug assert
/// instead of leaving a level stuck in a phase that can no longer progress.
/// Anything a rule needs must be added here deliberately — a missing edge is a
/// bug, not something to route around in the session.
abstract final class LevelPhaseTransitions {
  /// Phases each phase may move to.
  ///
  /// Notable absences, all intentional:
  /// - `ready` only starts playing; nothing can end a level before a wave runs.
  /// - `waveTransition` cannot end the level: it is only entered with a cleared
  ///   field, so there is nothing left that could win or lose it.
  /// - `victory` and `defeat` are terminal.
  static const Map<LevelPhase, Set<LevelPhase>> _allowed = {
    LevelPhase.ready: {LevelPhase.playing},
    LevelPhase.playing: {
      LevelPhase.waveTransition,
      LevelPhase.victory,
      LevelPhase.defeat,
    },
    LevelPhase.waveTransition: {LevelPhase.playing},
    LevelPhase.victory: {},
    LevelPhase.defeat: {},
  };

  /// Whether [to] is a legal next phase from [from].
  ///
  /// A phase may never transition to itself; repeating a phase is a no-op, not
  /// an edge, which keeps the table honest about real changes.
  static bool isLegal(LevelPhase from, LevelPhase to) {
    return _allowed[from]?.contains(to) ?? false;
  }

  /// Phases reachable from [phase]; empty for terminal phases.
  static Set<LevelPhase> nextFrom(LevelPhase phase) =>
      _allowed[phase] ?? const {};

  /// Whether [phase] ends the attempt.
  static bool isTerminal(LevelPhase phase) {
    return phase == LevelPhase.victory || phase == LevelPhase.defeat;
  }
}
