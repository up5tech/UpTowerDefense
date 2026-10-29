import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/application/level_controller.dart';
import 'package:up_tower_defense/features/gameplay/application/map_selection.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_event.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';
import 'package:up_tower_defense/features/gameplay/flame/flame_audio_sfx_sink.dart';
import 'package:up_tower_defense/features/gameplay/flame/game.dart';
import 'package:up_tower_defense/features/gameplay/flame/sfx_layer.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/map_fixture.dart';

/// A sink that records what was asked to play, for assertions on cue order,
/// volume and coalescing without an audio platform.
class _RecordingSink implements SfxSink {
  final List<({String cue, double volume})> plays = [];

  @override
  void play(String cue, double volume) => plays.add((cue: cue, volume: volume));
}

LevelEvent _event(LevelEventKind kind) =>
    LevelEvent(kind, const WorldPoint(100, 100));

UpTowerDefenseGame _game({
  required bool enabled,
  SfxSink? sink,
  double sfxVolume = 1,
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
    sfxEnabled: enabled,
    sfxVolume: sfxVolume,
    sfxSink: sink,
  );
}

void main() {
  test('every level fact has a cue file that actually ships', () {
    for (final kind in LevelEventKind.values) {
      final cue = SfxLayer.cues[kind];
      expect(cue, isNotNull, reason: '$kind has no cue mapped');
      expect(cue, endsWith('.wav'), reason: '$kind must be a shipped wav');
      expect(
        File('assets/audio/$cue').existsSync(),
        isTrue,
        reason: 'assets/audio/$cue is missing from the bundle',
      );
      expect(
        SfxLayer.volumes[kind],
        isNotNull,
        reason: '$kind has no volume mapped',
      );
      expect(SfxLayer.volumes[kind], inInclusiveRange(0.01, 1.0));
    }
  });

  test('one frame plays each kind once, no matter how many fired', () {
    final sink = _RecordingSink();
    final layer = SfxLayer(enabled: true, sink: sink);

    layer.handle([
      _event(LevelEventKind.shot),
      _event(LevelEventKind.shot),
      _event(LevelEventKind.shot),
      _event(LevelEventKind.hit),
      _event(LevelEventKind.hit),
      _event(LevelEventKind.leaked),
    ]);

    expect(
      sink.plays.map((play) => play.cue),
      ['shot.wav', 'hit.wav', 'leaked.wav'],
    );
  });

  test('a later frame plays again', () {
    final sink = _RecordingSink();
    final layer = SfxLayer(enabled: true, sink: sink);

    layer.handle([_event(LevelEventKind.shot)]);
    layer.handle([_event(LevelEventKind.shot)]);

    expect(sink.plays, hasLength(2));
  });

  test('a disabled switch never reaches the sink', () {
    final sink = _RecordingSink();
    final layer = SfxLayer(enabled: false, sink: sink);

    layer.handle([
      _event(LevelEventKind.leaked),
      _event(LevelEventKind.defeated),
    ]);

    expect(sink.plays, isEmpty);
  });

  test('a layer with no sink is silent instead of broken', () {
    final layer = SfxLayer(enabled: true);

    expect(
      () => layer.handle([_event(LevelEventKind.leaked)]),
      returnsNormally,
    );
  });

  test('rare facts are louder than the ones that fire constantly', () {
    // The leak is what the player must hear over everything else; the shot
    // is what they must not get tired of.
    expect(
      SfxLayer.volumes[LevelEventKind.leaked],
      greaterThan(SfxLayer.volumes[LevelEventKind.defeated]!),
    );
    expect(
      SfxLayer.volumes[LevelEventKind.defeated],
      greaterThan(SfxLayer.volumes[LevelEventKind.shot]!),
    );
  });

  testWidgets('the production sink fails harmlessly without an audio platform', (
    tester,
  ) async {
    // The rule is that audio failure is cosmetic. This environment has
    // bindings but no audio platform and no loadable sound, so every attempt
    // fails — and any unhandled failure in that path fails this test. Surviving
    // is the assertion.
    const FlameAudioSfxSink().play('shot.wav', 0.5);
    const FlameAudioSfxSink().play('missing.wav', 0.5);

    await tester.pump(const Duration(milliseconds: 100));
  });

  test('the player volume multiplies with each cue, never replaces it', () {
    final sink = _RecordingSink();
    final layer = SfxLayer(enabled: true, sink: sink, volume: 0.5);

    layer.handle([
      _event(LevelEventKind.shot),
      _event(LevelEventKind.leaked),
    ]);

    expect(sink.plays, hasLength(2));
    expect(
      sink.plays[0].volume,
      closeTo(SfxLayer.volumes[LevelEventKind.shot]! * 0.5, 1e-9),
    );
    expect(
      sink.plays[1].volume,
      closeTo(SfxLayer.volumes[LevelEventKind.leaked]! * 0.5, 1e-9),
    );
  });

  test('the game hands its built-in volume to the layer it builds', () {
    final loud = _game(enabled: true, sfxVolume: 0.25);
    expect(loud.sfxLayer.volume, 0.25);

    // A game built without a slider value keeps the cues at their authored
    // loudness.
    expect(_game(enabled: true).sfxLayer.volume, 1);
  });

  test('the game carries the audio switch and sink it was built with', () {
    final sink = _RecordingSink();

    final game = _game(enabled: true, sink: sink);
    game.sfxLayer.handle([_event(LevelEventKind.leaked)]);

    expect(sink.plays.single.cue, 'leaked.wav');
    expect(sink.plays.single.volume, SfxLayer.volumes[LevelEventKind.leaked]);

    // The default game (tests, or nothing wired) is silent by construction.
    final silent = _game(enabled: false);
    silent.sfxLayer.handle([_event(LevelEventKind.leaked)]);
    expect(silent.sfxLayer.enabled, isFalse);
  });
}
