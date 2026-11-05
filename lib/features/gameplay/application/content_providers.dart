import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_tower_defense/features/campaign/application/campaign_providers.dart';
import 'package:up_tower_defense/features/gameplay/data/content_catalog.dart';
import 'package:up_tower_defense/features/gameplay/data/difficulty_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/enemy_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/level_bundle.dart';
import 'package:up_tower_defense/features/gameplay/data/level_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/map_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/tower_repository.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/difficulty.dart';

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

/// Loads the difficulty profiles (D65).
final Provider<DifficultyRepository> difficultyRepositoryProvider =
    Provider<DifficultyRepository>((ref) => DifficultyRepository());

/// Loads levels with their map, enemy and tower references resolved.
final Provider<LevelRepository> levelRepositoryProvider =
    Provider<LevelRepository>(
      (ref) => LevelRepository(
        mapRepository: ref.watch(mapRepositoryProvider),
        enemyRepository: ref.watch(enemyRepositoryProvider),
        towerRepository: ref.watch(towerRepositoryProvider),
      ),
    );

/// Every authored difficulty profile, loaded once.
final FutureProvider<Map<Difficulty, DifficultyProfile>>
difficultyProfilesProvider = FutureProvider<Map<Difficulty, DifficultyProfile>>(
  (ref) => ref.watch(difficultyRepositoryProvider).load(),
);

/// One difficulty's profile, ready to be handed to the repository.
final difficultyProfileProvider =
    FutureProvider.family<DifficultyProfile, Difficulty>((
      ref,
      difficulty,
    ) async {
      final profiles = await ref.watch(difficultyProfilesProvider.future);
      return profiles[difficulty]!;
    });

/// Which level, on which mode, a gameplay screen is asking for.
///
/// A record rather than a level id alone: the bundle key must include the mode,
/// or a Hard replay would be served the Normal bundle that was already cached
/// (D65). It is also the route's key, so the screen that plays a level remounts
/// when the mode changes.
typedef LevelRequest = ({String levelId, Difficulty difficulty});

/// A Normal-difficulty request for [levelId].
LevelRequest normalLevelRequest(String levelId) => (
  levelId: levelId,
  difficulty: Difficulty.normal,
);

/// One campaign level, resolved into everything a session needs.
///
/// Keyed by level *and* difficulty so the level picker, a deep link and the
/// "Play" entry point all go through the same load-and-validate path, and so a
/// player can never be handed the other mode's scaled waves.
final levelBundleProvider = FutureProvider.family<LevelBundle, LevelRequest>((
  ref,
  request,
) async {
  final profile = await ref.watch(
    difficultyProfileProvider(request.difficulty).future,
  );
  return ref
      .watch(levelRepositoryProvider)
      .load(
        ContentCatalog.levelAssetFor(request.levelId),
        profile: profile,
      );
});

/// The endless challenge level, loaded like any other bundle.
///
/// Separate from [levelBundleProvider]'s campaign keying on purpose: endless
/// is its own mode with its own route, never a member of the campaign order
/// (D62). It always runs on Normal — Hard is campaign-only (D65) — and
/// validation still runs, through the same repository as a shipped level.
final FutureProvider<LevelBundle> endlessBundleProvider =
    FutureProvider<LevelBundle>((ref) {
      return ref.watch(levelRepositoryProvider).load(ContentCatalog.endless);
    });

/// Level the Play button opens: the campaign's first unfinished level on Normal.
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
      return ref.watch(levelBundleProvider(normalLevelRequest(levelId)).future);
    });
