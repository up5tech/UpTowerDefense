import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/campaign/application/achievement_providers.dart';
import 'package:up_tower_defense/features/campaign/application/campaign_providers.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_progress.dart';

import '../helpers/pump_app.dart';

/// The progress screen (V2-4) reports facts, not promises.
///
/// It reads the same providers the menu and picker read, so these cases drive it
/// the way a player reaches it — through the menu — and assert the numbers the
/// save actually holds.
Future<void> _openProgress(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Progress'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Progress'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a fresh save shows zero totals and ten locked achievements', (
    tester,
  ) async {
    await pumpApp(tester);
    await _openProgress(tester);

    expect(find.widgetWithText(AppBar, 'Progress'), findsOneWidget);
    expect(
      find.text('0 of 4 levels cleared on Normal · 0 of 12 stars'),
      findsOneWidget,
    );
    expect(find.text('Endless best'), findsOneWidget);
    expect(find.text('Not played yet'), findsOneWidget);
    expect(find.text('Achievements'), findsOneWidget);
    expect(find.text('0 of 10'), findsOneWidget);
    expect(find.text('Locked'), findsNWidgets(10));
    // Every locked achievement still explains what it asks for.
    expect(find.text('Finish any campaign level'), findsOneWidget);
  });

  testWidgets('an earned fact moves the totals and the earned rows', (
    tester,
  ) async {
    final container = await pumpApp(tester);

    container
        .read(campaignProgressProvider.notifier)
        .record(
          const LevelResult(
            levelId: 'test_level',
            stars: 3,
            coreHealth: 5,
            maxCoreHealth: 5,
            wavesCleared: 2,
            totalWaves: 2,
            objectivesMet: 2,
          ),
        );
    await container.read(achievementsProvider.notifier).refresh();
    await tester.pumpAndSettle();

    await _openProgress(tester);

    expect(
      find.text('1 of 4 levels cleared on Normal · 3 of 12 stars'),
      findsOneWidget,
    );
    // First clear, untouched core and three stars, all from one run.
    expect(find.text('3 of 10'), findsOneWidget);
    expect(find.text('Earned'), findsNWidgets(3));
    expect(find.text('Locked'), findsNWidgets(7));
  });
}
