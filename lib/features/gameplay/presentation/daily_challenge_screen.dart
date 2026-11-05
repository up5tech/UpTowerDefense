import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:up_tower_defense/app/routes.dart';
import 'package:up_tower_defense/features/gameplay/application/daily_providers.dart';
import 'package:up_tower_defense/features/gameplay/presentation/gameplay_screen.dart';

/// Resolves today's seeded level and hosts it as a one-off run (D66, D70).
///
/// The selection is resolved once, here, and handed down as a fixed level id and
/// date: a run that starts before local midnight keeps the seed it began with
/// even if the clock rolls over while it plays. The screen is keyed by the date
/// so a new day always starts a fresh attempt.
class DailyChallengeScreen extends ConsumerWidget {
  const DailyChallengeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(dailySelectionProvider);

    return selection.when(
      data: (choice) => GameplayScreen(
        key: ValueKey('daily-${choice.dateKey}'),
        levelId: choice.levelId,
        daily: true,
        dailyDateKey: choice.dateKey,
      ),
      loading: () => const _DailyStatus(
        title: "Picking today's challenge",
        body: CircularProgressIndicator(),
        showLeave: true,
      ),
      error: (error, stackTrace) => _DailyStatus(
        title: 'Daily challenge unavailable',
        body: Text(
          '$error',
          textAlign: TextAlign.center,
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
        ),
        showLeave: true,
      ),
    );
  }
}

/// Shared non-playable frame for the daily screen's loading and error states.
class _DailyStatus extends StatelessWidget {
  const _DailyStatus({
    required this.title,
    required this.body,
    required this.showLeave,
  });

  final String title;
  final Widget body;
  final bool showLeave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showLeave)
                IconButton.filledTonal(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go(AppRoutes.mainMenu),
                  tooltip: 'Back to menu',
                  icon: const Icon(Icons.arrow_back),
                ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      body,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
