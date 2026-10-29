import 'package:meta/meta.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_progress.dart';
import 'package:up_tower_defense/features/settings/domain/game_settings.dart';

/// Everything the game persists between launches.
///
/// One document instead of two independent blobs: a single schema version, one
/// read validation and one backup, so campaign progress and preferences can
/// never be stored as different generations of the format (D41).
@immutable
class SaveDocument {
  const SaveDocument({
    required this.progress,
    required this.settings,
    this.endlessBest = 0,
  });

  /// A clean install: nothing earned, default preferences.
  const SaveDocument.empty()
    : progress = const CampaignProgress.empty(),
      settings = GameSettings.defaults,
      endlessBest = 0;

  /// Unlocks and best results, keyed by level id.
  final CampaignProgress progress;

  /// Player preferences, saved beside progress rather than beside themselves.
  final GameSettings settings;

  /// Waves cleared in the player's best endless run; 0 before the first.
  ///
  /// Lives in the same document as the campaign so one schema, one read
  /// validation and one backup cover everything the game persists (D62).
  final int endlessBest;

  /// A copy with one half replaced and the other carried over.
  ///
  /// This is what lets progress and settings save independently: each writer
  /// supplies only its own half and never has to read the other side back.
  SaveDocument copyWith({
    CampaignProgress? progress,
    GameSettings? settings,
    int? endlessBest,
  }) {
    return SaveDocument(
      progress: progress ?? this.progress,
      settings: settings ?? this.settings,
      endlessBest: endlessBest ?? this.endlessBest,
    );
  }

  @override
  String toString() =>
      'SaveDocument(${progress.results.length} results, '
      'endless best $endlessBest, $settings)';
}
