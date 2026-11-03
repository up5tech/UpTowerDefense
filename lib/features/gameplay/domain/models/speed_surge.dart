import 'package:meta/meta.dart';

/// The one-shot speed burst a boss gains when it is badly hurt (D69).
///
/// Authored only on boss definitions, so an ordinary enemy can never grow one by
/// accident; the runtime bookkeeping (whether it has fired, how long is left)
/// lives in `EnemyState`, the same split every other definition/instance pair
/// follows.
@immutable
class SpeedSurge {
  const SpeedSurge({
    required this.healthRatio,
    required this.multiplier,
    required this.durationSeconds,
  });

  /// Fraction of maximum health that arms the surge, in `(0, 1]`.
  ///
  /// The surge fires when health *first falls to or below* this share, so a
  /// burst on the last hit of a fight never happens: the boss has to survive the
  /// threshold to be seen using it.
  final double healthRatio;

  /// Speed multiplier while the surge lasts; strictly greater than `1`, because
  /// a surge that does not speed anything up is a content mistake.
  final double multiplier;

  /// How long the burst lasts, in simulation seconds.
  final double durationSeconds;

  /// Whether [health] of [maxHealth] has reached the arming threshold.
  bool armsAt(double health, double maxHealth) {
    return health > 0 && health <= maxHealth * healthRatio;
  }

  @override
  String toString() =>
      'SpeedSurge(x$multiplier for ${durationSeconds}s at '
      '${(healthRatio * 100).toStringAsFixed(0)}% health)';
}
