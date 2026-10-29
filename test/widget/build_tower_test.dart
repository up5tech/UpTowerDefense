import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/data/level_bundle.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/targeting_policy.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/gameplay_harness.dart';
import '../helpers/map_fixture.dart';

/// World-to-screen mapping for an 800x450 surface showing a 1280x720 world:
/// aspect ratios match, so the scale is 0.625 with no letterbox.
const double _scale = 0.625;

const WorldPoint _padA = WorldPoint(180, 360);
const WorldPoint _padB = WorldPoint(860, 380);

Offset _screen(WorldPoint point) => Offset(point.x * _scale, point.y * _scale);

LevelBundle _bundle({int startingGold = 150}) {
  return LevelBundle(
    level: LevelDefinition(
      id: testLevel.id,
      displayName: testLevel.displayName,
      mapId: testLevel.mapId,
      coreHealth: testLevel.coreHealth,
      startingGold: startingGold,
      waves: testLevel.waves,
    ),
    map: testMap,
    enemies: testEnemyCatalog,
    towers: testTowerCatalog,
  );
}

/// [testBundle] with the full Phase 6 roster, so the build menu offers cannon
/// and frost next to the ranger.
LevelBundle _rosterBundle({int startingGold = 150}) {
  return LevelBundle(
    level: LevelDefinition(
      id: testLevel.id,
      displayName: testLevel.displayName,
      mapId: testLevel.mapId,
      coreHealth: testLevel.coreHealth,
      startingGold: startingGold,
      waves: testLevel.waves,
    ),
    map: testMap,
    enemies: testEnemyCatalog,
    towers: fullTowerCatalog,
  );
}

void _useSmallLandscape(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 450);
  addTearDown(tester.view.reset);
}

