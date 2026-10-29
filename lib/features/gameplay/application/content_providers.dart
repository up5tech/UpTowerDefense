import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_tower_defense/features/campaign/application/campaign_providers.dart';
import 'package:up_tower_defense/features/gameplay/data/content_catalog.dart';
import 'package:up_tower_defense/features/gameplay/data/enemy_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/level_bundle.dart';
import 'package:up_tower_defense/features/gameplay/data/level_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/map_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/tower_repository.dart';

/// Loads map definitions from bundled assets.
final Provider<MapRepository> mapRepositoryProvider = Provider<MapRepository>(
  (ref) => MapRepository(),
);

/// Loads the enemy catalog.
final Provider<EnemyRepository> enemyRepositoryProvider =
    Provider<EnemyRepository>((ref) => EnemyRepository());

/// Loads the tower catalog the player builds from.
final Provider<TowerRepository> towerRepositoryProvider =
    Provider<TowerRepository>((ref) => TowerRepository());

/// Loads levels with their map, enemy and tower references resolved.
final Provider<LevelRepository> levelRepositoryProvider =
    Provider<LevelRepository>(
      (ref) => LevelRepository(
        mapRepository: ref.watch(mapRepositoryProvider),
        enemyRepository: ref.watch(enemyRepositoryProvider),
        towerRepository: ref.watch(towerRepositoryProvider),
      ),
    );

/// One campaign level, resolved into everything a session needs.
///
/// Keyed by level id so the level picker, a deep link and the "Play" entry point
/// all go through the same load-and-validate path. The type is inferred because
/// the family class lives in Riverpod's `misc` barrel, not the app-facing one.
final levelBundleProvider = FutureProvider.family<LevelBundle, String>((
  ref,
  levelId,
) {
  return ref
      .watch(levelRepositoryProvider)
      .load(ContentCatalog.levelAssetFor(levelId));
});

/// The endless challenge level, loaded like any other bundle.
///
/// Separate from [levelBundleProvider]'s campaign keying on purpose: endless
/// is its own mode with its own route, never a member of the campaign order
/// (D62). Validation still runs — the file resolves its map, enemies and
/// towers through the same repository as a shipped level.
final FutureProvider<LevelBundle> endlessBundleProvider =
    FutureProvider<LevelBundle>((ref) {
      return ref.watch(levelRepositoryProvider).load(ContentCatalog.endless);
    });

/// Level the Play button opens: the campaign's first unfinished level.
///
/// It watches progress on purpose — finishing a level moves the campaign on, so
/// the next tap on Play opens the next level without any extra bookkeeping.
final FutureProvider<LevelBundle> levelToPlayProvider =
    FutureProvider<LevelBundle>((ref) async {
      final campaign = await ref.watch(campaignProvider.future);
      final progress = ref.watch(campaignProgressProvider);
      final levelId = progress.resumeLevelId(campaign);
      if (levelId == null) {
        throw StateError('the campaign has no levels');
      }
      return ref.watch(levelBundleProvider(levelId).future);
    });
