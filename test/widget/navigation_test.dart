import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/core/constants/app_info.dart';
import 'package:up_tower_defense/features/gameplay/flame/game.dart';

import '../helpers/pump_app.dart';
import '../helpers/pump_until.dart';

void main() {
  testWidgets('each menu entry opens its screen and back returns to the menu', (
    tester,
  ) async {
    await pumpApp(tester);

    for (final label in ['Campaign', 'Codex', 'Settings', 'Credits']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, label), findsOneWidget);
      expect(find.text(AppInfo.name), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text(AppInfo.name), findsOneWidget);
    }
  });

  testWidgets('Play loads the map and back returns to the menu', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Play'));
    await tester.pump();

    // The map is read from the bundled asset, so wait for it to arrive.
    await pumpUntilFound(tester, find.text('Test Meadow'));

    expect(find.byType(GameWidget<UpTowerDefenseGame>), findsOneWidget);

    await tester.tap(find.byTooltip('Back to menu'));
    await tester.pumpAndSettle();

    expect(find.text(AppInfo.name), findsOneWidget);
  });

  testWidgets('system back leaves gameplay instead of trapping the player', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Play'));
    await tester.pump();
    await pumpUntilFound(tester, find.text('Test Meadow'));

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.text(AppInfo.name), findsOneWidget);
  });

  testWidgets('repeated enter and exit of gameplay keeps working', (
    tester,
  ) async {
    await pumpApp(tester);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Play'));
      await tester.pump();
      await pumpUntilFound(tester, find.text('Test Meadow'));

      await tester.tap(find.byTooltip('Back to menu'));
      await tester.pumpAndSettle();
      expect(find.text(AppInfo.name), findsOneWidget);
    }
  });

  testWidgets('menus render without overflow on a small landscape phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    // 640x360 logical pixels: a cramped landscape phone.
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(tester.view.reset);

    await pumpApp(tester);

    for (final label in ['Campaign', 'Codex', 'Settings', 'Credits']) {
      // The menu scrolls on short screens; reach the button before tapping.
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}
