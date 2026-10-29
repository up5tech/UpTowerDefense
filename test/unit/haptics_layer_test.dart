import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/application/level_controller.dart';
import 'package:up_tower_defense/features/gameplay/application/map_selection.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_event.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';
import 'package:up_tower_defense/features/gameplay/flame/flutter_haptics_sink.dart';
import 'package:up_tower_defense/features/gameplay/flame/game.dart';
import 'package:up_tower_defense/features/gameplay/flame/haptics_layer.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/map_fixture.dart';

class _RecordingSink implements HapticsSink {
  final List<HapticPattern> patterns = [];

  @override
  void vibrate(HapticPattern pattern) => patterns.add(pattern);
}

LevelEvent _event(LevelEventKind kind) =>
    LevelEvent(kind, const WorldPoint(100, 100));

UpTowerDefenseGame _game({
  required bool enabled,
  HapticsSink? sink,
}) {
  return UpTowerDefenseGame(
    controller: LevelController(
      session: LevelSession(
        level: testLevel,
        map: testMap,
        enemyCatalog: testEnemyCatalog,
        towerCatalog: testTowerCatalog,
      ),
    ),
    selection: MapSelection(),
    hapticsEnabled: enabled,
    hapticsSink: sink,
  );
}

void main() {
  test('important facts map to restrained haptic patterns', () {
    expect(HapticsLayer.patterns, {
      LevelEventKind.built: HapticPattern.light,
      LevelEventKind.upgraded: HapticPattern.light,
      LevelEventKind.leaked: HapticPattern.heavy,
    });
    for (final kind in [
      LevelEventKind.shot,
      LevelEventKind.hit,
      LevelEventKind.defeated,
    ]) {
      expect(HapticsLayer.patterns.containsKey(kind), isFalse);
    }
  });

  test('each mapped fact kind vibrates once per event batch', () {
    final sink = _RecordingSink();
    final layer = HapticsLayer(enabled: true, sink: sink);

    layer.handle([
      _event(LevelEventKind.built),
      _event(LevelEventKind.built),
      _event(LevelEventKind.upgraded),
      _event(LevelEventKind.leaked),
      _event(LevelEventKind.shot),
      _event(LevelEventKind.hit),
      _event(LevelEventKind.defeated),
    ]);

    expect(sink.patterns, [
      HapticPattern.light,
      HapticPattern.light,
      HapticPattern.heavy,
    ]);
  });

  test('disabled haptics and a missing platform sink remain silent', () {
    final sink = _RecordingSink();
    HapticsLayer(enabled: false, sink: sink).handle([
      _event(LevelEventKind.leaked),
    ]);
    HapticsLayer(enabled: true).handle([_event(LevelEventKind.built)]);

    expect(sink.patterns, isEmpty);
  });

  testWidgets('the platform adapter failure is harmless', (tester) async {
    const sink = FlutterHapticsSink();
    sink
      ..vibrate(HapticPattern.light)
      ..vibrate(HapticPattern.heavy);

    // The test host has no native haptic service; ignored channel failures
    // must not become uncaught errors or affect gameplay.
    await tester.pump(const Duration(milliseconds: 100));
  });

  test(
    'the game passes its haptics setting and sink to the feedback layer',
    () {
      final sink = _RecordingSink();
      final game = _game(enabled: true, sink: sink);

      game.hapticsLayer.handle([_event(LevelEventKind.leaked)]);

      expect(sink.patterns, [HapticPattern.heavy]);
      expect(_game(enabled: false).hapticsLayer.enabled, isFalse);
    },
  );
}
