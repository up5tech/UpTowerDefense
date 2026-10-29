import 'package:up_tower_defense/app/audio/music_controller.dart';

/// A [MusicSink] that records commands instead of playing anything.
///
/// Widget tests boot the real shell, which now owns a background loop; this
/// keeps every one of them silent while still letting a case assert exactly
/// what the switch asked for.
class RecordingMusicSink implements MusicSink {
  final List<String> commands = [];

  @override
  Future<void> initialize() async => commands.add('initialize');

  @override
  Future<void> start(String track, double volume) async {
    commands.add('start:$track:$volume');
  }

  @override
  Future<void> stop() async => commands.add('stop');

  @override
  Future<void> setVolume(double volume) async =>
      commands.add('setVolume:$volume');
}
