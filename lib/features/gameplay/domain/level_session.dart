import 'dart:math' as math;

import 'package:up_tower_defense/features/gameplay/domain/endless_wave_composer.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_event.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_phase.dart';
import 'package:up_tower_defense/features/gameplay/domain/map_geometry.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/enemy_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/enemy_state.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/map_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/projectile_state.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/targeting_policy.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_instance.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_level_stats.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';
import 'package:up_tower_defense/features/gameplay/domain/targeting_system.dart';
import 'package:up_tower_defense/features/gameplay/domain/tower_build_result.dart';
import 'package:up_tower_defense/features/gameplay/domain/tower_sell_result.dart';
import 'package:up_tower_defense/features/gameplay/domain/tower_upgrade_result.dart';

// `LevelPhase` lives with its transition table; re-exported here because every
// caller that drives a level already imports the session.
export 'package:up_tower_defense/features/gameplay/domain/level_phase.dart';

/// One level attempt: the authoritative simulation for waves, enemies, leaks and
/// the core.
///
/// Plain Dart with no engine dependency. Everything advances through [advance]
/// with an explicit delta time, which is what makes the loop testable, frame-rate
/// independent, and correct when the engine is paused: no wall-clock timer is
/// ever read here.
class LevelSession {
  LevelSession({
    required this.level,
    required this.map,
    required this.enemyCatalog,
    required this.towerCatalog,
    MapGeometry? geometry,
  }) : geometry = geometry ?? MapGeometry(map),
       coreHealth = level.coreHealth,
       gold = level.startingGold;

  final LevelDefinition level;
  final MapDefinition map;
  final EnemyCatalog enemyCatalog;
  final TowerCatalog towerCatalog;
  final MapGeometry geometry;

  /// Core health remaining; clamped at zero.
  int coreHealth;

  /// Gold available to build with; integer, never negative.
  int gold;

  /// Enemies that reached the core, counted once each.
  int leaks = 0;

  /// Enemies defeated in this attempt, counted once each.
  ///
  /// A run stat for the result summary, never a rule input: the wave and reward
  /// rules read the active enemy list, not this counter.
  int kills = 0;

  /// Gold earned from kills in this attempt, before any spending.
  ///
  /// Kept separately from [gold] so the summary can report what the run paid out
  /// instead of what happens to be left in the purse.
  int goldEarned = 0;

  final List<EnemyState> _enemies = [];

  /// Membership view of [_enemies] for O(1) containment checks.
  ///
  /// Splash resolution asks "is this victim still active?" once per candidate
  /// and once per application; over a crowd of thousands a linear scan per
  /// question is what turns a burst of simultaneous blasts into the most
  /// expensive frames of a run. Every mutation funnels through [_addEnemy] and
  /// [_removeEnemy], so the two can never disagree, and iteration order —
  /// which simulation determinism depends on — stays the list's.
  final Set<EnemyState> _enemySet = {};

  final List<_ScheduledSpawn> _spawnQueue = [];
  final List<TowerInstance> _towers = [];
  final Map<String, TowerInstance> _towersByPad = {};
  final List<ProjectileState> _projectiles = [];
  final List<LevelEvent> _events = [];
  static const TargetingSystem _targeting = TargetingSystem();

  /// Adds an active enemy to the field, keeping the membership view in sync.
  void _addEnemy(EnemyState enemy) {
    _enemies.add(enemy);
    _enemySet.add(enemy);
  }

  /// Removes an enemy from the field, keeping the membership view in sync.
  ///
  /// Returns whether the enemy was actually active, so callers can fire their
  /// once-only bookkeeping (the reward, the leak) off the real list state.
  bool _removeEnemy(EnemyState enemy) {
    final removed = _enemies.remove(enemy);
    _enemySet.remove(enemy);
    return removed;
  }

  /// Slack for comparing a float cooldown against zero.
  ///
  /// Subtracting `dt` repeatedly leaves a residue like 5.5e-17 instead of
  /// exactly zero (0.7 - 0.1 * 7 > 0), which would delay every shot by a frame
  /// and change how many hits fit inside a range window. The tolerance is far
  /// below any real frame delta, so it can never fire a shot early.
  static const double _cooldownEpsilon = 1e-9;

