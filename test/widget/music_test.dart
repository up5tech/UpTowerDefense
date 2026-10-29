import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/settings/domain/game_settings.dart';

import '../helpers/pump_app.dart';
import '../helpers/recording_music_sink.dart';

// The background loop is app-wide, so the shell — not any screen — owns it.
// These cases pin the switch-to-playback wiring end to end through the real
// app tree, with playback recorded instead of played.
void main() {
  Finder musicTile() => find.widgetWithText(SwitchListTile, 'Music');

  testWidgets('the shell starts the loop from the saved switch', (
    tester,
  ) async {
    final sink = RecordingMusicSink();

    await pumpApp(tester, musicSink: sink);

    expect(sink.commands, contains('start:music.mp3:1.0'));
  });

  testWidgets('a fresh install with music off stays silent', (tester) async {
    final sink = RecordingMusicSink();

    await pumpApp(
      tester,
      musicSink: sink,
      settings: GameSettings.defaults.copyWith(musicEnabled: false),
    );

    expect(sink.commands, isEmpty);
  });

  testWidgets('flipping the switch in Settings mutes and resumes live', (
    tester,
  ) async {
    final sink = RecordingMusicSink();
    await pumpApp(tester, musicSink: sink);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(musicTile());
    await tester.pumpAndSettle();

    expect(sink.commands.last, 'stop');

    await tester.tap(musicTile());
    await tester.pumpAndSettle();

    expect(sink.commands, [
      'initialize',
      'start:music.mp3:1.0',
      'stop',
      'initialize',
      'start:music.mp3:1.0',
    ]);
  });

  testWidgets('moving the Music slider retunes the running loop live', (
    tester,
  ) async {
    final sink = RecordingMusicSink();
    await pumpApp(tester, musicSink: sink);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider).first, const Offset(-80, 0));
    await tester.pumpAndSettle();

    // Loudness changes on the running loop without restarting it.
    expect(sink.commands.last, startsWith('setVolume:'));
    expect(
      sink.commands.where((command) => command.startsWith('start:')),
      hasLength(1),
    );
  });
}
