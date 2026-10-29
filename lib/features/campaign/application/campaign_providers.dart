import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_tower_defense/features/campaign/data/campaign_repository.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_definition.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_progress.dart';
import 'package:up_tower_defense/features/gameplay/data/content_catalog.dart';
import 'package:up_tower_defense/features/save/application/save_providers.dart';

/// Loads the authored campaign.
final Provider<CampaignRepository> campaignRepositoryProvider =
    Provider<CampaignRepository>((ref) => CampaignRepository());

/// The campaign: regions and level order.
///
/// Loaded once per app session; the level picker and the "Play" entry point both
/// read it, so they can never disagree about what the next level is.
final FutureProvider<CampaignDefinition> campaignProvider =
    FutureProvider<CampaignDefinition>((ref) {
      return ref
          .watch(campaignRepositoryProvider)
          .load(ContentCatalog.campaign);
    });

/// What the player has achieved so far.
///
/// Seeded from the save loaded at bootstrap, so a relaunch picks up exactly
/// what the last session stored; the unlock rule and the picker read this one
/// provider either way.
final NotifierProvider<CampaignProgressNotifier, CampaignProgress>
campaignProgressProvider =
    NotifierProvider<CampaignProgressNotifier, CampaignProgress>(
      CampaignProgressNotifier.new,
    );

/// Owns campaign progress, applies results and persists each change.
class CampaignProgressNotifier extends Notifier<CampaignProgress> {
  @override
  CampaignProgress build() => ref.watch(initialSaveProvider).progress;

  /// Records [result], keeping the better of it and any earlier run.
  ///
  /// A worse replay leaves the state untouched, so listeners are not notified
  /// for a result that changes nothing — and nothing is written, which is what
  /// keeps saves off the frame loop.
  void record(LevelResult result) {
    final next = state.record(result);
    if (identical(next, state)) {
      return;
    }
    state = next;
    _persist();
  }

  /// Forgets every recorded result, reopening the whole campaign.
  ///
  /// Called only from the confirmed reset on the settings screen; preferences
  /// are a separate half of the save and are deliberately untouched.
  void reset() {
    if (state.results.isEmpty) {
      return;
    }
    state = const CampaignProgress.empty();
    _persist();
  }

  /// Writes the new state through the save repository.
  ///
  /// A failed write is logged rather than surfaced: progress that could not be
  /// stored must still be playable for the rest of the session.
  void _persist() {
    try {
      unawaited(
        ref.read(saveRepositoryProvider).saveProgress(state),
      );
    } on Object catch (error) {
      debugPrint('Failed to save campaign progress: $error');
    }
  }
}
