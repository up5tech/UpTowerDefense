import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/app/router.dart';
import 'package:up_tower_defense/core/constants/app_info.dart';
import 'package:up_tower_defense/features/gameplay/presentation/gameplay_screen.dart';
import 'package:up_tower_defense/features/main_menu/presentation/main_menu_screen.dart';
import 'package:up_tower_defense/features/settings/data/in_memory_settings_store.dart';

import '../helpers/pump_app.dart';
import '../helpers/pump_until.dart';

/// The first-level tutorial (PLAN Phase 11).
///
/// The card is step-driven, not action-driven: every step advances through its
/// own buttons, so nothing a player does in the level — building, starting a
/// wave, pausing — can strand the tour. These cases pin that guarantee, the
/// one-time dismissal, and that the card belongs only to the campaign's
/// opening level.
void main() {
  testWidgets('the first level walks through the tutorial once, then never '
      'again', (tester) async {
    final store = InMemorySettingsStore();
    await pumpApp(tester, store: store);

    await tester.tap(find.text('Play'));
    await pumpUntilFound(tester, find.text('Step 1 of 3'));
    expect(store.settings.tutorialSeen, isFalse);

    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Step 2 of 3'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Step 3 of 3'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pump();
    expect(find.text('Step 1 of 3'), findsNothing);
    expect(find.text('Got it'), findsNothing);

    // The dismissal was written through the real settings chain…
    expect(store.settings.tutorialSeen, isTrue);

    // …so a second visit to the same level stays card-free.
    await tester.tap(find.byTooltip('Back to menu'));
    await tester.pumpAndSettle();
    expect(find.text(AppInfo.name), findsOneWidget);

    await tester.tap(find.text('Play'));
    await pumpUntilFound(tester, find.byType(GameplayScreen));
    await tester.pump();
    expect(find.text('Step 1 of 3'), findsNothing);
  });

  testWidgets('the tutorial can be skipped straight from the first step', (
    tester,
  ) async {
    final store = InMemorySettingsStore();
    await pumpApp(tester, store: store);

    await tester.tap(find.text('Play'));
    await pumpUntilFound(tester, find.text('Step 1 of 3'));

    await tester.tap(find.byTooltip('Skip tutorial'));
    await tester.pump();

    expect(find.text('Step 1 of 3'), findsNothing);
    expect(store.settings.tutorialSeen, isTrue);
  });

  testWidgets('the card never blocks the level it describes', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Play'));
    await pumpUntilFound(tester, find.text('Step 1 of 3'));

    // The wave control under the card still works while the tour is up: a
    // player who already knows the game never has to step through it.
    await tester.tap(find.text('Start wave'));
    await tester.pump();

    expect(find.text('Wave in progress'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
  });

  testWidgets('levels after the campaign opener open without the card', (
    tester,
  ) async {
    await pumpApp(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MainMenuScreen)),
    );
    container.read(routerProvider).go('/play/test_level_2');

    await pumpUntilFound(tester, find.byType(GameplayScreen));
    await tester.pump();

    expect(find.text('Step 1 of 3'), findsNothing);
  });
}
