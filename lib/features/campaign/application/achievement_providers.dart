import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_tower_defense/features/campaign/application/campaign_providers.dart';
import 'package:up_tower_defense/features/campaign/domain/achievement.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_definition.dart';
import 'package:up_tower_defense/features/gameplay/application/daily_providers.dart';
import 'package:up_tower_defense/features/gameplay/application/endless_providers.dart';
import 'package:up_tower_defense/features/save/application/save_providers.dart';

/// Achievements the player has earned (D67).
///
/// Seeded from the save loaded at bootstrap, so a relaunch shows exactly what the
/// last session stored; the progress screen reads this provider and nothing else
/// counts or computes achievements on its own.
final NotifierProvider<AchievementsNotifier, Set<Achievement>>
achievementsProvider = NotifierProvider<AchievementsNotifier, Set<Achievement>>(
  AchievementsNotifier.new,
);

/// Owns the earned set, re-derives it from stored facts and persists what is new.
///
/// [refresh] is called from the one path that records a result — the gameplay
/// screen's outcome handler — and once when the progress screen opens, which
/// backfills a save written before achievements existed. Only ids missing from
/// the current set are added and written, so a restart, a replay or two calls in
/// the same frame cannot double-award.
class AchievementsNotifier extends Notifier<Set<Achievement>> {
  @override
  Set<Achievement> build() => ref.watch(initialSaveProvider).achievements;

  /// Re-derives the earned set and stores anything new.
  ///
  /// Reads the campaign's future because the region and campaign goals need the
  /// level order; if it cannot load, nothing is awarded and the next call tries
  /// again — an achievement is never guessed from a partial campaign.
  Future<void> refresh() async {
    final CampaignDefinition campaign;
    try {
      campaign = await ref.read(campaignProvider.future);
    } on Object catch (error) {
      debugPrint('Achievements skipped, campaign unavailable: $error');
      return;
    }

    try {
      final earned = AchievementEvaluator.evaluate(
        campaign: campaign,
        progress: ref.read(campaignProgressProvider),
        endlessBest: ref.read(endlessBestProvider),
        dailyResults: ref.read(dailyResultsProvider),
      );
      final added = earned.difference(state);
      if (added.isEmpty) {
        return;
      }
      state = Set<Achievement>.unmodifiable({...state, ...added});
      unawaited(ref.read(saveRepositoryProvider).saveAchievements(state));
    } on Object catch (error) {
      // A provider read after the screen closed, or a failed write: the session
      // keeps the set it has. Losing an achievement costs one line on a screen;
      // throwing here would interrupt the result that earned it.
      debugPrint('Achievements could not be evaluated: $error');
    }
  }
}

/// The earned set as a readable list, for the progress screen.
final Provider<AchievementProgress> achievementProgressProvider =
    Provider<AchievementProgress>(
      (ref) => AchievementProgress(ref.watch(achievementsProvider)),
    );