  LevelPhase _phase = LevelPhase.ready;
  double _elapsed = 0;
  double _transitionRemaining = 0;
  int _startedWaves = 0;
  int _nextInstanceId = 0;
  int _nextTowerId = 0;
  int _nextProjectileId = 0;

  /// Simulation time elapsed since the session was created.
  double get elapsed => _elapsed;

  /// Current lifecycle phase.
  LevelPhase get phase => _phase;

  /// Whether the level is holding between a cleared wave and the next one.
  bool get isInWaveTransition => _phase == LevelPhase.waveTransition;

  /// Simulation seconds left before the next wave starts on its own; zero when
  /// the level is not in a transition.
  double get transitionRemainingSeconds => _transitionRemaining;

  /// Total wave count of the level.
  int get totalWaves => level.waves.length;

  /// How many waves have been started so far.
  int get startedWaves => _startedWaves;

  /// Active enemies, in spawn order.
  List<EnemyState> get enemies => List.unmodifiable(_enemies);

  /// Enemies scheduled but not yet spawned by the current wave.
  int get pendingSpawns => _spawnQueue.length;

  /// Towers built during this attempt, in build order.
  List<TowerInstance> get towers => List.unmodifiable(_towers);

  /// Number of towers on the field.
  int get towerCount => _towers.length;

  /// Shots currently in flight, in fire order.
  List<ProjectileState> get projectiles => List.unmodifiable(_projectiles);

  /// Level facts published since the last call, consumed by the Flame layer to
  /// draw effects and by audio to play cues.
  ///
  /// Draining (rather than exposing the list) guarantees the renderer sees each
  /// event once, while the facts themselves stay owned by the simulation.
  List<LevelEvent> drainEvents() {
    if (_events.isEmpty) {
      return const [];
    }
    final events = List<LevelEvent>.of(_events);
    _events.clear();
    return events;
  }

  /// The tower occupying [padId], or null when the pad is empty.
  TowerInstance? towerAtPad(String padId) => _towersByPad[padId];

  /// Whether [padId] already holds a tower.
  bool isPadOccupied(String padId) => _towersByPad.containsKey(padId);

  /// Whether the current wave still has enemies to spawn or on the field.
  bool get isWaveActive => _spawnQueue.isNotEmpty || _enemies.isNotEmpty;

  /// Whether the player may start another wave right now.
  ///
  /// True while the field is clear and waves remain — including during the
  /// between-waves countdown, which is how "start early" works without a second
  /// rule. Waves still never overlap: an active enemy or a pending spawn blocks
  /// the start no matter which phase the level is in.
  bool get canStartNextWave {
    if (LevelPhaseTransitions.isTerminal(_phase)) {
      return false;
    }
    // An endless run always has a next wave: it is composed from the template
    // on demand, so only an active wave or a finished attempt can refuse.
    if (!level.endless && _startedWaves >= totalWaves) {
      return false;
    }
    return !isWaveActive;
  }

  /// Starts the next wave and schedules its spawns on the simulation clock.
  ///
  /// Returns false when a wave is still active, all waves are done, or the level
  /// has ended. Starting during the between-waves countdown cuts it short, so
  /// the next wave begins immediately.
  bool startNextWave() {
    if (!canStartNextWave) {
      return false;
    }

    // Endless waves past the template are composed from it; the authored
    // waves themselves are used verbatim so the first cycles are exactly the
    // pacing the level was tuned with.
    final wave = level.endless && _startedWaves >= level.waves.length
        ? const EndlessWaveComposer().compose(
            template: level.waves,
            waveNumber: _startedWaves + 1,
            countGrowthPerCycle: level.endlessCountGrowth,
          )
        : level.waves[_startedWaves];
    _startedWaves += 1;

    for (final group in wave.groups) {
      final definition = enemyCatalog[group.enemyId];
      if (definition == null) {
        // Content validation rejects unknown ids before a level can start; this
        // guard keeps a hand-built session from crashing in developer tooling.
        continue;
      }
      for (var index = 0; index < group.count; index++) {
        _spawnQueue.add(
          _ScheduledSpawn(
            time:
                _elapsed +
                group.initialDelaySeconds +
                index * group.spawnIntervalSeconds,
            definition: definition,
          ),
        );
      }
    }
    _spawnQueue.sort((a, b) => a.time.compareTo(b.time));

    // Whichever phase asked for the wave, the countdown is over and the level is
    // playing again.
    _transitionRemaining = 0;
    _enterPhase(LevelPhase.playing);
    return true;
  }

