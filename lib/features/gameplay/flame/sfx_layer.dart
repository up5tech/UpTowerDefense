import 'package:up_tower_defense/features/gameplay/domain/level_event.dart';

/// Where a sound cue goes when the level publishes a fact.
///
/// The production binding routes to `flame_audio`; tests supply a recording
/// fake. The interface exists so the rules for *which* cue plays and *when*
/// stay plain Dart, testable without an audio platform.
abstract interface class SfxSink {
  /// Plays [cue] — a file name under `assets/audio/` — at [volume], 0..1.
  void play(String cue, double volume);
}

/// The level's sound cues, fed from the same published [LevelEvent]s the
/// effect layer draws.
///
/// Pure presentation: nothing here can reach the simulation, and a sink that
/// fails never reaches it either (ADR 0001). Two rules shape it:
///
/// * [enabled] and [volume] are read once, when the attempt's game is built —
///   the same reason reduced motion is: the settings screen lives behind a
///   route that disposes the game, so a change always meets a fresh instance
///   rather than a stale one.
/// * Each frame's events collapse to one cue per kind: six enemies dying in
///   the same frame is one death sound, not a machine gun. Every fact is still
///   drawn; only the audio coalesces.
class SfxLayer {
  SfxLayer({required this.enabled, this.sink, this.volume = 1});

  /// Whether cues may sound at all — the persisted SFX switch.
  final bool enabled;

  /// The playback target; null means silent (tests, or no audio wired).
  final SfxSink? sink;

  /// The player's SFX loudness, 0..1, scaling every cue.
  ///
  /// It multiplies the per-kind volumes rather than replacing them: the slider
  /// chooses how loud the channel is, the map still decides what deserves to
  /// be heard over what.
  final double volume;

  /// The file each fact plays, under `assets/audio/`.
  ///
  /// Keyed by every [LevelEventKind] on purpose: a new fact must choose a cue
  /// (or consciously map one) instead of silently making no sound.
  static const Map<LevelEventKind, String> cues = {
    LevelEventKind.shot: 'shot.wav',
    LevelEventKind.hit: 'hit.wav',
    LevelEventKind.defeated: 'defeated.wav',
    LevelEventKind.leaked: 'leaked.wav',
    LevelEventKind.built: 'built.wav',
    LevelEventKind.upgraded: 'upgraded.wav',
  };

  /// Playback volume per cue, 0..1.
  ///
  /// Ordered by how often it fires: a shot plays constantly and sits quiet,
  /// while a leak is rare, matters most, and is the loudest thing in the
  /// level — the audio says "the core was hit" even in a noisy room.
  static const Map<LevelEventKind, double> volumes = {
    LevelEventKind.shot: 0.3,
    LevelEventKind.hit: 0.45,
    LevelEventKind.defeated: 0.55,
    LevelEventKind.built: 0.6,
    LevelEventKind.upgraded: 0.6,
    LevelEventKind.leaked: 0.9,
  };

  /// Plays the cues for [events]; called once per frame with the batch the
  /// simulation drained.
  void handle(List<LevelEvent> events) {
    if (!enabled) {
      return;
    }
    final sink = this.sink;
    if (sink == null) {
      return;
    }
    final played = <LevelEventKind>{};
    for (final event in events) {
      if (!played.add(event.kind)) {
        continue;
      }
      sink.play(cues[event.kind]!, volumes[event.kind]! * volume);
    }
  }
}
