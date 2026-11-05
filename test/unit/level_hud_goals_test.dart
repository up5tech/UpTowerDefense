import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/campaign/domain/level_rating.dart';
import 'package:up_tower_defense/features/gameplay/application/level_controller.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_objective.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/map_fixture.dart';

/// The HUD's goal values are the ones stars are awarded from (D68).
///
/// `LevelHudState.objectives` is the only published goal state: the chip, the
/// pause panel, the result panel and the rating all read it. This pins that the
/// controller republishes when a goal is lost and that the star rule agrees with
/// what the HUD shows.
LevelSession _session(List<LevelObjective> objectives) {
  return LevelSession(
    level: LevelDefinition(
      id: 'hud_goals',
      displayName: 'HUD Goals',
      mapId: testMap.id,
      coreHealth: 5,
      startingGold: 150,
      waves: testLevel.waves,
      objectives: objectives,
    ),
    map: testMap,
    enemyCatalog: testEnemyCatalog,
    towerCatalog: testTowerCatalog,
  );
}

void main() {
  test('the HUD publishes the goals and republishes when one is lost', () {
    final controller = LevelController(
      session: _session(const [
        LevelObjective.noLeaks(),
        LevelObjective.maxTowers(1),
      ]),
    );
    addTearDown(controller.dispose);
    final ranger = testTowerCatalog['ranger']!;

    expect(controller.hud.objectiveCount, 2);
    expect(controller.hud.objectivesMet, 2);

    // A second tower breaks the cap; the controller republishes on the build.
    controller.buildTower('pad_a', ranger);
    controller.buildTower('pad_b', ranger);

    expect(controller.hud.objectivesMet, 1);
    expect(controller.hud.objectives.last.hasFailed, isTrue);
    // The HUD's own list awards the stars, so 2/2 is three stars and this run
    // is worth two (D68).
    expect(
      LevelRating.starsForRun(
        victorious: true,
        coreHealth: controller.hud.coreHealth,
        maxCoreHealth: controller.hud.maxCoreHealth,
        objectives: controller.hud.objectives,
      ),
      2,
    );
  });

  test('a level with no goals publishes none, keeping the 1.0 rating', () {
    final controller = LevelController(session: _session(const []));
    addTearDown(controller.dispose);

    expect(controller.hud.objectiveCount, 0);
    expect(
      LevelRating.starsForRun(
        victorious: true,
        coreHealth: 5,
        maxCoreHealth: 5,
        objectives: controller.hud.objectives,
      ),
      3,
    );
  });
}
