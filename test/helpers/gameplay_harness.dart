import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:up_tower_defense/features/gameplay/application/level_controller.dart';
import 'package:up_tower_defense/features/gameplay/application/map_selection.dart';
import 'package:up_tower_defense/features/gameplay/data/level_bundle.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';
import 'package:up_tower_defense/features/gameplay/flame/enemy_layer.dart';
import 'package:up_tower_defense/features/gameplay/flame/fx_layer.dart';
import 'package:up_tower_defense/features/gameplay/flame/game.dart';
import 'package:up_tower_defense/features/gameplay/flame/map_component.dart';
import 'package:up_tower_defense/features/gameplay/flame/projectile_layer.dart';
import 'package:up_tower_defense/features/gameplay/flame/tower_layer.dart';
import 'package:up_tower_defense/features/gameplay/presentation/gameplay_screen.dart';

import 'content_fixtures.dart';
import 'save_overrides.dart';

/// Pumps [GameplayScreen] with an injected game on a two-route router, so back
/// navigation behaves exactly as it does in the real shell.
///
/// The game loop never settles, so this pumps a few frames instead of
/// `pumpAndSettle`. The game, controller and selection are owned by the test and
/// disposed when the tree is torn down.
Future<UpTowerDefenseGame> pumpGameplay(
  WidgetTester tester, {
  LevelBundle? bundle,
}) async {
  final content = bundle ?? testBundle;
  final selection = MapSelection();
  final controller = LevelController(
    session: LevelSession(
      level: content.level,
      map: content.map,
      enemyCatalog: content.enemies,
      towerCatalog: content.towers,
    ),
  );
  final game = UpTowerDefenseGame(controller: controller, selection: selection);

  final router = GoRouter(
    initialLocation: '/play',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('menu')),
      ),
      GoRoute(
        path: '/play',
        builder: (context, state) => GameplayScreen(game: game),
      ),
    ],
  );

  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    controller.dispose();
    selection.dispose();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [isolatedSaveOverride()],
      // Matches the real shell (lib/app/app.dart): without this the test-only
      // debug banner paints a ribbon over the field's top-right corner and
      // shows up in captures.
      child: MaterialApp.router(
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    ),
  );

  // Two kinds of asynchrony have to interleave before the field is usable:
  // see [waitForGameLayers].
  await waitForGameLayers(tester, game);
  await tester.pump(const Duration(milliseconds: 200));

  return game;
}

/// Waits until every gameplay layer has mounted its sprite files.
///
/// Two kinds of asynchrony have to interleave: layers start loading only on a
/// lifecycle tick (pump), and their sprites decode only in real async time
/// (runAsync) — the test's fake clock never runs a codec. Alternating the two
/// is what makes the field tappable; without it the map component never mounts
/// and taps reach nothing. Fails with the layers still missing instead of
/// letting later interactions fail somewhere far away.
Future<void> waitForGameLayers(
  WidgetTester tester,
  UpTowerDefenseGame game,
) async {
  const expectedLayers = [
    MapComponent,
    TowerLayer,
    EnemyLayer,
    ProjectileLayer,
    FxLayer,
  ];
  for (var i = 0; i < 30; i++) {
    final pending = [
      for (final type in expectedLayers)
        if (!game.world.children.any((child) => child.runtimeType == type))
          type,
    ];
    if (pending.isEmpty) {
      return;
    }
    if (i == 29) {
      fail('the game never mounted its layers; still missing: $pending');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
}
