import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_tower_defense/app/app.dart';
import 'package:up_tower_defense/app/lifecycle/app_orientation.dart';
import 'package:up_tower_defense/features/save/application/save_bootstrap.dart';
import 'package:up_tower_defense/features/save/application/save_providers.dart';
import 'package:up_tower_defense/features/save/data/save_backed_settings_store.dart';
import 'package:up_tower_defense/features/settings/application/settings_providers.dart';

/// Process entry point for UpTowerDefense.
///
/// Bootstrap stays minimal: open the save, inject what it found, then start the
/// shell. No gameplay rule lives here, and nothing in this path needs a network
/// connection.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppOrientation.releaseForMenu();

  final (:repository, :document, :report) = await openSave();

  runApp(
    ProviderScope(
      overrides: [
        saveRepositoryProvider.overrideWithValue(repository),
        initialSaveProvider.overrideWithValue(document),
        saveStatusProvider.overrideWithValue(report),
        // Preferences now write through the save, so the settings screen keeps
        // its old boundary while both halves persist together.
        settingsStoreProvider.overrideWithValue(
          SaveBackedSettingsStore(repository),
        ),
      ],
      child: const UpTowerDefenseApp(),
    ),
  );
}