  /// Whether building [definition] on [padId] would currently succeed.
  ///
  /// The UI uses this to disable an option; [buildTower] re-checks the same rules
  /// and is the only path that can spend gold.
  bool canBuildOn(String padId, TowerDefinition definition) {
    return _buildBlocker(padId, definition) == null;
  }

  /// Builds [definition] on [padId], spending its cost atomically.
  ///
  /// Gold is deducted only after every rule passed, so a refused build leaves the
  /// run exactly as it was. A pad holds at most one tower.
  TowerBuildResult buildTower(String padId, TowerDefinition definition) {
    final blocker = _buildBlocker(padId, definition);
    if (blocker != null) {
      return TowerBuildResult.refused(
        blocker,
        missingGold: blocker == TowerBuildBlocker.insufficientGold
            ? definition.buildCost - gold
            : 0,
      );
    }

    gold -= definition.buildCost;
    final tower = TowerInstance(
      instanceId: _nextTowerId,
      padId: padId,
      definition: definition,
      buildCost: definition.buildCost,
    );
    _nextTowerId += 1;
    _towers.add(tower);
    _towersByPad[padId] = tower;
    // An economy fact, not a combat one — but the renderer needs it the same
    // way, because the pad is where the change became visible. `_buildBlocker`
    // already proved the pad exists, hence no fallback position.
    final pad = map.padById(padId);
    if (pad != null) {
      _events.add(LevelEvent(LevelEventKind.built, pad.position));
    }
    return TowerBuildResult.built(tower);
  }

  /// Whether [padId] holds a tower that could still be upgraded.
  bool canUpgradeAt(String padId) => _upgradeBlocker(padId) == null;

  /// Upgrades the tower on [padId] to its next level, spending its cost
  /// atomically.
  ///
  /// Gold is deducted only after every rule passed, so a refused upgrade
  /// leaves the run and the tower exactly as they were.
  TowerUpgradeResult upgradeTowerAt(String padId) {
    final blocker = _upgradeBlocker(padId);
    if (blocker != null) {
      return TowerUpgradeResult.refused(blocker);
    }

    final tower = _towersByPad[padId];
    // _upgradeBlocker already rejected an empty pad, so this is non-null.
    if (tower == null) {
      return const TowerUpgradeResult.refused(TowerUpgradeBlocker.padEmpty);
    }
    final cost = tower.nextUpgradeCost;
    if (cost == null) {
      return const TowerUpgradeResult.refused(TowerUpgradeBlocker.maxLevel);
    }

    gold -= cost;
    tower
      ..investedGold += cost
      ..level += 1;
    final upgradedPad = map.padById(padId);
    if (upgradedPad != null) {
      _events.add(LevelEvent(LevelEventKind.upgraded, upgradedPad.position));
    }
    return TowerUpgradeResult.upgraded(tower, goldSpent: cost);
  }

  /// Whether the tower on [padId] can be sold right now.
  bool canSellAt(String padId) => _sellBlocker(padId) == null;

  /// Sells the tower on [padId], paying its refund and freeing the pad.
  ///
  /// The refund is the definition's rate applied to every gold ever invested
  /// in the tower (build plus upgrades), floored to an integer.
  TowerSellResult sellTowerAt(String padId) {
    final blocker = _sellBlocker(padId);
    if (blocker != null) {
      return TowerSellResult.refused(blocker);
    }
    final tower = _towersByPad[padId];
    // _sellBlocker already rejected an empty pad, so this is non-null.
    if (tower == null) {
      return const TowerSellResult.refused(TowerSellBlocker.padEmpty);
    }

    final invested = tower.investedGold;
    final refund = tower.definition.refundForInvested(invested);
    _towers.remove(tower);
    _towersByPad.remove(padId);
    gold += refund;
    return TowerSellResult.sold(
      padId: padId,
      towerDefinition: tower.definition,
      refundGold: refund,
      investedGold: invested,
    );
  }

