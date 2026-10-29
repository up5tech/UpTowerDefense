import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_tower_defense/features/campaign/application/campaign_providers.dart';
import 'package:up_tower_defense/features/campaign/domain/level_rating.dart';

/// One line of campaign progress: "3 of 10 levels cleared · 5 of 30 stars".
///
/// Shared by the level picker and the main menu so the two screens can never
/// count differently — they read the same campaign and the same progress, and
/// only this widget knows how to phrase it. While the campaign is still loading
/// it renders nothing, so a screen never shows a total it cannot back up.
class CampaignSummary extends ConsumerWidget {
  const CampaignSummary({
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
  });

  /// Style override; defaults to the picker's muted title style.
  final TextStyle? style;

  final TextAlign textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaign = ref.watch(campaignProvider);
    final progress = ref.watch(campaignProgressProvider);

    return campaign.when(
      data: (definition) {
        final cleared = definition.levelIds.where(progress.isCompleted).length;
        final stars = progress.totalStars(definition.levelIds);
        final maxStars = definition.levelCount * LevelRating.maxStars;
        return Text(
          '$cleared of ${definition.levelCount} levels cleared · '
          '$stars of $maxStars stars',
          textAlign: textAlign,
          style:
              style ??
              Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}
