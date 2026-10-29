import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:up_tower_defense/app/routes.dart';
import 'package:up_tower_defense/features/campaign/application/campaign_providers.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_definition.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_progress.dart';
import 'package:up_tower_defense/features/campaign/domain/level_rating.dart';
import 'package:up_tower_defense/features/campaign/presentation/campaign_summary.dart';
import 'package:up_tower_defense/shared/layout/menu_layout.dart';

/// The campaign picker.
///
/// Shows the campaign in order, five levels per page, with each level's best
/// result, and locks the levels the player has not reached. The lock state
/// comes from `CampaignProgress.isUnlocked`, the same rule the validator and
/// the "Play" entry point use, so the picker cannot offer a level the game
/// would refuse.
class LevelSelectScreen extends ConsumerWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaign = ref.watch(campaignProvider);
    final progress = ref.watch(campaignProgressProvider);

    return MenuLayout(
      title: 'Campaign',
      children: [
        campaign.when(
          data: (definition) => _CampaignBody(
            campaign: definition,
            progress: progress,
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => _CampaignError(error: error),
        ),
      ],
    );
  }
}

/// Regions, levels and the campaign totals, five levels at a time.
///
/// The page split follows campaign order, so it is also unlock order: a region
/// can span two pages, and every page keeps its rows in the order they open.
/// Paging keeps the picker to a handful of taps instead of a long scroll on a
/// phone, and the totals above it always count the whole campaign.
class _CampaignBody extends StatefulWidget {
  const _CampaignBody({required this.campaign, required this.progress});

  /// How many level rows one page holds.
  static const int levelsPerPage = 5;

  final CampaignDefinition campaign;
  final CampaignProgress progress;

  @override
  State<_CampaignBody> createState() => _CampaignBodyState();
}