  /// Sets which enemy the tower on [padId] prefers.
  ///
  /// Returns false when the pad holds no tower, so the UI can never report a
  /// priority change that did not happen.
  bool setTargetingPolicyAt(String padId, TargetingPolicy policy) {
    final tower = _towersByPad[padId];
    if (tower == null) {
      return false;
    }
    tower.targetingPolicy = policy;
    return true;
  }

  /// Resets this attempt to its opening state, keeping the loaded level.
  ///
  /// Restarting in place is what lets the same game, camera and HUD survive a
  /// replay. Every transient field is reset here — phase, clock, waves, spawns,
  /// enemies, towers, shots, pending combat events and run stats — so the result
  /// is indistinguishable from a freshly constructed session, which is exactly
  /// what the restart test asserts. Definitions and catalogs are untouched.
  void restart() {
    _phase = LevelPhase.ready;
    _elapsed = 0;
    _transitionRemaining = 0;
    _startedWaves = 0;
    _nextInstanceId = 0;
    _nextTowerId = 0;
    _nextProjectileId = 0;
    coreHealth = level.coreHealth;
    gold = level.startingGold;
    leaks = 0;
    kills = 0;
    goldEarned = 0;
    _enemies.clear();
    _enemySet.clear();
    _spawnQueue.clear();
    _towers.clear();
    _towersByPad.clear();
    _projectiles.clear();
    _events.clear();
  }

  /// The first rule that refuses an upgrade, or null when it would succeed.
  TowerUpgradeBlocker? _upgradeBlocker(String padId) {
    if (LevelPhaseTransitions.isTerminal(_phase)) {
      return TowerUpgradeBlocker.levelEnded;
    }
    if (map.padById(padId) == null) {
      return TowerUpgradeBlocker.unknownPad;
    }
    final tower = _towersByPad[padId];
    if (tower == null) {
      return TowerUpgradeBlocker.padEmpty;
    }
    if (tower.isMaxLevel) {
      return TowerUpgradeBlocker.maxLevel;
    }
    final cost = tower.nextUpgradeCost;
    if (cost == null || gold < cost) {
      return TowerUpgradeBlocker.insufficientGold;
    }
    return null;
  }

  /// The first rule that refuses a sell, or null when it would succeed.
  TowerSellBlocker? _sellBlocker(String padId) {
    if (LevelPhaseTransitions.isTerminal(_phase)) {
      return TowerSellBlocker.levelEnded;
    }
    if (map.padById(padId) == null) {
      return TowerSellBlocker.unknownPad;
    }
    if (_towersByPad[padId] == null) {
      return TowerSellBlocker.padEmpty;
    }
    return null;
  }

  /// The first rule that refuses a build, or null when it would succeed.
  TowerBuildBlocker? _buildBlocker(String padId, TowerDefinition definition) {
    if (LevelPhaseTransitions.isTerminal(_phase)) {
      return TowerBuildBlocker.levelEnded;
    }
    if (map.padById(padId) == null) {
      return TowerBuildBlocker.unknownPad;
    }
    if (_towersByPad.containsKey(padId)) {
      return TowerBuildBlocker.padOccupied;
    }
    if (!definition.isAffordableWith(gold)) {
      return TowerBuildBlocker.insufficientGold;
    }
    return null;
  }

  /// Advances the simulation by [dt] seconds of simulation time.
  ///
  /// Ignores non-positive or non-finite deltas. `ready`, `victory` and `defeat`
  /// consume nothing, so a late frame from a host that outlives the attempt can
  /// never move a finished or not-yet-started level; the between-waves countdown
  /// is the only thing that runs outside `playing`.
  void advance(double dt) {
    if (!dt.isFinite || dt <= 0) {
      return;
    }

    switch (_phase) {
      case LevelPhase.ready:
      case LevelPhase.victory:
      case LevelPhase.defeat:
        return;
      case LevelPhase.waveTransition:
        _advanceWaveTransition(dt);
        return;
      case LevelPhase.playing:
        break;
    }

    _elapsed += dt;

    // Enemies that were already on the field advance for the whole frame; ones
    // spawned part-way through the frame are placed at their exact progress and
    // skip this frame's movement, so spawn timing never gains a free step.
    final previouslyActive = List<EnemyState>.of(_enemies);
    _spawnDueEnemies();
    for (final enemy in previouslyActive) {
      if (_phase != LevelPhase.playing) {
        break;
      }
      _advanceEnemy(enemy, dt);
    }

    // Combat runs only while the level is still playable: a defeat during the
    // movement pass freezes the field exactly where it stood.
    if (_phase == LevelPhase.playing) {
      _combatStep(dt);
    }

    _evaluateWaveCompletion();
  }

