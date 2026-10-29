// Phase 9's acceptance criteria end to end: progress survives a relaunch, a
// clean install still reaches a playable level, and storage is only touched
// when something actually changed.
//
// A relaunch is simulated by tearing the whole widget tree down — including the
// provider container — and booting a fresh shell over the same storage, so
// nothing can be carried over in memory.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/campaign/application/campaign_providers.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_progress.dart';
import 'package:up_tower_defense/features/gameplay/presentation/gameplay_screen.dart';
import 'package:up_tower_defense/features/save/data/in_memory_save_store.dart';
import 'package:up_tower_defense/features/save/data/save_store.dart';

import '../helpers/pump_app.dart';
import '../helpers/pump_until.dart';

/// Counts writes, so a test can prove when the app reaches for storage.
class _CountingStore implements SaveStore {
  _CountingStore(this.inner);

  final SaveStore inner;
  int writes = 0;

  @override
  Future<String?> readCurrent() => inner.readCurrent();

  @override
  Future<String?> readBackup() => inner.readBackup();

  @override
  Future<void> write(String payload) {
    writes++;
    return inner.write(payload);
  }

  @override
  Future<void> preserve(String payload) => inner.preserve(payload);
}

LevelResult _result({int stars = 3}) {
  return LevelResult(
    levelId: 'test_level',
    stars: stars,
    coreHealth: 10,
    maxCoreHealth: 10,
    wavesCleared: 2,
    totalWaves: 2,
  );
}

/// Unmounts everything, so the next [pumpApp] boots from storage alone.
Future<void> _forceClose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('progress recorded in one session is there after a relaunch', (
    tester,
  ) async {
    final storage = InMemorySaveStore();

    final firstSession = await pumpApp(tester, saveStore: storage);
    // The gameplay screen records a finished attempt through this same call.
    firstSession.read(campaignProgressProvider.notifier).record(_result());
    await tester.pumpAndSettle();

    expect(storage.current, isNotNull);

    await _forceClose(tester);

    final secondSession = await pumpApp(tester, saveStore: storage);
    expect(
      secondSession.read(campaignProgressProvider).isCompleted('test_level'),
      isTrue,
    );
    expect(
      secondSession.read(campaignProgressProvider).starsFor('test_level'),
      3,
    );

    // The picker agrees with what was loaded, not with a fresh campaign.
    await tester.tap(find.text('Campaign'));
    await tester.pumpAndSettle();
    expect(find.text('Clear Second Meadow to unlock'), findsOneWidget);
    expect(find.text('Clear Third Meadow to unlock'), findsOneWidget);
  });

  testWidgets('a clean install still reaches a playable level', (
    tester,
  ) async {
    final container = await pumpApp(tester);

    expect(container.read(campaignProgressProvider).results, isEmpty);

    // Play opens the first level without any stored data.
    await tester.tap(find.text('Play'));
    await tester.pump();
    await pumpUntilFound(tester, find.byType(GameplayScreen));
    expect(find.text('150 g'), findsOneWidget);

    await tester.tap(find.byTooltip('Back to menu'));
    await tester.pumpAndSettle();

    // The picker agrees: a clean campaign locks everything but its first level.
    await tester.tap(find.text('Campaign'));
    await tester.pumpAndSettle();
    expect(find.text('Clear Test Meadow to unlock'), findsOneWidget);
    expect(find.text('Clear Second Meadow to unlock'), findsOneWidget);
    expect(find.text('Clear Third Meadow to unlock'), findsOneWidget);
  });

  testWidgets('storage is written on changes only, never per frame', (
    tester,
  ) async {
    final storage = _CountingStore(InMemorySaveStore());
    final container = await pumpApp(tester, saveStore: storage);

    // Navigating and idling on the menu write nothing.
    await tester.tap(find.text('Campaign'));
    await tester.pumpAndSettle();
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(storage.writes, 0);

    // One recorded result, one write.
    container.read(campaignProgressProvider.notifier).record(_result());
    await tester.pumpAndSettle();
    expect(storage.writes, 1);

    // A worse replay changes nothing, so it writes nothing.
    container.read(campaignProgressProvider.notifier).record(_result(stars: 1));
    await tester.pumpAndSettle();
    expect(storage.writes, 1);

    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(storage.writes, 1);
  });
}
