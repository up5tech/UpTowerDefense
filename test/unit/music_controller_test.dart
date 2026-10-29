import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/app/audio/music_controller.dart';

import '../helpers/recording_music_sink.dart';

void main() {
  test('booting with music off never touches playback', () {
    final sink = RecordingMusicSink();
    final music = MusicController(sink: sink);

    music.setEnabled(enabled: false);

    expect(sink.commands, isEmpty);
  });

  test('switching on starts the shipped loop once', () {
    final sink = RecordingMusicSink();
    final music = MusicController(sink: sink);

    music.setEnabled(enabled: true);
    music.setEnabled(enabled: true); // A repeat changes nothing.

    expect(sink.commands, ['initialize', 'start:music.mp3:1.0']);
  });

  test('switching off stops the loop, and only once', () {
    final sink = RecordingMusicSink();
    final music = MusicController(sink: sink);

    music.setEnabled(enabled: true);
    music.setEnabled(enabled: false);
    music.setEnabled(enabled: false);

    expect(sink.commands, [
      'initialize',
      'start:music.mp3:1.0',
      'stop',
    ]);
  });

  test('re-enabling after a stop starts the loop again', () {
    final sink = RecordingMusicSink();
    final music = MusicController(sink: sink);

    music.setEnabled(enabled: true);
    music.setEnabled(enabled: false);
    music.setEnabled(enabled: true);

    expect(sink.commands, [
      'initialize',
      'start:music.mp3:1.0',
      'stop',
      'initialize',
      'start:music.mp3:1.0',
    ]);
  });

  test('a volume change reaches the playing loop, a repeat does not', () {
    final sink = RecordingMusicSink();
    final music = MusicController(sink: sink);

    music.setEnabled(enabled: true);
    sink.commands.clear();

    music.setVolume(0.3);
    music.setVolume(0.3);

    expect(sink.commands, ['setVolume:0.3']);
  });

  test('a volume change while silent only arms the next start', () {
    final sink = RecordingMusicSink();
    final music = MusicController(sink: sink);

    music.setVolume(0.2);
    music.setEnabled(enabled: true);

    expect(sink.commands, ['initialize', 'start:music.mp3:0.2']);
  });
}