  /// Removes a defeated enemy, pays its reward and re-evaluates wave completion.
  ///
  /// Combat (Phase 5) calls this after damage resolution; tests use it to model
  /// kills before attacks exist. Removing the enemy first makes the reward and
  /// the wave bookkeeping happen exactly once per enemy.
  void reportEnemyDefeated(EnemyState enemy) {
    final removed = _removeEnemy(enemy);
    if (!removed) {
      return;
    }
    final position = geometry.pointAtDistance(enemy.distanceAlongRoute);
    enemy.resolved = true;
    kills += 1;
    gold += enemy.definition.rewardGold;
    goldEarned += enemy.definition.rewardGold;
    _events.add(LevelEvent(LevelEventKind.defeated, position));
    _evaluateWaveCompletion();
  }

  /// Advances targeting, cooldowns and every shot in flight by [dt].
  ///
  /// Called once per frame from [advance] while the level is playing. Firing
  /// happens before flight so a shot built this frame still moves this frame,
  /// and each phase re-checks the phase because a kill can end the level
  /// mid-step.
  void _combatStep(double dt) {
    for (final tower in _towers) {
      if (_phase != LevelPhase.playing) {
        return;
      }
      tower.cooldownRemaining = math.max(0, tower.cooldownRemaining - dt);
      if (tower.cooldownRemaining > _cooldownEpsilon) {
        continue;
      }

      final pad = map.padById(tower.padId);
      if (pad == null) {
        continue;
      }
      final target = _targeting.acquire(
        geometry: geometry,
        origin: pad.position,
        range: tower.stats.range,
        enemies: _enemies,
        policy: tower.targetingPolicy,
      );
      if (target == null) {
        // No target means no shot and no cooldown spent: the tower keeps
        // waiting rather than firing at nothing.
        continue;
      }

      _fire(tower, pad.position, target);
      // The cooldown comes from the *current* level's stats: charging the
      // definition's base value would make an upgrade buy damage and range but
      // never a faster shot.
      tower.cooldownRemaining = tower.stats.fireCooldownSeconds;
    }

    for (final projectile in List<ProjectileState>.of(_projectiles)) {
      if (_phase != LevelPhase.playing) {
        break;
      }
      _advanceProjectile(projectile, dt);
    }
  }

  void _fire(
    TowerInstance tower,
    WorldPoint origin,
    EnemyState target,
  ) {
    final stats = tower.stats;
    _projectiles.add(
      ProjectileState(
        instanceId: _nextProjectileId,
        towerInstanceId: tower.instanceId,
        position: origin,
        destination: geometry.pointAtDistance(target.distanceAlongRoute),
        target: target,
        speed: stats.projectileSpeed,
        damage: stats.damage,
        splashRadius: stats.splashRadius,
        slow: stats.slow,
        colorValue: tower.definition.colorValue,
      ),
    );
    _nextProjectileId += 1;
    _events.add(LevelEvent(LevelEventKind.shot, origin));
  }

  /// Moves one shot towards its destination and resolves the hit on arrival.
  ///
  /// A shot whose target was resolved meanwhile keeps flying to the last known
  /// position and expires there without effect, so a kill can never leave a
  /// dangling reference behind.
  void _advanceProjectile(ProjectileState projectile, double dt) {
    final target = projectile.target;
    final live = !target.resolved && target.health > 0;
    if (live) {
      projectile.destination = geometry.pointAtDistance(
        target.distanceAlongRoute,
      );
    }

    final dx = projectile.destination.x - projectile.position.x;
    final dy = projectile.destination.y - projectile.position.y;
    final distance = math.sqrt(dx * dx + dy * dy);
    final step = projectile.speed * dt;
    // Contact distance includes the target's body, so a shot disappears where
    // it visually meets the enemy instead of at its centre point.
    final contact = live ? target.definition.radius : 0.0;

    if (distance <= contact || step >= distance) {
      _projectiles.remove(projectile);
      if (live) {
        _resolveHit(projectile);
      }
      return;
    }

    projectile.position = WorldPoint(
      projectile.position.x + dx / distance * step,
      projectile.position.y + dy / distance * step,
    );
  }

