import 'package:flutter_riverpod/misc.dart';
import 'package:up_tower_defense/features/save/application/save_providers.dart';
import 'package:up_tower_defense/features/save/data/in_memory_save_store.dart';
import 'package:up_tower_defense/features/save/data/save_repository.dart';
import 'package:up_tower_defense/features/settings/data/in_memory_settings_store.dart';

/// An override that gives a bare test scope a working, isolated save.
///
/// `pumpApp` wires a real repository already; this is for the smaller harnesses
/// that build their own `ProviderScope` or `ProviderContainer`. Without it every
/// recorded result hits the provider's deliberate "not overridden" failure —
/// caught and logged, but noisy enough to bury a real failure in the output.
Override isolatedSaveOverride() {
  final repository = SaveRepository(
    store: InMemorySaveStore(),
    legacySettings: InMemorySettingsStore(),
  );
  return saveRepositoryProvider.overrideWithValue(repository);
}
