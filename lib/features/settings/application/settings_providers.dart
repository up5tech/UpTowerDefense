import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_tower_defense/features/save/application/save_providers.dart';
import 'package:up_tower_defense/features/settings/data/settings_store.dart';
import 'package:up_tower_defense/features/settings/domain/game_settings.dart';

/// Persistence backend for settings.
///
/// Injected by `main` (and overridden by tests); there is deliberately no
/// default implementation, because silently falling back to memory would lose
/// the player's preferences without anybody noticing.
final Provider<SettingsStore> settingsStoreProvider = Provider<SettingsStore>(
  (ref) => throw UnimplementedError(
    'settingsStoreProvider must be overridden with a concrete SettingsStore.',
  ),
);

/// Settings read once at startup, before the first frame.
///
/// Derived from the save document loaded at bootstrap, so preferences and
/// progress always come from the same load (D41); `main` overrides the
/// document itself rather than this value.
final Provider<GameSettings> initialSettingsProvider = Provider<GameSettings>(
  (ref) => ref.watch(initialSaveProvider).settings,
);

/// Current settings plus the commands the UI may issue.
final NotifierProvider<SettingsController, GameSettings> settingsProvider =
    NotifierProvider<SettingsController, GameSettings>(SettingsController.new);

/// Owns the in-memory settings snapshot and writes every change to disk.
///
/// Persistence goes through [SettingsStore], which in the shipped app is the
/// versioned save: a preference write is one document write beside progress.
/// Failures are logged rather than surfaced — a preference that failed to save
/// must not block gameplay, and the recovery message lives on the settings
/// screen.
class SettingsController extends Notifier<GameSettings> {
  @override
  GameSettings build() => ref.watch(initialSettingsProvider);

  void setMusicEnabled({required bool enabled}) {
    _apply(state.copyWith(musicEnabled: enabled));
  }

  void setSfxEnabled({required bool enabled}) {
    _apply(state.copyWith(sfxEnabled: enabled));
  }

  void setMusicVolume(double volume) {
    _apply(state.copyWith(musicVolume: volume));
  }

  void setSfxVolume(double volume) {
    _apply(state.copyWith(sfxVolume: volume));
  }

  void setHapticsEnabled({required bool enabled}) {
    _apply(state.copyWith(hapticsEnabled: enabled));
  }

  void setReducedMotion({required bool enabled}) {
    _apply(state.copyWith(reducedMotion: enabled));
  }

  /// Records that the first-level tutorial was dismissed.
  ///
  /// Not exposed as a control anywhere: dismissing is the whole interaction,
  /// and the flag exists so a player who has already seen the card is never
  /// shown it again.
  void markTutorialSeen() {
    _apply(state.copyWith(tutorialSeen: true));
  }

  /// Applies a new snapshot immediately, then persists it in the background.
  void _apply(GameSettings next) {
    if (next == state) {
      return;
    }
    state = next;
    unawaited(_persist(next));
  }

  Future<void> _persist(GameSettings settings) async {
    try {
      await ref.read(settingsStoreProvider).save(settings);
    } on Object catch (error) {
      debugPrint('Failed to persist settings, keeping session values: $error');
    }
  }
}