  /// The single path damage takes: clamps health at zero and dispatches death
  /// exactly once, through [reportEnemyDefeated], which pays the reward.
  void _applyDamage(EnemyState enemy, double damage) {
    if (enemy.resolved || !_enemySet.contains(enemy)) {
      return;
    }
    // A chilled target takes the hit plus its chill amplifier. Reading the
    // enemy's current state here keeps amplification inside the single damage
    // path, so direct shots, splash and future effects can never disagree —
    // and an expired chill stops amplifying without any extra bookkeeping.
    final amp = enemy.isSlowed ? enemy.slowDamageAmp : 0.0;
    final total = damage * (1 + amp);
    enemy.health = math.max(0, enemy.health - total);
    if (enemy.health > 0) {
      return;
    }
    reportEnemyDefeated(enemy);
  }

  /// Resolves a landed shot: damage (plus splash), then its slow, to exactly
  /// the enemies caught in the impact.
  ///
  /// Victims are collected before anything is applied, so a kill in the middle
  /// of the loop cannot change which enemies the blast reaches. Splash is
  /// centre-to-centre with the boundary included and damage never falls off,
  /// which is what "exactly the enemies inside the radius" means in the rules.
  void _resolveHit(ProjectileState projectile) {
    final hitPoint = projectile.destination;
    final victims = <EnemyState>[];

    if (!projectile.target.resolved && _enemySet.contains(projectile.target)) {
      victims.add(projectile.target);
    }

    final splashRadius = projectile.splashRadius;
    if (splashRadius > 0) {
      // Broad phase first: the blast can only reach enemies whose own route
      // segment comes within the radius of the impact, so every stretch of
      // route the mask rejects is skipped without computing a position — the
      // per-candidate cost drops from a segment walk plus a square root to a
      // handful of comparisons. The exact test below still decides every
      // victim, so the mask can only discard candidates it would have
      // rejected anyway (a position always lies on its own segment).
      final reachable = geometry.reachableSegments(hitPoint, splashRadius);
      // No copy: nothing in this loop mutates the enemy list — victims are
      // collected first and damaged only after the scan completes.
      for (final enemy in _enemies) {
        if (identical(enemy, projectile.target)) {
          continue;
        }
        if (!reachable[geometry.segmentIndexAtDistance(
          enemy.distanceAlongRoute,
        )]) {
          continue;
        }
        final position = geometry.pointAtDistance(enemy.distanceAlongRoute);
        if (position.distanceTo(hitPoint) <= splashRadius) {
          victims.add(enemy);
        }
      }
    }

    _events.add(
      LevelEvent(
        LevelEventKind.hit,
        hitPoint,
        // The blast size travels with the fact, so the effect ring is exactly
        // the radius the damage rule used.
        radius: splashRadius,
      ),
    );

    final slow = projectile.slow;
    for (final victim in victims) {
      _applyDamage(victim, projectile.damage);
      if (slow != null && !victim.resolved) {
        _applySlow(victim, slow);
      }
      if (_phase != LevelPhase.playing) {
        break;
      }
    }
  }

  /// Applies a slow with the strongest-wins refresh rule.
  ///
  /// A hit that is weaker than the active slow is ignored outright — it does
  /// not refresh the timer either — so a weak tower cannot piggy-back a strong
  /// slow forever. An equal or stronger hit replaces the magnitude, takes its
  /// own speed floor, and buys the full duration again. Stacking is therefore
  /// impossible by construction: the enemy carries exactly one slow.
  void _applySlow(EnemyState enemy, SlowSpec slow) {
    // Gate on the *active* chill: a stored magnitude whose timer already ran
    // out is not a slow anymore, so it must not keep rejecting weaker hits —
    // otherwise one expired level-3 frost chill (0.6) would block every weaker
    // frost (0.4, 0.5) from ever landing again on that enemy.
    if (enemy.isSlowed && slow.magnitude < enemy.slowMagnitude) {
      return;
    }
    enemy
      ..slowMagnitude = slow.magnitude
      ..slowMinSpeedRatio = slow.minSpeedRatio
      ..slowDamageAmp = slow.damageAmp
      ..slowRemainingSeconds = slow.durationSeconds;
  }

