import 'package:meta/meta.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_objective.dart';

/// Where one goal stands right now.
///
/// Three states rather than a bool because a goal can still be won: the HUD has
/// to show "2/2" for two achieved goals and a crossed line for one that is
/// already lost, and a goal that is merely still possible must not look lost.
enum LevelObjectiveState {
  /// Still possible, not yet earned.
  pending,

  /// Satisfied by the run so far.
  met,

  /// Cannot be earned by this run any more.
  failed,
}

/// One authored goal plus the state this run gives it.
///
/// Immutable and comparable, so the HUD snapshot can publish the list without
/// rebuilding Flutter every frame: two frames with the same states are equal.
@immutable
class LevelObjectiveStatus {
  const LevelObjectiveStatus({required this.objective, required this.state});

  /// The goal being judged; its [LevelObjective.description] is the sentence a
  /// player reads, so the text can never disagree with the rule.
  final LevelObjective objective;

  /// Where the goal stands.
  final LevelObjectiveState state;

  /// Whether the run satisfies this goal.
  bool get isMet => state == LevelObjectiveState.met;

  /// Whether this goal is already out of reach.
  bool get hasFailed => state == LevelObjectiveState.failed;

  @override
  bool operator ==(Object other) {
    return other is LevelObjectiveStatus &&
        other.objective.kind == objective.kind &&
        other.objective.value == objective.value &&
        other.state == state;
  }

  @override
  int get hashCode => Object.hash(objective.kind, objective.value, state);

  @override
  String toString() =>
      'LevelObjectiveStatus(${objective.kind.wireName}, $state)';
}

/// Judges a level's goals from the facts the simulation already holds (D68).
///
/// Pure functions over a snapshot of the run instead of a stateful tracker: the
/// session owns the facts (leaks, peak towers, elapsed, core health) and this
/// derives the answer, so a goal cannot be met in one reader and failed in
/// another. A goal that can no longer be earned is reported as failed the moment
/// it is lost — a player must never discover it on the result screen.
abstract final class LevelObjectives {
  /// The status of every goal in [objectives], in authored order.
  static List<LevelObjectiveStatus> evaluate({
    required List<LevelObjective> objectives,
    required int leaks,
    required int peakTowerCount,
    required double elapsedSeconds,
    required int coreHealth,
    required bool victorious,
  }) {
    return [
      for (final objective in objectives)
        LevelObjectiveStatus(
          objective: objective,
          state: _stateOf(
            objective,
            leaks: leaks,
            peakTowerCount: peakTowerCount,
            elapsedSeconds: elapsedSeconds,
            coreHealth: coreHealth,
            victorious: victorious,
          ),
        ),
    ];
  }

  /// How many of [statuses] are met.
  static int metCount(Iterable<LevelObjectiveStatus> statuses) =>
      statuses.where((status) => status.isMet).length;

  static LevelObjectiveState _stateOf(
    LevelObjective objective, {
    required int leaks,
    required int peakTowerCount,
    required double elapsedSeconds,
    required int coreHealth,
    required bool victorious,
  }) {
    final value = objective.value;
    switch (objective.kind) {
      case LevelObjectiveKind.noLeaks:
        // A leak is permanent: the goal is lost the instant one gets through,
        // not when the level ends.
        return leaks == 0
            ? LevelObjectiveState.met
            : LevelObjectiveState.failed;
      case LevelObjectiveKind.maxTowers:
        // The peak, never the current count: selling a tower must not restore a
        // goal the build already spent, or build–sell–build would cheat it.
        return peakTowerCount <= (value ?? 0)
            ? LevelObjectiveState.met
            : LevelObjectiveState.failed;
      case LevelObjectiveKind.deadlineSeconds:
        final limit = (value ?? 0).toDouble();
        if (elapsedSeconds > limit) {
          return LevelObjectiveState.failed;
        }
        if (victorious) {
          return LevelObjectiveState.met;
        }
        return LevelObjectiveState.pending;
      case LevelObjectiveKind.coreAbove:
        final threshold = value ?? 0;
        if (coreHealth < threshold) {
          return LevelObjectiveState.failed;
        }
        if (victorious) {
          return LevelObjectiveState.met;
        }
        return LevelObjectiveState.pending;
    }
  }
}
