import 'package:flame_audio/flame_audio.dart';

/// Where the background loop goes when the music switch changes.
///
/// Production routes to `flame_audio`'s global background-music player; tests
/// supply a recording fake, so the controller's rules are plain Dart with no
/// audio platform anywhere near them.
abstract interface class MusicSink {
  /// Prepares playback and the audio package's app-lifecycle observer.
  Future<void> initialize();

  /// Starts [track] looping at [volume], replacing whatever played before.
  Future<void> start(String track, double volume);

  /// Stops the loop, if one is playing.
  Future<void> stop();

  /// Changes loudness on the running loop.
  Future<void> setVolume(double volume);
}

/// The production [MusicSink], on top of `flame_audio`'s global background
/// music player (`FlameAudio.bgm`).
class FlameAudioMusicSink implements MusicSink {
  const FlameAudioMusicSink();

  /// Registers the package's own lifecycle observer alongside the player: it
  /// pauses the loop while the app is backgrounded and resumes it on return,
  /// so this layer never sees an app-lifecycle event.
  @override
  Future<void> initialize() => FlameAudio.bgm.initialize();

  @override
  Future<void> start(String track, double volume) =>
      FlameAudio.bgm.play(track, volume: volume);

  @override
  Future<void> stop() => FlameAudio.bgm.stop();

  @override
  Future<void> setVolume(double volume) =>
      FlameAudio.bgm.audioPlayer.setVolume(volume);
}

/// Keeps the one background loop in step with the music switch.
///
/// The loop is app-wide — one track under the menus and the levels alike — so
/// the shell owns it rather than any screen, and the switch decides everything:
/// booting with music off never touches playback, and flipping it off mid-song
/// stops it immediately. In-game pause is a choice about the *simulation* and
/// deliberately leaves the music playing; only app-backgrounding stops it,
/// which the audio package handles.
///
/// Every sink call is fire-and-forget: music is cosmetic, so a device with no
/// audio platform loses the loop, never the widget tree — the same rule the
/// gameplay SFX sink follows.
class MusicController {
  MusicController({required this.sink});

  final MusicSink sink;

  /// The shipped loop, under `assets/audio/`.
  static const String trackName = 'music.mp3';

  bool? _enabled;
  bool _started = false;
  double musicVolume = 1;

  /// Brings playback in line with the music switch.
  ///
  /// Repeating the current value does nothing, so a rebuild or a second call
  /// cannot double-start the track.
  void setEnabled({required bool enabled}) {
    if (_enabled == enabled) {
      return;
    }
    _enabled = enabled;

    if (!enabled) {
      if (_started) {
        _started = false;
        sink.stop().ignore();
      }
      return;
    }

    _started = true;
    // Initialize is idempotent in the package; it is awaited by `start` on the
    // audio side regardless, so issuing both here keeps boot one step.
    sink.initialize().ignore();
    sink.start(trackName, musicVolume).ignore();
  }

  /// Sets the loop's loudness, live while it plays and remembered until it
  /// starts.
  ///
  /// The player chose this value on the slider, so nothing clamps it here —
  /// the settings layer already guarantees 0..1.
  void setVolume(double volume) {
    if (musicVolume == volume) {
      return;
    }
    musicVolume = volume;
    if (_started) {
      sink.setVolume(volume).ignore();
    }
  }
}
