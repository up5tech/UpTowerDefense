import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/data/content_catalog.dart';
import 'package:up_tower_defense/features/gameplay/data/enemy_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/level_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/map_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/tower_repository.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_event.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';

import '../helpers/stress_scenario.dart';

/// Stress frame-cost scenario (PLAN Phase 12).
///
/// Phase 12 wants a representative stress level profiled before device testing.
/// This test is that scenario in automated form: the shared stress field from
/// `stress_scenario.dart` — 23 built, maxed towers against a wave holding
/// thousands of enemies and a twelve-thousand-deep spawn queue at once. That
/// frame is the worst simulation load the rules can produce, which is what a
/// device profiler should be pointed at.
///
/// What is measured is the *simulation* half of a frame: `advance`, the only
/// work the domain does per tick. Rendering — sprites, particles, hit effects —
/// is deliberately out of scope, because it needs a real GPU and belongs to the
/// on-device profiling pass, not a widget test on a fake clock. The effect
/// layer's own costs have a companion measurement in
/// `stress_fx_cost_test.dart`, which runs the same scenario through the
/// effects half of the frame.
///
/// The assertions pin the shape of the scenario (every pad built and maxed,
/// the field actually crowded for most of the run) plus one generous average
/// frame budget. The budget carries wide headroom on purpose: wall-clock timing
/// on a shared machine is noisy, so it must only fail on order-of-magnitude
/// regressions — an accidental O(n²) scan or a per-frame allocation storm, the
/// exact bugs that show up as dropped frames on a phone. The full distribution
/// is printed on every run so a human can trend it across data and code edits.

/// Warm-up frames are simulated but not sampled: they let the crowd reach
/// density and the JIT finish compiling the hot path, so the measured window
/// reads steady-state cost rather than startup cost.
const int _warmupFrames = 600;

/// The measured window: 50 seconds of play at 60 fps. The spawn schedule below
/// lasts past the end of it, so the field never thins out mid-measurement.
const int _measuredFrames = 3000;

/// Average `advance` cost tolerated before the simulation counts as too slow.
///
/// One 60 fps frame is ~16 670µs on device; the simulation gets a quarter of
/// it (4 000µs), several times the observed cost on a development machine, so
/// only a catastrophic regression trips this rather than CI noise.
const int _averageFrameBudgetMicros = 4000;

/// A frame counts as crowded once at least this many enemies are on the field.
const int _crowdEnemyFloor = 100;

/// Share of the measured window that must stay crowded, so the printed peak
/// cannot come from a single spike while the rest of the run idles.
const double _crowdedFrameShare = 0.9;

