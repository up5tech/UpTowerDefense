import 'package:meta/meta.dart';

/// The deterministic, offline daily challenge selection (D66, D70).
///
/// The device's local calendar date is read in presentation and passed in as an
/// integer `yyyyMMdd`; this file never reads a clock. The selection is a pure
/// function of that integer and the campaign's ordered level list, so every
/// installed copy picks the same level on the same day without a server.
abstract final class DailyChallenge {
  /// State substituted for zero, so seed 0 still selects a level (D70).
  static const int zeroState = 0x6D2B79F5;

  /// 32-bit mask; xorshift32 is defined on unsigned 32-bit words.
  static const int _mask = 0xFFFFFFFF;

  /// The local date as `yyyyMMdd`, the seed a run is started with.
  ///
  /// Presentation calls this with the device's local date: the reset boundary is
  /// local midnight, which is the one rule a player can predict from their own
  /// calendar.
  static int dateKeyOf(DateTime localDate) =>
      localDate.year * 10000 + localDate.month * 100 + localDate.day;

  /// One step of xorshift32 (opcode 13, 17, 5), masked to 32 bits after every
  /// shift so the arithmetic stays unsigned on a 64-bit Dart int.
  static int nextSeed(int seed) {
    var x = seed == 0 ? zeroState : seed & _mask;
    x = (x ^ (x << 13)) & _mask;
    x = (x ^ (x >> 17)) & _mask;
    x = (x ^ (x << 5)) & _mask;
    return x;
  }

  /// The level id today's seed selects.
  ///
  /// The campaign's stable ordered list is the domain of the choice, so a level
  /// added to the end never reshuffles the days before it and no level needs its
  /// own daily variant.
  static String selectLevelId({
    required int seed,
    required List<String> levelIds,
  }) {
    if (levelIds.isEmpty) {
      throw ArgumentError.value(levelIds, 'levelIds', 'cannot be empty');
    }
    return levelIds[nextSeed(seed) % levelIds.length];
  }
}

/// One date's best daily run.
///
/// The record is keyed by the date it was played, never by the level: finishing
/// a daily must not touch campaign stars, results or unlocks (D70).
@immutable
class DailyResult {
  const DailyResult({
    required this.dateKey,
    required this.levelId,
    required this.stars,
    required this.coreHealth,
    required this.maxCoreHealth,
    required this.objectivesMet,
  });

  /// The `yyyyMMdd` this run belongs to.
  final int dateKey;

  /// The level the seed selected that day.
  final String levelId;

  /// Stars the run earned; 0 for a defeat.
  final int stars;

  final int coreHealth;
  final int maxCoreHealth;

  /// Goals the run met, so the daily screen can explain the stars.
  final int objectivesMet;

  /// Whether this run beats [other] on the same date.
  ///
  /// Stars then core health, the same rule campaign results use, so "best today"
  /// is a property of the data rather than of the screen that shows it.
  bool isBetterThan(DailyResult other) {
    if (stars != other.stars) {
      return stars > other.stars;
    }
    return coreHealth > other.coreHealth;
  }

  @override
  String toString() =>
      'DailyResult($dateKey, $levelId, $stars stars, '
      'core $coreHealth/$maxCoreHealth)';
}
