import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/core/constants/app_info.dart';

import '../helpers/pump_app.dart';

/// The tower/enemy codex (PLAN Phase 11).
///
/// Widget cases read the fixture catalogs through the real screen and the real
/// provider composition, so the copy they assert is the copy a player sees.
void main() {
  testWidgets('codex opens from the menu and explains the tower catalog', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Codex'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Codex'), findsOneWidget);
    expect(find.text(AppInfo.name), findsNothing);

    // Identity, cost and the base stats of the fixture roster's first tower.
    expect(find.text('Ranger Tower'), findsOneWidget);
    expect(find.text('Cost 70 g'), findsOneWidget);
    expect(find.text('Damage 18'), findsOneWidget);
    expect(find.text('Range 210'), findsOneWidget);
    expect(find.text('Fire 0.7s'), findsOneWidget);

    // Traits that are not plain numbers are spelled out, not just chipped.
    expect(find.textContaining('Shells explode'), findsOneWidget);
    expect(find.textContaining('Each hit slows by 40%'), findsOneWidget);
    expect(find.textContaining('take 25% more damage'), findsOneWidget);

    // The whole upgrade curve, with the gold each step costs.
    expect(
      find.textContaining('Lv2: 27 dmg for 60 g · Lv3: 40 dmg for 95 g'),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text(AppInfo.name), findsOneWidget);
  });

  testWidgets('switching to enemies lists the enemy catalog and its rules', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Codex'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enemies'));
    await tester.pumpAndSettle();

    expect(find.text('Grunt'), findsOneWidget);
    expect(find.text('Health 100'), findsOneWidget);
    expect(find.text('Speed 80/s'), findsOneWidget);
    expect(find.text('Kill reward 10 g'), findsOneWidget);
    expect(
      find.textContaining(
        'Reaching the core costs 1 core health. A kill pays 10 g',
      ),
      findsOneWidget,
    );
    expect(find.text('Ranger Tower'), findsNothing);

    // The toggle swaps one list for the other; it never stacks a second screen.
    await tester.tap(find.text('Towers'));
    await tester.pumpAndSettle();

    expect(find.text('Ranger Tower'), findsOneWidget);
    expect(find.text('Grunt'), findsNothing);
  });
}
