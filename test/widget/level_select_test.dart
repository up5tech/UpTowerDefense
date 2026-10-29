import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:up_tower_defense/core/constants/app_info.dart';
import 'package:up_tower_defense/features/campaign/application/campaign_providers.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_definition.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_progress.dart';
import 'package:up_tower_defense/features/gameplay/application/content_providers.dart';
import 'package:up_tower_defense/features/level_select/presentation/level_select_screen.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/pump_app.dart';
import '../helpers/pump_until.dart';
import '../helpers/save_overrides.dart';

/// Seven-level campaign: four levels in Region One, three in Region Two, so the
/// five-row page split lands inside the second region.
final CampaignDefinition _longCampaign = CampaignDefinition([
  CampaignRegion(
    id: 'region_one',
    displayName: 'Region One',
    levels: const [
      CampaignLevel(id: 'test_level', displayName: 'Test Meadow'),
      CampaignLevel(id: 'test_level_2', displayName: 'Second Meadow'),
      CampaignLevel(id: 'test_level_3', displayName: 'Third Meadow'),
      CampaignLevel(id: 'test_level_4', displayName: 'Fourth Meadow'),
    ],
  ),
  CampaignRegion(
    id: 'region_two',
    displayName: 'Region Two',
    levels: const [
      CampaignLevel(id: 'test_level_5', displayName: 'Fifth Meadow'),
      CampaignLevel(id: 'test_level_6', displayName: 'Sixth Meadow'),
      CampaignLevel(id: 'test_level_7', displayName: 'Seventh Meadow'),
    ],
  ),
]);

/// Progress preset for a picker that must open on a later page.
class _PresetProgressNotifier extends CampaignProgressNotifier {
  _PresetProgressNotifier(this.preset);

  final CampaignProgress preset;

  @override
  CampaignProgress build() => preset;
}

