import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_tower_defense/features/campaign/application/campaign_providers.dart';
import 'package:up_tower_defense/features/gameplay/domain/daily_challenge.dart';
import 'package:up_tower_defense/features/save/application/save_providers.dart';

/// The device's local date, read once per selection.
///
/// The only wall-clock read in the app, and it lives here in presentation so the
/// domain never sees one (D66). Tests override it to pin a date.
final Provider<DateTime> todayProvider = Provider<DateTime>(
  (ref) => DateTime.now(),
);

/// Today's date as the integer `yyyyMMdd` seed.
final Provider<int> dailyDateKeyProvider = Provider<int>(
  (ref) => DailyChallenge.dateKeyOf(ref.watch(todayProvider)),
);

/// Which campaign level today's seed selects, with the date it was selected for.
///
/// The date travels with the id so a run that starts before local midnight
/// records under the day it began with, even if the clock has moved on by the
/// time it finishes (D66).
final FutureProvider<({int dateKey, String levelId})> dailySelectionProvider =
    FutureProvider<({int dateKey, String levelId})>((ref) async {
      final campaign = await ref.watch(campaignProvider.future);
      final dateKey = ref.watch(dailyDateKeyProvider);
      return (
        dateKey: dateKey,
        levelId: DailyChallenge.selectLevelId(
          seed: dateKey,
          levelIds: campaign.levelIds,
        ),
      );
    });

/// The best daily run per date.
///
/// Persisted since save v5 beside achievements: a daily best that vanished on
/// relaunch would make the mode pointless. Nothing here touches campaign
/// progress — that separation is the rule these records exist for (D70).
final NotifierProvider<DailyResultsNotifier, Map<int, DailyResult>>
dailyResultsProvider =
    NotifierProvider<DailyResultsNotifier, Map<int, DailyResult>>(
      DailyResultsNotifier.new,
    );

/// Owns the daily records and keeps the best run for each date.
class DailyResultsNotifier extends Notifier<Map<int, DailyResult>> {
  @override
  Map<int, DailyResult> build() => ref.watch(initialSaveProvider).dailyResults;

  /// Records [result] when it beats the stored run for its date.
  ///
  /// A worse run changes nothing, so a listener is not notified for a replay
  /// that did not improve the day — the same rule campaign results follow — and
  /// nothing is written.
  void record(DailyResult result) {
    final previous = state[result.dateKey];
    if (previous != null && !result.isBetterThan(previous)) {
      return;
    }
    state = Map<int, DailyResult>.unmodifiable({
      ...state,
      result.dateKey: result,
    });
    _persist();
  }

  /// Writes the records through the save repository.
  ///
  /// A failed write is logged rather than surfaced: a daily that could not be
  /// stored must still count for the rest of the session.
  void _persist() {
    try {
      unawaited(ref.read(saveRepositoryProvider).saveDailyResults(state));
    } on Object catch (error) {
      debugPrint('Failed to save daily results: $error');
    }
  }
}
