import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/campaign/application/achievement_providers.dart';
import 'package:up_tower_defense/features/campaign/application/campaign_providers.dart';
import 'package:up_tower_defense/features/campaign/domain/achievement.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_progress.dart';
import 'package:up_tower_defense/features/gameplay/application/daily_providers.dart';
import 'package:up_tower_defense/features/gameplay/domain/daily_challenge.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/difficulty.dart';
import 'package:up_tower_defense/features/save/application/save_providers.dart';
import 'package:up_tower_defense/features/save/data/in_memory_save_store.dart';
import 'package:up_tower_defense/features/save/data/save_repository.dart';
import 'package:up_tower_defense/features/settings/data/in_memory_settings_store.dart';

import '../helpers/content_fixtures.dart';

/// Unlocking once (D67).
///
/// `refresh` is called from the path that records a result and again when the
/// progress screen opens, so this exercises the real notifier over a real
/// repository: the saved payload must carry each id exactly once however many
/// times the facts are re-derived.
LevelResult _result({
  String levelId = 'test_level',
  int stars = 3,
  int coreHealth = 5,
  int maxCoreHealth = 5,
  Difficulty difficulty = Difficulty.normal,
}) {
  return LevelResult(
    levelId: levelId,
    stars: stars,
    coreHealth: coreHealth,
    maxCoreHealth: maxCoreHealth,
    wavesCleared: 2,
    totalWaves: 2,
    difficulty: difficulty,
    objectivesMet: stars == 0 ? 0 : stars - 1,
  );
}

Future<({ProviderContainer container, InMemorySaveStore store})>
_scope() async {
  final store = InMemorySaveStore();
  final repository = SaveRepository(
    store: store,
    legacySettings: InMemorySettingsStore(),
  );
  await repository.load();

  final container = ProviderContainer(
    overrides: [
      saveRepositoryProvider.overrideWithValue(repository),
      initialSaveProvider.overrideWithValue(repository.document),
      campaignProvider.overrideWith((ref) => testCampaign),
    ],
  );
  return (container: container, store: store);
}

/// Lets the repository's write queue drain before the payload is inspected.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 1));

List<Object?> _storedAchievements(InMemorySaveStore store) {
  final payload = jsonDecode(store.current!) as Map<String, Object?>;
  return payload['achievements']! as List<Object?>;
}

void main() {
  test('a recorded result unlocks its achievements once, not per call', () async {
    final scope = await _scope();
    addTearDown(scope.container.dispose);

    scope.container.read(campaignProgressProvider.notifier).record(_result());

    await scope.container.read(achievementsProvider.notifier).refresh();
    await _settle();
    expect(scope.container.read(achievementsProvider), {
      Achievement.firstClear,
      Achievement.untouchedCore,
      Achievement.threeStars,
    });

    final firstWrite = _storedAchievements(scope.store);
    expect(firstWrite, hasLength(3));
    expect(firstWrite.where((id) => id == 'firstClear'), hasLength(1));

    // The progress screen opens later and re-derives the same facts: nothing is
    // added, and the stored list is not written a second time with duplicates.
    await scope.container.read(achievementsProvider.notifier).refresh();
    await _settle();
    await scope.container.read(achievementsProvider.notifier).refresh();
    await _settle();

    expect(scope.container.read(achievementsProvider), hasLength(3));
    expect(_storedAchievements(scope.store), firstWrite);
  });

  test('a Hard run unlocks nothing the list says is a Normal goal', () async {
    final scope = await _scope();
    addTearDown(scope.container.dispose);

    scope.container
        .read(campaignProgressProvider.notifier)
        .record(_result(difficulty: Difficulty.hard));

    await scope.container.read(achievementsProvider.notifier).refresh();
    await _settle();

    expect(scope.container.read(achievementsProvider), isEmpty);
    expect(scope.store.current, contains('"achievements":[]'));
  });

  test(
    'a finished daily unlocks the daily achievement and is persisted',
    () async {
      final scope = await _scope();
      addTearDown(scope.container.dispose);

      scope.container
          .read(dailyResultsProvider.notifier)
          .record(
            const DailyResult(
              dateKey: 20261104,
              levelId: 'test_level',
              stars: 2,
              coreHealth: 4,
              maxCoreHealth: 5,
              objectivesMet: 1,
            ),
          );
      await Future<void>.delayed(Duration.zero);

      await scope.container.read(achievementsProvider.notifier).refresh();
      await _settle();

      expect(
        scope.container.read(achievementsProvider),
        contains(Achievement.dailyFinished),
      );
      // The daily record itself reached the document, not just the achievement.
      expect(scope.store.current, contains('"20261104"'));
    },
  );

  test('the progress view follows the same set the save holds', () async {
    final scope = await _scope();
    addTearDown(scope.container.dispose);

    scope.container.read(campaignProgressProvider.notifier).record(_result());
    await scope.container.read(achievementsProvider.notifier).refresh();
    await _settle();

    final view = scope.container.read(achievementProgressProvider);
    expect(view.count, 3);
    expect(view.ordered.take(3), [
      Achievement.firstClear,
      Achievement.untouchedCore,
      Achievement.threeStars,
    ]);
  });
}
