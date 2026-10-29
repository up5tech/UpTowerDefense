import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/application/level_controller.dart';
import 'package:up_tower_defense/features/gameplay/application/map_selection.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_event.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';
import 'package:up_tower_defense/features/gameplay/flame/fx_layer.dart';
import 'package:up_tower_defense/features/gameplay/flame/game.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/map_fixture.dart';

LevelEvent _event(LevelEventKind kind, {double radius = 0}) {
  return LevelEvent(kind, const WorldPoint(100, 100), radius: radius);
}

void main() {
  test('every published fact has a cue that expires', () {
    final layer = FxLayer();

    for (final kind in LevelEventKind.values) {
      layer.publish([
        _event(kind, radius: kind == LevelEventKind.hit ? 40 : 0),
      ]);
    }

    expect(layer.activeCount, LevelEventKind.values.length);
    layer.update(1);
    expect(layer.activeCount, 0, reason: 'no cue may outlive its lifetime');
  });

  test('a burst of cues keeps the newest and drops the oldest', () {
    final layer = FxLayer();

    layer.publish([
      for (var i = 0; i < FxLayer.maxLiveEffects; i++)
        _event(LevelEventKind.shot),
      _event(LevelEventKind.leaked),
    ]);

    // The cap bites, and what it drops is the oldest — the cue the player just
    // caused is the one worth keeping.
    expect(layer.activeCount, FxLayer.maxLiveEffects);
    expect(layer.effects.last.kind, LevelEventKind.leaked);
    expect(
      layer.effects.where((effect) => effect.kind == LevelEventKind.shot),
      hasLength(FxLayer.maxLiveEffects - 1),
    );
  });

  test('a core impact expands while it fades', () {
    final layer = FxLayer();
    layer.publish([_event(LevelEventKind.leaked)]);

    final birth = layer.effects.single;
    layer.update(0.2);
    final later = layer.effects.single;

    expect(later.radius, greaterThan(birth.radius));
    expect(later.alpha, lessThan(birth.alpha));
  });

  test('reduced motion freezes geometry but keeps the fade', () {
    final layer = FxLayer(reducedMotion: true);
    layer.publish([_event(LevelEventKind.leaked)]);

    final birth = layer.effects.single;
    layer.update(0.2);
    final later = layer.effects.single;

    // The cue stays readable — same size, same place, less opaque — it just
    // does not move.
    expect(later.radius, birth.radius);
    expect(later.center, birth.center);
    expect(later.alpha, lessThan(birth.alpha));
  });

  test('upward cues rise with motion and stay put without it', () {
    final moving = FxLayer();
    moving.publish([_event(LevelEventKind.upgraded)]);
    moving.update(0.2);
    expect(moving.effects.single.rise, greaterThan(0));

    final still = FxLayer(reducedMotion: true);
    still.publish([_event(LevelEventKind.upgraded)]);
    still.update(0.2);
    expect(still.effects.single.rise, 0);
  });

  test('a splash cue carries the blast radius the rule used', () {
    final layer = FxLayer();
    layer.publish([_event(LevelEventKind.hit, radius: 70)]);

    expect(layer.effects.single.blastRadius, greaterThan(0));
    // It starts at exactly the radius the damage rule resolved with.
    expect(layer.effects.single.blastRadius, closeTo(70, 0.001));
  });

  test('clearing drops the cues of the run that produced them', () {
    final layer = FxLayer();
    layer.publish([_event(LevelEventKind.hit)]);

    layer.clear();

    expect(layer.activeCount, 0);
  });

  test('the game hands the accessibility setting to the effect layer', () {
    final game = UpTowerDefenseGame(
      controller: LevelController(
        session: LevelSession(
          level: testLevel,
          map: testMap,
          enemyCatalog: testEnemyCatalog,
          towerCatalog: testTowerCatalog,
        ),
      ),
      selection: MapSelection(),
      reducedMotion: true,
    );

    expect(game.fxLayer.reducedMotion, isTrue);
  });
}
