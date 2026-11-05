import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_tower_defense/features/campaign/application/achievement_providers.dart';
import 'package:up_tower_defense/features/campaign/application/campaign_providers.dart';
import 'package:up_tower_defense/features/campaign/domain/achievement.dart';
import 'package:up_tower_defense/features/campaign/domain/level_rating.dart';
import 'package:up_tower_defense/features/campaign/presentation/campaign_summary.dart';
import 'package:up_tower_defense/features/gameplay/application/daily_providers.dart';
import 'package:up_tower_defense/features/gameplay/application/endless_providers.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/difficulty.dart';
import 'package:up_tower_defense/shared/layout/menu_layout.dart';

/// One screen for every long-term goal (V2-4).
///
/// It reads the same providers the menu and picker use — campaign progress,
/// endless best, daily records, achievements — so two screens can never count
/// differently (D44). Nothing here recomputes an achievement: the list is what
/// the save holds, and the one backfill call in the state's initState exists so
/// a save
/// written before achievements shipped still shows what those facts earn.
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  @override
  void initState() {
    super.initState();
    // After the first frame, not during build: this can write the save, and a
    // build must never do that.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(achievementsProvider.notifier).refresh());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final campaign = ref.watch(campaignProvider);
    final progress = ref.watch(campaignProgressProvider);
    final endlessBest = ref.watch(endlessBestProvider);
    final dailies = ref.watch(dailyResultsProvider);
    final achievementProgress = ref.watch(achievementProgressProvider);
    final dailySelection = ref
        .watch(dailySelectionProvider)
        .whenOrNull(data: (value) => value);
    final definition = campaign.whenOrNull(data: (value) => value);

    final todayName = dailySelection == null
        ? null
        : definition?.displayNameOf(dailySelection.levelId);
    final todayBest = dailySelection == null
        ? null
        : dailies[dailySelection.dateKey];

    return MenuLayout(
      title: 'Progress',
      children: [
        const CampaignSummary(),
        if (definition != null && progress.isHardAvailable(definition)) ...[
          const SizedBox(height: 4),
          const CampaignSummary(difficulty: Difficulty.hard),
        ],
        const SizedBox(height: 20),
        _ProgressCard(
          rows: [
            (
              icon: Icons.waves_rounded,
              label: 'Endless best',
              value: endlessBest == 0 ? 'Not played yet' : '$endlessBest waves',
            ),
            (
              icon: Icons.today_rounded,
              label: 'Daily best',
              value: switch ((todayName, todayBest)) {
                (null, _) => 'No challenge today',
                (final name?, null) => '$name — not finished yet',
                (final name?, final best?) =>
                  '$name — ${best.stars} of ${LevelRating.maxStars} stars',
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text('Achievements', style: theme.textTheme.titleMedium),
            ),
            Text(
              '${achievementProgress.count} of ${achievementProgress.total}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final entry
                  in achievementProgress.ordered.asMap().entries) ...[
                if (entry.key > 0) const Divider(height: 1),
                _AchievementRow(
                  achievement: entry.value,
                  earned: achievementProgress.earned.contains(entry.value),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Campaign achievements count Normal results only; Hard is a second '
          'pass.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Two-line facts card: one icon, a label and a value per row.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.rows});

  final List<({IconData icon, String label, String value})> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      row.icon,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(row.label, style: theme.textTheme.bodyMedium),
                    ),
                    Text(row.value, style: theme.textTheme.titleSmall),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One achievement: what it asks for, and whether it is earned.
///
/// Locked rows keep their description visible on purpose — an achievement a
/// player cannot read is a goal they cannot chase.
class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.achievement, required this.earned});

  final Achievement achievement;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = earned
        ? const Color(0xFFE8C15C)
        : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      label: '${achievement.label}, ${earned ? 'earned' : 'locked'}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              earned ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
              size: 22,
              color: tint,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    achievement.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: earned ? null : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    achievement.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              earned ? 'Earned' : 'Locked',
              style: theme.textTheme.labelMedium?.copyWith(color: tint),
            ),
          ],
        ),
      ),
    );
  }
}
