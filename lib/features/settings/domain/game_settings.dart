import 'package:meta/meta.dart';

/// Player preferences that are not part of campaign progress.
///
/// Immutable so the settings screen can compare snapshots before persisting and
/// so widgets rebuild only when a value actually changed. Language arrives
/// with localisation in a later phase.
@immutable
class GameSettings {
  const GameSettings({
    required this.musicEnabled,
    required this.sfxEnabled,
    required this.musicVolume,
    required this.sfxVolume,
    required this.hapticsEnabled,
    required this.reducedMotion,
    required this.tutorialSeen,
  });

  /// First-launch defaults, used when stored values are missing or invalid.
  static const GameSettings defaults = GameSettings(
    musicEnabled: true,
    sfxEnabled: true,
    musicVolume: 1,
    sfxVolume: 1,
    hapticsEnabled: true,
    reducedMotion: false,
    tutorialSeen: false,
  );

  /// Background music toggle.
  final bool musicEnabled;

  /// Sound-effects toggle.
  final bool sfxEnabled;

  /// Background music loudness, 0..1 — a full slider at the default.
  final double musicVolume;

  /// Sound-effects loudness, 0..1, scaling every cue the level plays.
  final double sfxVolume;

  /// Haptic feedback toggle, where the device supports it.
  final bool hapticsEnabled;

  /// Reduces large motion effects for players who prefer it.
  final bool reducedMotion;

  /// Whether the first-level tutorial has already been dismissed.
  ///
  /// Lives with the preferences rather than in campaign progress: it is a fact
  /// about this player's session with the app, not a result, so resetting the
  /// campaign (D43) does not bring the card back to somebody who just asked to
  /// start over.
  final bool tutorialSeen;

  GameSettings copyWith({
    bool? musicEnabled,
    bool? sfxEnabled,
    double? musicVolume,
    double? sfxVolume,
    bool? hapticsEnabled,
    bool? reducedMotion,
    bool? tutorialSeen,
  }) {
    return GameSettings(
      musicEnabled: musicEnabled ?? this.musicEnabled,
      sfxEnabled: sfxEnabled ?? this.sfxEnabled,
      musicVolume: musicVolume ?? this.musicVolume,
      sfxVolume: sfxVolume ?? this.sfxVolume,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      tutorialSeen: tutorialSeen ?? this.tutorialSeen,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is GameSettings &&
        other.musicEnabled == musicEnabled &&
        other.sfxEnabled == sfxEnabled &&
        other.musicVolume == musicVolume &&
        other.sfxVolume == sfxVolume &&
        other.hapticsEnabled == hapticsEnabled &&
        other.reducedMotion == reducedMotion &&
        other.tutorialSeen == tutorialSeen;
  }

  @override
  int get hashCode => Object.hash(
    musicEnabled,
    sfxEnabled,
    musicVolume,
    sfxVolume,
    hapticsEnabled,
    reducedMotion,
    tutorialSeen,
  );

  @override
  String toString() =>
      'GameSettings(music: $musicEnabled @ $musicVolume, '
      'sfx: $sfxEnabled @ $sfxVolume, haptics: $hapticsEnabled, '
      'reducedMotion: $reducedMotion, tutorialSeen: $tutorialSeen)';
}
