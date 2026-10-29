import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_tower_defense/features/codex/data/codex_content.dart';
import 'package:up_tower_defense/features/gameplay/data/content_catalog.dart';
import 'package:up_tower_defense/features/gameplay/data/enemy_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/tower_repository.dart';

/// Bundle the codex catalogs are read from.
///
/// A seam of its own so widget tests can serve fixture catalogs instead of
/// reading real assets, the same rule the credits bundle follows.
final Provider<AssetBundle> codexBundleProvider = Provider<AssetBundle>((ref) {
  return rootBundle;
});

/// The tower and enemy catalogs the codex explains.
///
/// Loaded when the screen opens and kept per container, so revisiting the codex
/// does not re-read the files but a relaunched app does.
///
/// `retry` is disabled deliberately: Riverpod 3 retries a failed future up to
/// ten times with backoff, which would hold the screen on "Loading" for the
/// better part of a minute. A bundled file that cannot be read is a broken
/// build, never a transient failure, so it should surface as an error the
/// moment it happens — the same rule as the credits document.
final FutureProvider<CodexContent> codexContentProvider =
    FutureProvider<CodexContent>((ref) async {
      // Constructed with the seam bundle rather than taken from the content
      // providers: those bind `rootBundle` directly, and the codex needs the
      // same test override credits enjoy.
      final bundle = ref.watch(codexBundleProvider);
      final towers = await TowerRepository(bundle: bundle).load(
        ContentCatalog.towers,
      );
      final enemies = await EnemyRepository(bundle: bundle).load(
        ContentCatalog.enemies,
      );
      return CodexContent(towers: towers, enemies: enemies);
    }, retry: (retryCount, error) => null);
