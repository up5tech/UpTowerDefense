import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:up_tower_defense/features/settings/data/in_memory_settings_store.dart';
import 'package:up_tower_defense/features/settings/data/settings_store.dart';
import 'package:up_tower_defense/features/settings/domain/game_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a second store instance reads what the first one wrote', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final first = await SharedPreferencesSettingsStore.open();
    await first.save(
      GameSettings.defaults.copyWith(musicEnabled: false, reducedMotion: true),
    );

    // A fresh instance models the next app launch: nothing is carried over in
    // memory, the values come from the preference store.
    final second = await SharedPreferencesSettingsStore.open();
    final loaded = await second.load();

    expect(loaded.musicEnabled, isFalse);
    expect(loaded.reducedMotion, isTrue);
    expect(loaded.sfxEnabled, isTrue);
    expect(loaded.hapticsEnabled, isTrue);
  });

  test('missing values fall back to defaults', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final store = await SharedPreferencesSettingsStore.open();

    expect(await store.load(), GameSettings.defaults);
  });

  test(
    'a corrupted value falls back to its default instead of throwing',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPreferencesSettingsStore.musicEnabledKey: 'not-a-bool',
        SharedPreferencesSettingsStore.musicVolumeKey: 'loud',
      });

      final store = await SharedPreferencesSettingsStore.open();
      final loaded = await store.load();

      expect(loaded.musicEnabled, GameSettings.defaults.musicEnabled);
      expect(loaded, GameSettings.defaults);
    },
  );

  test('channel volumes survive a save → load across instances', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final writer = await SharedPreferencesSettingsStore.open();
    await writer.save(
      GameSettings.defaults.copyWith(musicVolume: 0.35, sfxVolume: 0.9),
    );

    // A fresh instance models the next launch: the sliders' positions are
    // read back from the store, not from memory.
    final reader = await SharedPreferencesSettingsStore.open();
    final loaded = await reader.load();

    expect(loaded.musicVolume, 0.35);
    expect(loaded.sfxVolume, 0.9);
  });

  test('a dismissed tutorial stays dismissed across launches', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final writer = await SharedPreferencesSettingsStore.open();
    await writer.save(GameSettings.defaults.copyWith(tutorialSeen: true));

    // The next launch must not greet a player who already sat through the
    // first-level tutorial.
    final reader = await SharedPreferencesSettingsStore.open();
    final loaded = await reader.load();

    expect(loaded.tutorialSeen, isTrue);
  });

  test('the in-memory store returns and keeps snapshots', () async {
    final store = InMemorySettingsStore();
    expect(await store.load(), GameSettings.defaults);

    final updated = GameSettings.defaults.copyWith(hapticsEnabled: false);
    await store.save(updated);

    expect(store.settings, updated);
    expect(await store.load(), updated);
  });
}
