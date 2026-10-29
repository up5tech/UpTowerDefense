import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:up_tower_defense/features/campaign/application/campaign_providers.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_progress.dart';
import 'package:up_tower_defense/features/save/data/save_store.dart';
import 'package:up_tower_defense/features/settings/data/in_memory_settings_store.dart';
import 'package:up_tower_defense/features/settings/domain/game_settings.dart';

import '../helpers/pump_app.dart';

void main() {
  Finder musicTile() => find.widgetWithText(SwitchListTile, 'Music');

  SwitchListTile tileOf(WidgetTester tester, Finder finder) =>
      tester.widget<SwitchListTile>(finder);

  testWidgets('toggling a preference updates the switch and saves it', (
    tester,
  ) async {
    final store = InMemorySettingsStore();
    await pumpApp(tester, store: store);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(tileOf(tester, musicTile()).value, isTrue);

    await tester.tap(musicTile());
    await tester.pumpAndSettle();

    expect(tileOf(tester, musicTile()).value, isFalse);
    expect(store.settings.musicEnabled, isFalse);
    expect(store.settings.sfxEnabled, isTrue);
  });

  testWidgets('previously saved preferences are shown when the screen opens', (
    tester,
  ) async {
    final stored = GameSettings.defaults.copyWith(
      musicEnabled: false,
      reducedMotion: true,
    );
    final store = InMemorySettingsStore(stored);

    await pumpApp(tester, store: store, settings: stored);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(tileOf(tester, musicTile()).value, isFalse);
    final reducedMotion = find.widgetWithText(SwitchListTile, 'Reduced motion');
    expect(tileOf(tester, reducedMotion).value, isTrue);
  });

  testWidgets('unrelated preferences are untouched by a single toggle', (
    tester,
  ) async {
    final store = InMemorySettingsStore();
    await pumpApp(tester, store: store);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SwitchListTile, 'Haptics'));
    await tester.pumpAndSettle();

    expect(store.settings.hapticsEnabled, isFalse);
    expect(store.settings.musicEnabled, isTrue);
    expect(store.settings.sfxEnabled, isTrue);
    expect(store.settings.reducedMotion, isFalse);
  });

  testWidgets('resetting progress asks first and keeps preferences', (
    tester,
  ) async {
    final store = InMemorySettingsStore();
    final container = await pumpApp(tester, store: store);

    container
        .read(campaignProgressProvider.notifier)
        .record(
          const LevelResult(
            levelId: 'test_level',
            stars: 3,
            coreHealth: 10,
            maxCoreHealth: 10,
            wavesCleared: 2,
            totalWaves: 2,
          ),
        );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    // Settings keeps saying where progress lives even with nothing wrong —
    // unlike the menu, which stays silent unless a load degraded.
    expect(find.text('Progress is saved on this device.'), findsOneWidget);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Music'));
    await tester.pumpAndSettle();

    // The volume sliders sit above the progress section, so the reset row
    // is below the fold on this viewport — scroll it into reach first.
    await tester.ensureVisible(find.text('Reset campaign progress'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset campaign progress'));
    await tester.pumpAndSettle();
    expect(find.text('Reset campaign progress?'), findsOneWidget);

    // Cancelling changes nothing: there is no undo after a reset.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(container.read(campaignProgressProvider).results, hasLength(1));

    await tester.tap(find.text('Reset campaign progress'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(container.read(campaignProgressProvider).results, isEmpty);
    expect(
      find.text('Nothing has been recorded on this device'),
      findsOneWidget,
    );
    // Preferences are the other half of the save and were never in scope.
    expect(store.settings.musicEnabled, isFalse);
  });

  testWidgets("a muted channel's slider is dead until its switch is on", (
    tester,
  ) async {
    final stored = GameSettings.defaults.copyWith(musicEnabled: false);
    final store = InMemorySettingsStore(stored);

    await pumpApp(tester, store: store, settings: stored);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Sliders sit under their switch: loudness for a channel that is off
    // would promise an effect the switch has already vetoed.
    final music = tester.widget<Slider>(find.byType(Slider).at(0));
    final sfx = tester.widget<Slider>(find.byType(Slider).at(1));
    expect(music.onChanged, isNull);
    expect(sfx.onChanged, isNotNull);

    await tester.tap(musicTile());
    await tester.pumpAndSettle();

    expect(
      tester.widget<Slider>(find.byType(Slider).at(0)).onChanged,
      isNotNull,
    );
  });

  testWidgets('sliders show the saved loudness and persist a new one', (
    tester,
  ) async {
    final stored = GameSettings.defaults.copyWith(musicVolume: 0.6);
    final store = InMemorySettingsStore(stored);

    await pumpApp(tester, store: store, settings: stored);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(tester.widget<Slider>(find.byType(Slider).at(0)).value, 0.6);
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);

    await tester.drag(find.byType(Slider).at(0), const Offset(80, 0));
    await tester.pumpAndSettle();

    expect(store.settings.musicVolume, greaterThan(0.6));
    expect(store.settings.musicVolume, isNot(1.0));
    // The other channel was never touched by this drag.
    expect(store.settings.sfxVolume, GameSettings.defaults.sfxVolume);
  });

  testWidgets('an unreadable save is explained, not swallowed', (
    tester,
  ) async {
    const damaged = '{"schemaVersion":2,"results":';
    SharedPreferences.setMockInitialValues(<String, Object>{
      PreferencesSaveStore.currentKey: damaged,
    });
    final save = await PreferencesSaveStore.open();

    await pumpApp(tester, saveStore: save);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Your save could not be read'), findsOneWidget);

    // Launching again must not write over the data it could not read.
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(PreferencesSaveStore.currentKey), damaged);
    expect(preferences.getString(PreferencesSaveStore.damagedKey), damaged);
  });
}
