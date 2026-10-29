import 'package:meta/meta.dart';

/// The closed set of goals a level can ask for beyond finishing it (D68).
///
/// A closed enum rather than free-text labels: the sentence the player reads is
/// derived from the kind and its value, so the rule and its explanation can
/// never drift apart, and the validator can check every goal a shipped level
/// declares instead of trusting prose.
enum LevelObjectiveKind {
  /// Finish without letting a single enemy reach the core.
  noLeaks('noLeaks'),

  /// Never have more than [LevelObjective.value] towers standing at once.
  maxTowers('maxTowers'),

  /// Finish within [LevelObjective.value] seconds of play.
  deadlineSeconds('deadlineSeconds'),

  /// Finish with at least [LevelObjective.value] core health left.
  coreAbove('coreAbove');

  const LevelObjectiveKind(this.wireName);

  /// Name authored in level JSON; the Dart enum name stays an implementation
  /// detail, so a renamed constant never silently rewrites saved content.
  final String wireName;

  /// The kind authored as [name], or null when a level asks for an unknown
  /// goal. Null is reported by the decoder, not defaulted away.
  static LevelObjectiveKind? fromWireName(String name) {
    for (final kind in values) {
      if (kind.wireName == name) {
        return kind;
      }
    }
    return null;
  }
}

/// One goal a level offers beside winning it (D68).
///
/// Each kind carries its own constructor so a value can never be attached to
/// the wrong goal, and [value] is always an integer: gold and health in this
/// game are integers, and seconds are authored in whole seconds so the derived
/// sentence reads the same on every device.
@immutable
class LevelObjective {
  /// Finish the level without a leak.
  const LevelObjective.noLeaks()
    : kind = LevelObjectiveKind.noLeaks,
      value = null;

  /// Never exceed [towers] towers standing at once, counting the peak.
  ///
  /// Thresholds are checked by `LevelValidator`, not asserted here: a bad
  /// authored value has to surface as a content report through the same path
  /// as every other content mistake, never as an assertion in a debug build.
  const LevelObjective.maxTowers(int towers)
    : kind = LevelObjectiveKind.maxTowers,
      value = towers;

  /// Win within [seconds] seconds of play, transitions and pauses excluded.
  const LevelObjective.deadlineSeconds(int seconds)
    : kind = LevelObjectiveKind.deadlineSeconds,
      value = seconds;

  /// Finish with at least [health] core health left.
  const LevelObjective.coreAbove(int health)
    : kind = LevelObjectiveKind.coreAbove,
      value = health;

  /// Which goal this is.
  final LevelObjectiveKind kind;

  /// The goal's threshold, or null for [LevelObjectiveKind.noLeaks].
  final int? value;

  /// The one-sentence goal, derived so it cannot contradict the rule.
  String get description {
    final amount = value;
    return switch (kind) {
      LevelObjectiveKind.noLeaks => 'Take no leaks',
      LevelObjectiveKind.maxTowers =>
        'Never have more than $amount towers standing',
      LevelObjectiveKind.deadlineSeconds => 'Finish within $amount seconds',
      LevelObjectiveKind.coreAbove => 'Keep at least $amount core health',
    };
  }

  @override
  String toString() => 'LevelObjective(${kind.wireName}, value: $value)';
}