/// Density floors for the scenario itself: below these the test is no longer
/// stressing anything and its timing number would be meaningless.
const int _minPeakEnemies = 150;
const int _minPeakProjectiles = 8;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a normal campaign level records a simulation baseline', () async {
    final repository = LevelRepository(
      mapRepository: MapRepository(),
      enemyRepository: EnemyRepository(),
      towerRepository: TowerRepository(),
    );
    final bundle = await repository.load(
      ContentCatalog.levelAssetFor('meadow_03'),
    );
    final session = LevelSession(
      level: bundle.level,
      map: bundle.map,
      enemyCatalog: bundle.enemies,
      towerCatalog: bundle.towers,
    );
    const plan = [
      ('pad_a', 'ranger'),
      ('pad_c', 'ranger'),
      ('pad_b', 'ranger'),
      ('pad_e', 'ranger'),
      ('pad_d', 'ranger'),
      ('pad_f', 'ranger'),
    ];
    final samples = <int>[];
    final watch = Stopwatch();
    var frameCount = 0;

    while (session.elapsed < 900 &&
        session.phase != LevelPhase.victory &&
        session.phase != LevelPhase.defeat) {
      if (session.towerCount < plan.length) {
        final (padId, towerId) = plan[session.towerCount];
        final definition = bundle.towers[towerId];
        if (definition != null && session.canBuildOn(padId, definition)) {
          session.buildTower(padId, definition);
        }
      } else {
        for (final (padId, _) in plan) {
          if (session.canUpgradeAt(padId)) {
            session.upgradeTowerAt(padId);
            break;
          }
        }
      }
      if (session.canStartNextWave) {
        session.startNextWave();
      }

      watch
        ..reset()
        ..start();
      session.advance(stressFrameDt);
      watch.stop();
      samples.add(watch.elapsedMicroseconds);
      session.drainEvents();
      frameCount++;
    }

    final sorted = [...samples]..sort();
    final average =
        samples.fold<int>(0, (sum, value) => sum + value) / samples.length;
    final p95 = sorted[(sorted.length * 0.95).floor()];
    final worst = sorted.last;

    // ignore: avoid_print
    print(
      'normal simulation baseline (${bundle.level.id}, ${session.phase.name}): '
      '$frameCount frames, avg ${(average / 1000).toStringAsFixed(3)}ms, '
      'p95 ${(p95 / 1000).toStringAsFixed(3)}ms, '
      'worst ${(worst / 1000).toStringAsFixed(3)}ms',
    );

    expect(session.phase, LevelPhase.victory);
    expect(frameCount, greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('a crowded late-game frame stays inside the simulation budget', () async {
    final session = await startStressSession();
    final map = session.map;

    expect(session.towerCount, map.buildPads.length);

    final watch = Stopwatch();
    for (var frame = 0; frame < _warmupFrames; frame++) {
      session.advance(stressFrameDt);
      // The game loop drains every frame; doing the same here keeps the warm-up
      // out of the measured event counts.
      session.drainEvents();
    }

    // Half the route length: enemies past it prove the crowd reaches the far
    // pads, without which the back half of the field would never fire and the
    // scenario would stress six towers while calling itself a 23-tower test.
    var routeLength = 0.0;
    for (var i = 1; i < map.route.length; i++) {
      final dx = map.route[i].x - map.route[i - 1].x;
      final dy = map.route[i].y - map.route[i - 1].y;
      routeLength += math.sqrt(dx * dx + dy * dy);
    }
    final halfRoute = routeLength / 2;

    final samples = <int>[];
    var peakEnemies = 0;
    var peakProjectiles = 0;
    var peakPendingSpawns = 0;
    var crowdedFrames = 0;
    var leftPlaying = 0;

    // Diagnostics, all sampled outside the timed section so they never pollute
    // the frame-cost numbers. Events are drained every frame exactly as the
    // game loop does, which both keeps the queue realistic and turns the shot
    // and hit counts into exact per-run facts instead of guesses.
    var totalProjectiles = 0;
    var totalPastMid = 0;
    var firedShots = 0;
    var landedHits = 0;

    // A tower counts as engaged once it appears on cooldown during the window:
    // cooldown is only ever spent by a shot, so this union over all frames is
    // exactly the set of towers that fired at least once.
    final engagedTowers = <int>{};

    for (var frame = 0; frame < _measuredFrames; frame++) {
      watch
        ..reset()
        ..start();
      session.advance(stressFrameDt);
      watch.stop();
      samples.add(watch.elapsedMicroseconds);

      final active = session.enemies.length;
      peakEnemies = math.max(peakEnemies, active);
      peakProjectiles = math.max(peakProjectiles, session.projectiles.length);
      peakPendingSpawns = math.max(peakPendingSpawns, session.pendingSpawns);
      if (active >= _crowdEnemyFloor) {
        crowdedFrames += 1;
      }
      if (session.phase != LevelPhase.playing) {
        leftPlaying += 1;
      }

      totalProjectiles += session.projectiles.length;
      for (final tower in session.towers) {
        if (tower.cooldownRemaining > 0) {
          engagedTowers.add(tower.instanceId);
        }
      }
      for (final enemy in session.enemies) {
        if (enemy.distanceAlongRoute > halfRoute) {
          totalPastMid += 1;
        }
      }
      for (final event in session.drainEvents()) {
        if (event.kind == LevelEventKind.shot) {
          firedShots += 1;
        } else if (event.kind == LevelEventKind.hit) {
          landedHits += 1;
        }
      }

      // One line every ten simulated seconds turns a mystery into a curve:
      // peaks alone cannot tell a stalled spawn queue from a kill zone.
      if (frame % 600 == 0) {
        // ignore: avoid_print
        print(
          '  t=${((frame + _warmupFrames) * stressFrameDt).toStringAsFixed(0)}s '
          'enemies=$active pending=${session.pendingSpawns} '
          'kills=${session.kills} leaks=${session.leaks} '
          'shots=$firedShots hits=$landedHits',
        );
      }
    }

    final sorted = [...samples]..sort();
    final average =
        samples.fold<int>(0, (sum, value) => sum + value) / samples.length;
    final p95 = sorted[(sorted.length * 0.95).floor()];
    final worst = sorted.last;
    final crowdedShare = crowdedFrames / _measuredFrames;

    final firingShare = landedHits / firedShots;

    // The printed distribution is the deliverable of a profiling scenario;
    // a stress test nobody can read numbers off is not a measurement.
    // ignore: avoid_print
    print(
      'stress frame cost over $_measuredFrames frames: '
      'avg ${(average / 1000).toStringAsFixed(3)}ms, '
      'p95 ${(p95 / 1000).toStringAsFixed(3)}ms, '
      'worst ${(worst / 1000).toStringAsFixed(3)}ms | '
      'peaks: $peakEnemies enemies, $peakProjectiles projectiles, '
      '$peakPendingSpawns pending spawns | '
      'crowded frames: ${(crowdedShare * 100).toStringAsFixed(1)}% | '
      'combat: $firedShots shots, $landedHits hits '
      '(${firingShare.toStringAsFixed(1)} per shot), '
      '${(totalProjectiles / _measuredFrames).toStringAsFixed(1)} shots in '
      'flight, ${engagedTowers.length}/${map.buildPads.length} towers fired, '
      '${(totalPastMid / _measuredFrames).toStringAsFixed(0)} enemies past '
      'mid-route',
    );

    expect(
      leftPlaying,
      0,
      reason:
          'the attempt left the playing phase during the window — a finished '
          'or defeated level advances nothing, so the timing would measure '
          'an idle clock instead of a crowded field',
    );
    expect(
      crowdedShare,
      greaterThanOrEqualTo(_crowdedFrameShare),
      reason:
          'only ${(crowdedShare * 100).toStringAsFixed(1)}% of the window had '
          '$_crowdEnemyFloor+ enemies; the scenario must stay crowded or the '
          'average says nothing about a worst-case frame',
    );
    expect(
      peakEnemies,
      greaterThanOrEqualTo(_minPeakEnemies),
      reason:
          'peak active enemies was $peakEnemies — the stress wave no longer '
          'produces a crowd, so re-tune the spawn groups before trusting the '
          'timing',
    );
    expect(
      peakProjectiles,
      greaterThanOrEqualTo(_minPeakProjectiles),
      reason:
          'peak in-flight projectiles was $peakProjectiles — with every pad '
          'built the field should keep a dozen shells in the air',
    );
    expect(
      average.round(),
      lessThan(_averageFrameBudgetMicros),
      reason:
          'average simulation frame cost was '
          '${(average / 1000).toStringAsFixed(3)}ms against a '
          '$_averageFrameBudgetMicrosµs budget. A jump this large is an '
          'algorithmic regression (a per-frame O(n^2) scan or allocation '
          'storm), not noise — profile LevelSession.advance before merging. '
          'On a deliberate algorithm change, re-read the printed distribution '
          'and adjust the budget in the same change.',
    );
    expect(
      peakPendingSpawns,
      greaterThan(0),
      reason: 'the spawn queue drained before the window was measured',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
