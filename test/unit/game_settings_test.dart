import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/settings/domain/game_settings.dart';

void main() {
  test('defaults enable audio and haptics and keep reduced motion off', () {
    expect(GameSettings.defaults.musicEnabled, isTrue);
    expect(GameSettings.defaults.sfxEnabled, isTrue);
    expect(GameSettings.defaults.hapticsEnabled, isTrue);
    expect(GameSettings.defaults.reducedMotion, isFalse);
  });

  test('copyWith replaces only the named field', () {
    final updated = GameSettings.defaults.copyWith(musicEnabled: false);

    expect(updated.musicEnabled, isFalse);
    expect(updated.sfxEnabled, GameSettings.defaults.sfxEnabled);
    expect(updated.hapticsEnabled, GameSettings.defaults.hapticsEnabled);
    expect(updated.reducedMotion, GameSettings.defaults.reducedMotion);
    expect(GameSettings.defaults.musicEnabled, isTrue);
  });

  test('snapshots with the same values are equal and share a hash', () {
    final a = GameSettings.defaults.copyWith(sfxEnabled: false);
    final b = GameSettings.defaults.copyWith(sfxEnabled: false);
    const c = GameSettings.defaults;

    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
    expect(a, isNot(equals(c)));
  });
}