class _CampaignBodyState extends State<_CampaignBody> {
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = _pageForProgress();
  }

  /// Opens on the page holding the first unfinished level, which is the one the
  /// player is about to play; a fully cleared campaign opens on its last page
  /// so the levels just beaten are the ones in view.
  int _pageForProgress() {
    final campaign = widget.campaign;
    final pageCount = math.max(
      1,
      (campaign.levelCount / _CampaignBody.levelsPerPage).ceil(),
    );
    final nextIndex = campaign.levelIds.indexWhere(
      (id) => !widget.progress.isCompleted(id),
    );
    if (nextIndex < 0) {
      return pageCount - 1;
    }
    return math.min(nextIndex ~/ _CampaignBody.levelsPerPage, pageCount - 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final campaign = widget.campaign;
    final progress = widget.progress;
    final levelCount = campaign.levelCount;
    final pageCount = math.max(
      1,
      (levelCount / _CampaignBody.levelsPerPage).ceil(),
    );
    final page = _page.clamp(0, pageCount - 1);
    final currentPage = _pageForProgress();
    final first = page * _CampaignBody.levelsPerPage;
    final last = math.min(first + _CampaignBody.levelsPerPage, levelCount);

    // The page's levels, grouped into the regions they belong to. Consecutive
    // levels of one region share a section, so a region that ends mid-page
    // still gets its own header and count.
    final sections = <({CampaignRegion region, List<CampaignLevel> levels})>[];
    for (var index = first; index < last; index++) {
      final levelId = campaign.levelIdAt(index)!;
      final level = campaign.levelFor(levelId)!;
      final region = campaign.regionOf(levelId)!;
      if (sections.isNotEmpty && sections.last.region == region) {
        sections.last.levels.add(level);
      } else {
        sections.add((region: region, levels: [level]));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CampaignSummary(),
        if (pageCount > 1) ...[
          const SizedBox(height: 8),
          _PageControls(
            page: page,
            pageCount: pageCount,
            firstLevel: first + 1,
            lastLevel: last,
            levelCount: levelCount,
            onPrevious: () => setState(() => _page = page - 1),
            onNext: () => setState(() => _page = page + 1),
            // Only offered once the player has browsed away from the page the
            // game is actually on; on that page it would do nothing.
            onJumpToCurrent: page == currentPage
                ? null
                : () => setState(() => _page = currentPage),
          ),
        ],
        const SizedBox(height: 16),
        for (final section in sections) ...[
          _RegionSection(
            campaign: campaign,
            progress: progress,
            region: section.region,
            levels: section.levels,
          ),
          const SizedBox(height: 16),
        ],
        Text(
          'Progress is saved on this device.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Page navigation shown only when the campaign has more than one page.
class _PageControls extends StatelessWidget {
  const _PageControls({
    required this.page,
    required this.pageCount,
    required this.firstLevel,
    required this.lastLevel,
    required this.levelCount,
    required this.onPrevious,
    required this.onNext,
    this.onJumpToCurrent,
  });

  final int page;
  final int pageCount;
  final int firstLevel;
  final int lastLevel;
  final int levelCount;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// Returns to the page holding the next unfinished level; null on that page.
  final VoidCallback? onJumpToCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        IconButton(
          onPressed: page > 0 ? onPrevious : null,
          tooltip: 'Previous page',
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            'Page ${page + 1} of $pageCount · '
            'Levels $firstLevel–$lastLevel of $levelCount',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        IconButton(
          onPressed: page < pageCount - 1 ? onNext : null,
          tooltip: 'Next page',
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        if (onJumpToCurrent case final jump?)
          IconButton(
            onPressed: jump,
            tooltip: 'Jump to current level',
            icon: const Icon(Icons.flag_rounded),
          ),
      ],
    );
  }
}

/// One region header plus the level rows this page shows from it.
///
/// [levels] is the page's slice; the header still counts the whole region, so
/// a region split across two pages does not report a smaller total.
class _RegionSection extends StatelessWidget {
  const _RegionSection({
    required this.campaign,
    required this.progress,
    required this.region,
    required this.levels,
  });

  final CampaignDefinition campaign;
  final CampaignProgress progress;
  final CampaignRegion region;
  final List<CampaignLevel> levels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cleared = region.levels
        .where((level) => progress.isCompleted(level.id))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  region.displayName,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                '$cleared/${region.levels.length}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < levels.length; index++)
                _LevelTile(
                  campaign: campaign,
                  progress: progress,
                  level: levels[index],
                  showDivider: index > 0,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One level row: number, name, best result, and whether it is open.
class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.campaign,
    required this.progress,
    required this.level,
    required this.showDivider,
  });

  final CampaignDefinition campaign;
  final CampaignProgress progress;
  final CampaignLevel level;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlocked = progress.isUnlocked(campaign, level.id);
    final stars = progress.starsFor(level.id);
    final ordinal = campaign.ordinalOf(level.id);
    // A locked row names the level that opens it: the previous level in the
    // flattened order, which is the only thing that can (D33).
    final previousId = campaign.levelIdAt(campaign.indexOf(level.id) - 1);
    final previousName = previousId == null
        ? null
        : campaign.displayNameOf(previousId);
    final lockReason = previousName == null
        ? 'Clear the previous level to unlock'
        : 'Clear $previousName to unlock';

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: unlocked
                ? Text(
                    '$ordinal',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  )
                : Icon(
                    Icons.lock_outline_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  level.displayName,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                if (unlocked)
                  _StarRow(stars: stars)
                else
                  Text(
                    lockReason,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (unlocked)
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
        ],
      ),
    );

    return Column(
      children: [
        if (showDivider) const Divider(height: 1),
        Semantics(
          button: unlocked,
          enabled: unlocked,
          label: unlocked
              ? 'Play level $ordinal, ${level.displayName}, '
                    '$stars of ${LevelRating.maxStars} stars'
              : 'Level $ordinal, ${level.displayName}, locked'
                    '${previousName == null ? '' : ', opens after $previousName'}',
          child: unlocked
              ? InkWell(
                  onTap: () => context.go(AppRoutes.gameplayFor(level.id)),
                  child: content,
                )
              : Opacity(opacity: 0.6, child: content),
        ),
      ],
    );
  }
}

/// Three small stars, filled to the best result.
class _StarRow extends StatelessWidget {
  const _StarRow({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < LevelRating.maxStars; index++)
          Icon(
            index < stars ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 16,
            color: index < stars
                ? const Color(0xFFE8C15C)
                : theme.colorScheme.onSurfaceVariant,
          ),
      ],
    );
  }
}

/// Shown when the campaign file cannot be loaded or fails validation.
class _CampaignError extends StatelessWidget {
  const _CampaignError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Campaign unavailable', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'The campaign content could not be loaded. This is a build '
              'problem, not a missing download.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