Future<void> _tapWorld(WidgetTester tester, WorldPoint point) async {
  await tester.tapAt(_screen(point));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('the wave control avoids every build pad on a small screen', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 360);
    addTearDown(tester.view.reset);
    await pumpGameplay(tester);

    await tester.tapAt(const Offset(90, 180));
    await tester.pump(const Duration(milliseconds: 100));

    final wave = tester.getRect(find.byKey(const ValueKey('wave-control')));
    for (final pad in testMap.buildPads) {
      final padBounds = Rect.fromCircle(
        center: Offset(pad.position.x * 0.5, pad.position.y * 0.5),
        radius: testMap.buildPadRadius * 0.5 + 12,
      );
      expect(
        wave.overlaps(padBounds),
        isFalse,
        reason: '${pad.id} is covered by the wave control',
      );
    }

    // The panel still takes the clearest spot, but a menu that has to show
    // every tower needs more height than a 360-tall viewport can spare between
    // the pads, so pad clearance is best-effort there. What it must never do is
    // hang off the screen: the list is only reachable if it is fully painted.
    final panel = tester.getRect(find.byKey(const ValueKey('pad-panel')));
    expect(panel.left, greaterThanOrEqualTo(0));
    expect(panel.top, greaterThanOrEqualTo(0));
    expect(panel.right, lessThanOrEqualTo(640));
    expect(panel.bottom, lessThanOrEqualTo(360));
  });

  testWidgets('an empty pad offers the tower with its cost', (tester) async {
    _useSmallLandscape(tester);
    await pumpGameplay(tester);

    expect(find.text('150 g'), findsOneWidget);

    await _tapWorld(tester, _padA);

    expect(find.text('Build pad A'), findsOneWidget);
    expect(find.text('Ranger Tower'), findsOneWidget);
    expect(find.text('Fast single target'), findsOneWidget);
    expect(find.text('70 g'), findsOneWidget);
    expect(find.textContaining('Need'), findsNothing);
  });

  testWidgets('building deducts gold and shows the tower details', (
    tester,
  ) async {
    _useSmallLandscape(tester);
    final game = await pumpGameplay(tester);

    await _tapWorld(tester, _padA);
    await tester.tap(find.text('Ranger Tower'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('80 g'), findsOneWidget);
    expect(find.text('150 g'), findsNothing);
    expect(find.text('Build pad A'), findsNothing);
    expect(find.text('Pad A'), findsOneWidget);
    expect(find.text('Ranger Tower'), findsOneWidget);
    expect(find.text('Damage 18'), findsOneWidget);
    expect(find.text('Range 210'), findsOneWidget);
    expect(find.text('Fire 0.7s'), findsOneWidget);
    expect(game.session.towers, hasLength(1));
    expect(game.session.towerAtPad('pad_a')!.definition.id, 'ranger');
    expect(game.session.gold, 80);
  });

  testWidgets('an unaffordable tower is disabled and explains the shortfall', (
    tester,
  ) async {
    _useSmallLandscape(tester);
    final game = await pumpGameplay(tester, bundle: _bundle(startingGold: 10));

    await _tapWorld(tester, _padA);

    expect(find.text('10 g'), findsOneWidget);
    expect(find.text('70 g'), findsOneWidget);
    expect(find.text('Need 60 more'), findsOneWidget);

    await tester.tap(find.text('Ranger Tower'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Build pad A'), findsOneWidget);
    expect(find.text('10 g'), findsOneWidget);
    expect(game.session.towers, isEmpty);
    expect(game.session.gold, 10);
  });

  testWidgets('repeated taps never build twice on one pad', (tester) async {
    _useSmallLandscape(tester);
    final game = await pumpGameplay(tester);

    await _tapWorld(tester, _padA);
    await tester.tap(find.text('Ranger Tower'));
    await tester.pump(const Duration(milliseconds: 100));

    // Selecting another pad and coming back must not offer a second build.
    await _tapWorld(tester, _padB);
    expect(find.text('Build pad B'), findsOneWidget);

    await _tapWorld(tester, _padA);
    expect(find.text('Pad A'), findsOneWidget);
    expect(find.text('Build pad A'), findsNothing);

    expect(game.session.towers, hasLength(1));
    expect(game.session.gold, 80);
  });

  testWidgets('a tower can also be built on a second pad', (tester) async {
    _useSmallLandscape(tester);
    final game = await pumpGameplay(tester);

    await _tapWorld(tester, _padA);
    await tester.tap(find.text('Ranger Tower'));
    await tester.pump(const Duration(milliseconds: 100));

    await _tapWorld(tester, _padB);
    expect(find.text('Build pad B'), findsOneWidget);

    await tester.tap(find.text('Ranger Tower'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(game.session.towers.map((tower) => tower.padId), ['pad_a', 'pad_b']);
    expect(game.session.gold, 10);
    expect(find.text('10 g'), findsOneWidget);
    expect(find.text('Pad B'), findsOneWidget);
  });

  testWidgets('the tower panel shows current and next-level stats', (
    tester,
  ) async {
    _useSmallLandscape(tester);
    await pumpGameplay(tester, bundle: _rosterBundle());

    await _tapWorld(tester, _padA);
    await tester.tap(find.text('Ranger Tower'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Pad A'), findsOneWidget);
    expect(find.text('Lv 1/3'), findsOneWidget);
    expect(find.text('Damage 18'), findsOneWidget);
    expect(find.text('Range 210'), findsOneWidget);
    expect(find.text('Fire 0.7s'), findsOneWidget);
    expect(find.text('Next: 27 dmg · 225 range · 0.7s'), findsOneWidget);
    expect(find.text('Upgrade for 60 g'), findsOneWidget);
    expect(find.text('Sell for 42 g'), findsOneWidget);
    // The ranger has no blast and no slow, so neither chip may appear.
    expect(find.textContaining('Blast'), findsNothing);
    expect(find.textContaining('Slow'), findsNothing);
  });

  testWidgets('upgrading spends gold and advances the panel', (tester) async {
    _useSmallLandscape(tester);
    final game = await pumpGameplay(tester, bundle: _rosterBundle());

    await _tapWorld(tester, _padA);
    await tester.tap(find.text('Ranger Tower'));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.ensureVisible(find.text('Upgrade for 60 g'));
    await tester.tap(find.text('Upgrade for 60 g'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('20 g'), findsOneWidget);
    expect(find.text('Lv 2/3'), findsOneWidget);
    expect(find.text('Damage 27'), findsOneWidget);
    expect(find.text('Next: 40 dmg · 245 range · 0.6s'), findsOneWidget);

    final tower = game.session.towerAtPad('pad_a')!;
    expect(tower.level, 2);
    expect(tower.investedGold, 130);
    expect(game.session.gold, 20);

    // 20 gold cannot pay the 95-gold level-3 upgrade, and the disabled button
    // is the same check the domain would refuse with.
    expect(find.text('Need 75 more gold'), findsOneWidget);
    final upgradeButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Upgrade for 95 g'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(upgradeButton.onPressed, isNull);
  });

  testWidgets('an unaffordable upgrade is disabled with the shortfall', (
    tester,
  ) async {
    _useSmallLandscape(tester);
    final game = await pumpGameplay(
      tester,
      bundle: _rosterBundle(startingGold: 100),
    );

    await _tapWorld(tester, _padA);
    await tester.tap(find.text('Ranger Tower'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('30 g'), findsOneWidget);
    expect(find.text('Need 30 more gold'), findsOneWidget);
    final upgradeButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Upgrade for 60 g'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(upgradeButton.onPressed, isNull);

    await tester.ensureVisible(find.text('Upgrade for 60 g'));
    await tester.tap(find.text('Upgrade for 60 g'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(game.session.towerAtPad('pad_a')!.level, 1);
    expect(game.session.gold, 30);
  });

  testWidgets('selling refunds and returns the pad to the build menu', (
    tester,
  ) async {
    _useSmallLandscape(tester);
    final game = await pumpGameplay(tester, bundle: _rosterBundle());

    await _tapWorld(tester, _padA);
    await tester.tap(find.text('Ranger Tower'));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.ensureVisible(find.text('Sell for 42 g'));
    await tester.tap(find.text('Sell for 42 g'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Build pad A'), findsOneWidget);
    expect(find.text('Choose a tower'), findsOneWidget);
    expect(find.text('122 g'), findsOneWidget);
    expect(game.session.towers, isEmpty);
    expect(game.session.isPadOccupied('pad_a'), isFalse);
  });

  testWidgets('the priority chips switch the tower policy', (tester) async {
    _useSmallLandscape(tester);
    final game = await pumpGameplay(tester, bundle: _rosterBundle());

    await _tapWorld(tester, _padA);
    await tester.tap(find.text('Ranger Tower'));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.ensureVisible(find.text('Strongest'));
    await tester.tap(find.text('Strongest'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      game.session.towerAtPad('pad_a')!.targetingPolicy,
      TargetingPolicy.strongest,
    );

    await tester.ensureVisible(find.text('First'));
    await tester.tap(find.text('First'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      game.session.towerAtPad('pad_a')!.targetingPolicy,
      TargetingPolicy.first,
    );
  });

  testWidgets('the build menu offers cannon and frost with their roles', (
    tester,
  ) async {
    _useSmallLandscape(tester);
    await pumpGameplay(tester, bundle: _rosterBundle());

    await _tapWorld(tester, _padA);

    expect(find.text('Cannon Tower'), findsOneWidget);
    expect(find.text('Area damage'), findsOneWidget);
    expect(find.text('110 g'), findsOneWidget);
    expect(find.text('Frost Tower'), findsOneWidget);
    expect(find.text('Control'), findsOneWidget);
    expect(find.text('85 g'), findsOneWidget);
  });

  testWidgets('the tower panel fits every control on a landscape phone', (
    tester,
  ) async {
    // 844x390 is a common phone in landscape: the panel used to stop inside the
    // target chips, so the sell button and the policy chips were unreachable.
    const size = Size(844, 390);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    for (final tower in ['Ranger Tower', 'Frost Tower', 'Cannon Tower']) {
      await pumpGameplay(tester, bundle: _rosterBundle());

      final scale = [
        size.width / testMap.worldWidth,
        size.height / testMap.worldHeight,
      ].reduce((a, b) => a < b ? a : b);
      final origin = Offset(
        (size.width - testMap.worldWidth * scale) / 2,
        (size.height - testMap.worldHeight * scale) / 2,
      );
      await tester.tapAt(origin + Offset(_padA.x * scale, _padA.y * scale));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.ensureVisible(find.text(tower));
      await tester.tap(find.text(tower));
      await tester.pump(const Duration(milliseconds: 100));

      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(const ValueKey('pad-panel')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(
        scrollable.position.maxScrollExtent,
        0,
        reason: '$tower panel is taller than the screen and clips its controls',
      );

      final panel = tester.getRect(find.byKey(const ValueKey('pad-panel')));
      final sell = tester.getRect(find.textContaining('Sell for'));
      expect(panel.contains(sell.topLeft), isTrue);
      expect(panel.contains(sell.bottomRight), isTrue);
    }
  });

  testWidgets('the build menu paints every tower without clipping', (
    tester,
  ) async {
    _useSmallLandscape(tester);
    await pumpGameplay(tester, bundle: _rosterBundle());

    await _tapWorld(tester, _padA);

    // Existing checks only proved the texts are in the tree; a scroll view
    // keeps clipped children there. On a 450-tall landscape viewport the panel
    // used to stop after the first option, so every choice has to be painted
    // inside the panel's own bounds.
    final panel = tester.getRect(find.byKey(const ValueKey('pad-panel')));
    for (final name in ['Ranger Tower', 'Frost Tower', 'Cannon Tower']) {
      final option = tester.getRect(find.text(name));
      expect(
        option.top >= panel.top && option.bottom <= panel.bottom,
        isTrue,
        reason: '$name is clipped by the build panel ($option vs $panel)',
      );
    }
  });

  testWidgets('the cannon panel shows its blast radius', (tester) async {
    _useSmallLandscape(tester);
    final game = await pumpGameplay(tester, bundle: _rosterBundle());

    await _tapWorld(tester, _padA);
    await tester.ensureVisible(find.text('Cannon Tower'));
    await tester.tap(find.text('Cannon Tower'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Damage 26'), findsOneWidget);
    expect(find.text('Blast 70'), findsOneWidget);
    // The next level shows the blast it buys, not just damage and range.
    expect(
      find.text('Next: 40 dmg · 215 range · 1.5s · blast 78'),
      findsOneWidget,
    );

    // 150 - 110 build leaves 40 gold, short of the 90-gold upgrade.
    expect(find.text('40 g'), findsOneWidget);
    expect(find.text('Need 50 more gold'), findsOneWidget);
    expect(game.session.towerAtPad('pad_a')!.definition.id, 'cannon');
  });

  testWidgets('the frost panel shows its slow and maxes out on upgrade', (
    tester,
  ) async {
    _useSmallLandscape(tester);
    final game = await pumpGameplay(tester, bundle: _rosterBundle());

    await _tapWorld(tester, _padA);
    await tester.ensureVisible(find.text('Frost Tower'));
    await tester.tap(find.text('Frost Tower'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Damage 4'), findsOneWidget);
    expect(find.text('Slow 40% / 2.5s'), findsOneWidget);
    // A longer, stronger slow is the upgrade, so it has to be visible before
    // the player pays for it.
    expect(
      find.text('Next: 6 dmg · 205 range · 1.1s · slow 50% / 3s'),
      findsOneWidget,
    );
    // 150 - 85 build leaves exactly the 65-gold upgrade.
    expect(find.text('65 g'), findsOneWidget);

    await tester.ensureVisible(find.text('Upgrade for 65 g'));
    await tester.tap(find.text('Upgrade for 65 g'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('0 g'), findsOneWidget);
    expect(find.text('Lv 2/2'), findsOneWidget);
    expect(find.text('Slow 50% / 3s'), findsOneWidget);
    expect(find.text('Max level'), findsOneWidget);
    expect(game.session.towerAtPad('pad_a')!.level, 2);
  });
}
