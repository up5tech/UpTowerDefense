import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_tower_defense/features/save/data/save_document.dart';
import 'package:up_tower_defense/features/save/data/save_repository.dart';

/// The repository that owns the save document.
///
/// Bootstrap loads the document before the first frame and overrides this, so
/// nothing reads storage during a build. The default throws rather than falling
/// back to memory: progress that silently stops persisting is exactly the bug
/// this provider exists to make loud.
final Provider<SaveRepository> saveRepositoryProvider =
    Provider<SaveRepository>((ref) {
      throw UnimplementedError(
        'saveRepositoryProvider must be overridden at bootstrap.',
      );
    });

/// The document loaded at bootstrap, or a fresh one on a clean install.
///
/// Campaign progress derives from this, so what the picker shows is what the
/// last session saved — the unlock rule never sees anything else.
final Provider<SaveDocument> initialSaveProvider = Provider<SaveDocument>(
  (ref) => const SaveDocument.empty(),
);

/// What the last load found, for the status line on the menu and in Settings.
final Provider<SaveLoadReport> saveStatusProvider = Provider<SaveLoadReport>(
  (ref) => const SaveLoadReport.fresh(),
);