  void _spawnDueEnemies() {
    while (_spawnQueue.isNotEmpty && _spawnQueue.first.time <= _elapsed) {
      final spawn = _spawnQueue.removeAt(0);
      final activeFor = math.max(0.0, _elapsed - spawn.time);
      _addEnemy(
        EnemyState(
          instanceId: _nextInstanceId,
          definition: spawn.definition,
          distanceAlongRoute: spawn.definition.speed * activeFor,
        ),
      );
      _nextInstanceId += 1;
    }
  }

  void _advanceEnemy(EnemyState enemy, double dt) {
    // Status effects expire in simulation time, so pause and game speed move
    // them together with everything else.
    if (enemy.slowRemainingSeconds > 0) {
      enemy.slowRemainingSeconds = math.max(0, enemy.slowRemainingSeconds - dt);
    }

    final routeLength = geometry.routeLength;
    if (routeLength <= 0) {
      return;
    }

    enemy.distanceAlongRoute += enemy.currentSpeed * dt;
    if (enemy.distanceAlongRoute < routeLength) {
      return;
    }

    // Reaching the end is the only way to leak, and removal from the active list
    // makes it happen exactly once per enemy.
    _removeEnemy(enemy);
    enemy.resolved = true;
    leaks += 1;
    coreHealth = math.max(0, coreHealth - enemy.definition.coreDamageOnLeak);
    // The core took damage: published at the core, so the effect layer marks
    // exactly where the defence broke. Removal above already guarantees this
    // fires once per leaking enemy.
    _events.add(LevelEvent(LevelEventKind.leaked, map.core));

    if (coreHealth == 0) {
      _enterPhase(LevelPhase.defeat);
    }
  }

  void _evaluateWaveCompletion() {
    if (_phase != LevelPhase.playing) {
      return;
    }
    if (isWaveActive) {
      return;
    }
    // Victory is a campaign concept: an endless run clears one wave and
    // starts the next forever (D62), so it never enters this branch — the
    // transition below is its only "field is clear" outcome.
    if (!level.endless && _startedWaves >= totalWaves) {
      _enterPhase(LevelPhase.victory);
      return;
    }

    // The field is clear and waves remain: hold a visible countdown so the
    // player can spend a kill reward or change a priority, and let the next
    // wave arrive on its own. Every shot in flight is inert now — its target is
    // resolved — so the field is cleared rather than left with stale bullets.
    _enterPhase(LevelPhase.waveTransition);
    _transitionRemaining = level.waveTransitionSeconds;
    _projectiles.clear();
  }

  /// Counts down the between-waves pause and starts the next wave when it ends.
  ///
  /// The countdown is simulation time, so a pause freezes it and 2x runs it at
  /// double speed like everything else. Starting early goes through
  /// [startNextWave], which clears the remaining time.
  void _advanceWaveTransition(double dt) {
    _transitionRemaining -= dt;
    if (_transitionRemaining > 0) {
      return;
    }
    _transitionRemaining = 0;
    startNextWave();
  }

  /// Moves to [next], rejecting transitions the state machine does not allow.
  ///
  /// The assert is the contract: in debug and in tests an illegal move fails
  /// loudly here instead of leaving a level in a phase that can never progress.
  /// Terminal phases also drop the field, so a finished attempt holds no spawns
  /// and no shots no matter which rule ended it.
  void _enterPhase(LevelPhase next) {
    if (_phase == next) {
      return;
    }
    assert(
      LevelPhaseTransitions.isLegal(_phase, next),
      'illegal level transition $_phase -> $next',
    );
    _phase = next;

    if (LevelPhaseTransitions.isTerminal(next)) {
      _transitionRemaining = 0;
      _spawnQueue.clear();
      // A finished level freezes the field: shots in flight can no longer
      // affect anything, and leaving them would render stale bullets.
      _projectiles.clear();
    }
  }
}

/// A spawn waiting for its simulation time.
class _ScheduledSpawn {
  const _ScheduledSpawn({required this.time, required this.definition});

  final double time;
  final EnemyDefinition definition;
}
