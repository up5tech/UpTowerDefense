import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/data/level_bundle.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/gameplay_harness.dart';
import '../helpers/map_fixture.dart';

/// V2-5's large-text audit: the HUD, both pad-panel states, the pause panel and
/// the result card at 1.3× text on the 800×450 reference landscape.
///
/// A RenderFlex overflow is a Flutter error, so each case asserts the content is
/// reachable *and* that nothing was thrown: a card that clipped its last control
/// fails here instead of shipping.
const double _scale = 0.625;
const Offset _padA = Offset(180 * _scale, 360 * _scale);

void _useReferenceLandscape(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 450);
  addTearDown(tester.view.reset);
}

/// The fixture with the campaign's longest level name, so the HUD is audited at
/// the width a real shipped level uses rather than the short fixture label.
LevelBundle _longNamed() {
  return LevelBundle(
    level: LevelDefinition(
      id: testLevel.id,
      displayName: "Warden's Court",
      mapId: testLevel.mapId,
      coreHealth: testLevel.coreHealth,
      startingGold: testLevel.startingGold,
      waves: testLevel.waves,
    ),
    map: testMap,
    enemies: testEnemyCatalog,
    towers: testTowerCatalog,
  );
}

/// A one-hit core, so the defeat result card is one wave away.
LevelBundle _fragileCore() {
  return LevelBundle(
    level: LevelDefinition(
      id: testLevel.id,
      displayName: testLevel.displayName,
      mapId: testLevel.mapId,
      coreHealth: 1,
      startingGold: testLevel.startingGold,
      waves: testLevel.waves,
    ),
    map: testMap,
    enemies: testEnemyCatalog,
    towers: testTowerCatalog,
  );
}

void main() {
  testWidgets('the HUD fits and announces whole facts at 1.3x', (tester) async {
    _useReferenceLandscape(tester);
    await pumpGameplay(tester, textScale: 1.3);

    expect(find.text('Test Meadow'), findsOneWidget);
    expect(find.text('5/5'), findsOneWidget);
    expect(find.text('Wave 0/2'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The shorthand is fine on screen; a screen reader gets the sentence.
    expect(find.bySemanticsLabel('Level Test Meadow'), findsOneWidget);
    expect(find.bySemanticsLabel('Gold 150'), findsOneWidget);
    expect(find.bySemanticsLabel('Core 5 of 5'), findsOneWidget);
    expect(find.bySemanticsLabel('Wave 0 of 2'), findsOneWidget);
  });

  testWidgets('the build panel and tower details fit at 1.3x', (tester) async {
    _useReferenceLandscape(tester);
    await pumpGameplay(tester, textScale: 1.3);

    await tester.tapAt(_padA);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Choose a tower'), findsOneWidget);
    expect(find.text('Ranger Tower'), findsOneWidget);
    expect(find.text('70 g'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Ranger Tower'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Lv 1/3'), findsOneWidget);
    expect(find.text('Upgrade for 60 g'), findsOneWidget);
    expect(find.text('Sell for 42 g'), findsOneWidget);
    // Both target chips stay on screen, and their actions are named for a
    // screen reader rather than only by the adjective on the chip.
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Strongest'), findsOneWidget);
    expect(find.bySemanticsLabel('Target the first enemy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the pause panel fits and stays reachable at 1.3x', (
    tester,
  ) async {
    _useReferenceLandscape(tester);
    // A long shipped name is what pushes the fact chips past the row, so this
    // case is the one that proves the actions are pinned outside the scroll.
    await pumpGameplay(tester, bundle: _longNamed(), textScale: 1.3);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.byTooltip('Restart level'), findsOneWidget);
    expect(find.byTooltip('Quit to menu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the result card fits at 1.3x', (tester) async {
    _useReferenceLandscape(tester);
    final game = await pumpGameplay(
      tester,
      bundle: _fragileCore(),
      textScale: 1.3,
    );

    await tester.tap(find.text('Start wave'));
    await tester.pump();

    // Run past the whole route in loop-sized steps: both wave-one grunts leak
    // and drain the single hit point.
    for (var i = 0; i < 300; i++) {
      game.controller.advance(0.1);
    }
    await tester.pump();

    expect(find.text('Core destroyed'), findsOneWidget);
    expect(find.text('Replay'), findsOneWidget);
    expect(find.text('Menu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