/// Pumps the picker on a small router whose gameplay route only prints the id,
/// so a test can prove navigation without building a whole level.
Future<ProviderContainer> pumpLevelSelect(
  WidgetTester tester, {
  CampaignDefinition? campaign,
  CampaignProgress? progress,
}) async {
  final router = GoRouter(
    initialLocation: '/levels',
    routes: [
      GoRoute(
        path: '/levels',
        builder: (context, state) => const LevelSelectScreen(),
      ),
      GoRoute(
        path: '/play/:levelId',
        builder: (context, state) =>
            Scaffold(body: Text('playing ${state.pathParameters['levelId']}')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        campaignProvider.overrideWith((ref) => campaign ?? testCampaign),
        if (progress != null)
          campaignProgressProvider.overrideWith(
            () => _PresetProgressNotifier(progress),
          ),
        levelBundleProvider.overrideWith(
          (ref, levelId) => bundleForLevel(levelId),
        ),
        isolatedSaveOverride(),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();

  return ProviderScope.containerOf(
    tester.element(find.byType(LevelSelectScreen)),
  );
}

/// The page button with [tooltip], so a test can assert its enabled state.
VoidCallback? _pageAction(WidgetTester tester, String tooltip) {
  return tester
      .widget<IconButton>(
        find.ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(IconButton),
        ),
      )
      .onPressed;
}

void _record(
  ProviderContainer container,
  String levelId, {
  int stars = 3,
  int coreHealth = 5,
}) {
  container
      .read(campaignProgressProvider.notifier)
      .record(
        LevelResult(
          levelId: levelId,
          stars: stars,
          coreHealth: coreHealth,
          maxCoreHealth: 5,
          wavesCleared: 2,
          totalWaves: 2,
        ),
      );
}

void main() {
  testWidgets('the picker lists every region and level', (tester) async {
    await pumpLevelSelect(tester);

    expect(find.text('Region One'), findsOneWidget);
    expect(find.text('Region Two'), findsOneWidget);
    for (final name in [
      'Test Meadow',
      'Second Meadow',
      'Third Meadow',
      'Fourth Meadow',
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('0 of 4 levels cleared · 0 of 12 stars'), findsOneWidget);
  });

  testWidgets('the picker shows five levels per page', (tester) async {
    await pumpLevelSelect(tester, campaign: _longCampaign);

    expect(find.text('Page 1 of 2 · Levels 1–5 of 7'), findsOneWidget);
    expect(find.text('Test Meadow'), findsOneWidget);
    expect(find.text('Fifth Meadow'), findsOneWidget);
    expect(find.text('Sixth Meadow'), findsNothing);
    // The split lands inside Region Two, so both headers are on page one.
    expect(find.text('Region One'), findsOneWidget);
    expect(find.text('Region Two'), findsOneWidget);
    // Previous is disabled on the first page.
    expect(_pageAction(tester, 'Previous page'), isNull);
    expect(_pageAction(tester, 'Next page'), isNotNull);
  });

  testWidgets('paging shows the remaining levels and hides page one', (
    tester,
  ) async {
    await pumpLevelSelect(tester, campaign: _longCampaign);

    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();

    expect(find.text('Page 2 of 2 · Levels 6–7 of 7'), findsOneWidget);
    expect(find.text('Fifth Meadow'), findsNothing);
    expect(find.text('Sixth Meadow'), findsOneWidget);
    expect(find.text('Seventh Meadow'), findsOneWidget);
    expect(find.text('Region One'), findsNothing);
    expect(find.text('Region Two'), findsOneWidget);
    expect(_pageAction(tester, 'Next page'), isNull);

    await tester.tap(find.byTooltip('Previous page'));
    await tester.pumpAndSettle();

    expect(find.text('Page 1 of 2 · Levels 1–5 of 7'), findsOneWidget);
    expect(find.text('Test Meadow'), findsOneWidget);
  });

  testWidgets('the picker opens on the page with the next unfinished level', (
    tester,
  ) async {
    // Levels 1-5 are cleared, so the next one to play is level 6 on page two.
    final progress = const CampaignProgress.empty().record(
      const LevelResult(
        levelId: 'test_level',
        stars: 3,
        coreHealth: 5,
        maxCoreHealth: 5,
        wavesCleared: 2,
        totalWaves: 2,
      ),
    );
    var preset = progress;
    for (final id in [
      'test_level_2',
      'test_level_3',
      'test_level_4',
      'test_level_5',
    ]) {
      preset = preset.record(
        LevelResult(
          levelId: id,
          stars: 3,
          coreHealth: 5,
          maxCoreHealth: 5,
          wavesCleared: 2,
          totalWaves: 2,
        ),
      );
    }

    await pumpLevelSelect(
      tester,
      campaign: _longCampaign,
      progress: preset,
    );

    expect(find.text('Page 2 of 2 · Levels 6–7 of 7'), findsOneWidget);
    expect(find.text('Sixth Meadow'), findsOneWidget);
    expect(find.text('Test Meadow'), findsNothing);
    // Already on the current page: nothing to jump back to.
    expect(find.byTooltip('Jump to current level'), findsNothing);

    await tester.tap(find.byTooltip('Previous page'));
    await tester.pumpAndSettle();

    expect(find.text('Page 1 of 2 · Levels 1–5 of 7'), findsOneWidget);
    expect(find.byTooltip('Jump to current level'), findsOneWidget);

    await tester.tap(find.byTooltip('Jump to current level'));
    await tester.pumpAndSettle();

    expect(find.text('Page 2 of 2 · Levels 6–7 of 7'), findsOneWidget);
    expect(find.byTooltip('Jump to current level'), findsNothing);
  });

  testWidgets('a cleared campaign opens on its last page', (tester) async {
    var preset = const CampaignProgress.empty();
    for (var index = 1; index <= 7; index++) {
      preset = preset.record(
        LevelResult(
          levelId: index == 1 ? 'test_level' : 'test_level_$index',
          stars: 3,
          coreHealth: 5,
          maxCoreHealth: 5,
          wavesCleared: 2,
          totalWaves: 2,
        ),
      );
    }

    await pumpLevelSelect(
      tester,
      campaign: _longCampaign,
      progress: preset,
    );

    expect(find.text('Page 2 of 2 · Levels 6–7 of 7'), findsOneWidget);
    expect(find.text('Seventh Meadow'), findsOneWidget);
  });

  testWidgets('a campaign that fits one page shows no pager', (tester) async {
    await pumpLevelSelect(tester);

    expect(find.byTooltip('Next page'), findsNothing);
    expect(find.byTooltip('Previous page'), findsNothing);
    expect(find.byTooltip('Jump to current level'), findsNothing);
  });

  testWidgets('only the first level is open on a fresh campaign', (
    tester,
  ) async {
    await pumpLevelSelect(tester);

    // Three of the four levels explain why they are locked — each one names
    // the level that opens it.
    expect(find.text('Clear Test Meadow to unlock'), findsOneWidget);
    expect(find.text('Clear Second Meadow to unlock'), findsOneWidget);
    expect(find.text('Clear Third Meadow to unlock'), findsOneWidget);
  });

  testWidgets('finishing a level opens exactly the next one', (tester) async {
    final container = await pumpLevelSelect(tester);

    _record(container, 'test_level');
    await tester.pumpAndSettle();

    expect(find.text('Clear Second Meadow to unlock'), findsOneWidget);
    expect(find.text('Clear Third Meadow to unlock'), findsOneWidget);
    expect(
      find.text('1 of 4 levels cleared · 3 of 12 stars'),
      findsOneWidget,
    );
  });

  testWidgets('tapping an unlocked level opens it', (tester) async {
    await pumpLevelSelect(tester);

    await tester.tap(find.text('Test Meadow'));
    await tester.pumpAndSettle();

    expect(find.text('playing test_level'), findsOneWidget);
  });

  testWidgets('tapping a locked level does nothing', (tester) async {
    await pumpLevelSelect(tester);

    await tester.tap(find.text('Second Meadow'));
    await tester.pumpAndSettle();

    expect(find.text('playing test_level_2'), findsNothing);
    expect(find.text('Region One'), findsOneWidget);
  });

  testWidgets('opening a level and going back returns to the menu', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Campaign'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test Meadow'));
    await tester.pump();
    await pumpUntilFound(tester, find.byTooltip('Back to menu'));

    // The level route is a sibling of `play`, so back is one step to the menu
    // instead of landing on a second gameplay screen.
    await tester.tap(find.byTooltip('Back to menu'));
    await tester.pumpAndSettle();

    expect(find.text(AppInfo.name), findsOneWidget);
  });

  testWidgets('a recorded result shows its stars on the level row', (
    tester,
  ) async {
    final container = await pumpLevelSelect(tester);

    _record(container, 'test_level', stars: 2, coreHealth: 3);
    await tester.pumpAndSettle();

    // Two filled stars for the completed row, and one outline that makes it
    // "2 of 3". The next level is now open, so its own three outlines appear
    // too — locked rows show no stars at all.
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(4));
  });
}
