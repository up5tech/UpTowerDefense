import 'package:flame_audio/flame_audio.dart';
import 'package:up_tower_defense/features/gameplay/flame/sfx_layer.dart';

/// The production [SfxSink]: one-shot SFX through `flame_audio`'s shared cache.
class FlameAudioSfxSink implements SfxSink {
  const FlameAudioSfxSink();

  @override
  void play(String cue, double volume) {
    // Audio is cosmetic, so its failure is cosmetic too: a missing file, a
    // test environment with no platform player, or a device with no audio
    // service must never break the frame that reported a kill. Every failure
    // — asset load, platform channel, playback — lands in this future, which
    // discards it; gameplay never awaits sound. [FlameAudio.play] is async,
    // so nothing can throw at this call site.
    FlameAudio.play(cue, volume: volume).ignore();
  }
}
