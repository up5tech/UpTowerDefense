import 'package:meta/meta.dart';
import 'package:up_tower_defense/features/campaign/domain/achievement.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_progress.dart';
import 'package:up_tower_defense/features/gameplay/domain/daily_challenge.dart';
import 'package:up_tower_defense/features/settings/domain/game_settings.dart';

/// Everything the game persists between launches.
///
/// One document instead of several independent blobs: a single schema version,
/// one read validation and one backup, so campaign progress, preferences,
/// achievements and dailies can never be stored as different generations of the
/// format (D41).
@immutable
class SaveDocument {
  const SaveDocument({
    required this.progress,
    required this.settings,
    this.endlessBest = 0,
    this.achievements = const {},
    this.dailyResults = const {},
  });

  /// A clean install: nothing earned, default preferences.
  const SaveDocument.empty()
    : progress = const CampaignProgress.empty(),
      settings = GameSettings.defaults,
      endlessBest = 0,
      achievements = const {},
      dailyResults = const {};

  /// Unlocks and best results, keyed by level id and difficulty.
  final CampaignProgress progress;

  /// Player preferences, saved beside progress rather than beside themselves.
  final GameSettings settings;

  /// Waves cleared in the player's best endless run; 0 before the first.
  ///
  /// Lives in the same document as the campaign so one schema, one read
  /// validation and one backup cover everything the game persists (D62).
  final int endlessBest;

  /// Achievement ids the player has earned (D67, save v5).
  ///
  /// Ids only: the title and the rule behind each one are code, so a save can
  /// never carry prose that disagrees with the achievement it names.
  final Set<Achievement> achievements;

  /// The best daily run per `yyyyMMdd` date (D66, save v5).
  ///
  /// Keyed by the date rather than by level: a daily result is a fact about a
  /// day, and it must never be mistaken for campaign progress (D70).
  final Map<int, DailyResult> dailyResults;

  /// A copy with one half replaced and the other carried over.
  ///
  /// This is what lets progress, settings, achievements and dailies save
  /// independently: each writer supplies only its own part and never has to read
  /// the rest back.
  SaveDocument copyWith({
    CampaignProgress? progress,
    GameSettings? settings,
    int? endlessBest,
    Set<Achievement>? achievements,
    Map<int, DailyResult>? dailyResults,
  }) {
    return SaveDocument(
      progress: progress ?? this.progress,
      settings: settings ?? this.settings,
      endlessBest: endlessBest ?? this.endlessBest,
      achievements: achievements ?? this.achievements,
      dailyResults: dailyResults ?? this.dailyResults,
    );
  }

  @override
  String toString() =>
      'SaveDocument(${progress.results.length} results, '
      'endless best $endlessBest, ${achievements.length} achievements, '
      '${dailyResults.length} dailies, $settings)';
}
