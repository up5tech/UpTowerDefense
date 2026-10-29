import 'package:flutter/foundation.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/targeting_policy.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/tower_build_result.dart';
import 'package:up_tower_defense/features/gameplay/domain/tower_sell_result.dart';
import 'package:up_tower_defense/features/gameplay/domain/tower_upgrade_result.dart';

/// The snapshot of a level that the HUD needs.
///
/// Only coarse, event-driven values: core health, wave counts, phase, run stats
/// and the flow controls. Entity positions and per-frame state never pass
/// through here (ADR 0001). The between-waves countdown is published in whole
/// seconds on purpose, so a running transition rebuilds the HUD at most once a
/// second instead of once a frame.
@immutable
class LevelHudState {
  const LevelHudState({
    required this.coreHealth,
    required this.maxCoreHealth,
    required this.gold,
    required this.towerCount,
    required this.startedWaves,
    required this.totalWaves,
    required this.endless,
    required this.activeEnemies,
    required this.phase,
    required this.canStartWave,
    required this.kills,
    required this.leaks,
    required this.goldEarned,
    required this.transitionSecondsRemaining,
    required this.isPaused,
    required this.speed,
  });

  final int coreHealth;
  final int maxCoreHealth;

  /// Gold the player can spend right now.
  final int gold;

  /// Towers currently on the field.
  final int towerCount;

  final int startedWaves;
  final int totalWaves;

  /// Whether this attempt is the endless challenge (D62): waves have no
  /// upper bound, so the HUD shows the count reached, never a fraction.
  final bool endless;

  final int activeEnemies;
  final LevelPhase phase;
  final bool canStartWave;

  /// Enemies defeated this attempt.
  final int kills;

  /// Enemies that reached the core this attempt.
  final int leaks;

  /// Gold paid out by kills, before spending.
  final int goldEarned;

  /// Whole seconds left in the between-waves countdown; zero when not counting.
  final int transitionSecondsRemaining;

  /// Whether the player paused the attempt.
  final bool isPaused;

  /// Simulation speed multiplier: 1 or 2.
  final int speed;

  bool get isDefeated => phase == LevelPhase.defeat;

  bool get isVictorious => phase == LevelPhase.victory;

  /// Whether the attempt has ended either way.
  bool get isOver => isDefeated || isVictorious;

  /// Whether the level is holding between waves.
  bool get isInWaveTransition => phase == LevelPhase.waveTransition;

  /// Whether no wave has started yet, so the control reads "Start wave".
  bool get isReady => phase == LevelPhase.ready;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is LevelHudState &&
        other.coreHealth == coreHealth &&
        other.maxCoreHealth == maxCoreHealth &&
        other.gold == gold &&
        other.towerCount == towerCount &&
        other.startedWaves == startedWaves &&
        other.totalWaves == totalWaves &&
        other.endless == endless &&
        other.activeEnemies == activeEnemies &&
        other.phase == phase &&
        other.canStartWave == canStartWave &&
        other.kills == kills &&
        other.leaks == leaks &&
        other.goldEarned == goldEarned &&
        other.transitionSecondsRemaining == transitionSecondsRemaining &&
        other.isPaused == isPaused &&
        other.speed == speed;
  }

  @override
  int get hashCode => Object.hash(
    coreHealth,
    maxCoreHealth,
    gold,
    towerCount,
    startedWaves,
    totalWaves,
    endless,
    activeEnemies,
    phase,
    canStartWave,
    kills,
    leaks,
    goldEarned,
    transitionSecondsRemaining,
    isPaused,
    speed,
  );

  @override
  String toString() =>
      'LevelHudState(hp $coreHealth/$maxCoreHealth, ${gold}g, '
      '$towerCount towers, wave $startedWaves/$totalWaves, '
      '$activeEnemies enemies, $kills kills, $leaks leaks, '
      'transition ${transitionSecondsRemaining}s, $phase, '
      '${isPaused ? 'paused' : 'running'} at ${speed}x)';
}

/// Drives one level attempt for the gameplay screen.
///
/// The game loop calls [advance]; the HUD calls [startNextWave], [pause],
/// [resume], [toggleSpeed] and [restart], and rebuilds when the published
/// snapshot changes. Notifications are suppressed when nothing the HUD shows
/// changed, so a running level does not rebuild Flutter every frame.
///
/// Pause and speed live here rather than in the session because they describe
/// how the player watches the simulation, not what the simulation does: the
/// domain only ever receives an already-scaled delta. The pause flag is still
/// enforced on [advance] so a host that keeps ticking cannot move a paused
/// level, and the game pauses its engine as well so effects freeze too.
class LevelController extends ChangeNotifier {
  LevelController({required this.session}) : _hud = _snapshot(session);

  final LevelSession session;

  LevelHudState _hud;
  bool _paused = false;
  int _speed = 1;

  /// Latest HUD snapshot.
  LevelHudState get hud => _hud;

  /// Whether the attempt is paused.
  bool get isPaused => _paused;

  /// Simulation speed multiplier, 1 or 2.
  int get speed => _speed;

  /// Advances by [dt] of real frame time, scaled by [speed], and returns the
  /// simulation delta that actually reached the domain.
  ///
  /// The return value is what the caller passes on to anything else that must
  /// follow game speed (the effect layer), so one multiplier governs both.
  /// Returns zero while paused, which is also what freezes the effects.
  double advance(double dt) {
    if (_paused) {
      return 0;
    }
    final simulationDelta = dt * _speed;
    session.advance(simulationDelta);
    _publishIfChanged();
    return simulationDelta;
  }

  /// Starts the next wave, or cuts the between-waves countdown short.
  bool startNextWave() {
    final started = session.startNextWave();
    _publishIfChanged();
    return started;
  }

  /// Pauses the attempt; a paused level consumes no simulation time.
  void pause() {
    if (_paused) {
      return;
    }
    _paused = true;
    _publish();
  }

  /// Resumes a paused attempt.
  void resume() {
    if (!_paused) {
      return;
    }
    _paused = false;
    _publish();
  }

  /// Switches between 1x and 2x simulation speed.
  void toggleSpeed() {
    _speed = _speed == 1 ? 2 : 1;
    _publish();
  }

  /// Restarts the attempt from its opening state.
  ///
  /// Pause is cleared so a replay always starts playable; the chosen speed is a
  /// viewing preference and survives the restart.
  void restart() {
    session.restart();
    _paused = false;
    _publish();
  }

  /// Builds [definition] on [padId]; the HUD republishes only if it succeeded.
  TowerBuildResult buildTower(String padId, TowerDefinition definition) {
    final result = session.buildTower(padId, definition);
    _publishIfChanged();
    return result;
  }

  /// Upgrades the tower on [padId]; gold only changes when it succeeded.
  TowerUpgradeResult upgradeTower(String padId) {
    final result = session.upgradeTowerAt(padId);
    _publishIfChanged();
    return result;
  }

  /// Sells the tower on [padId] and pays its refund on success.
  TowerSellResult sellTower(String padId) {
    final result = session.sellTowerAt(padId);
    _publishIfChanged();
    return result;
  }

  /// Switches which enemy the tower on [padId] prefers.
  ///
  /// The priority is panel state rather than HUD state, so a successful change
  /// notifies listeners directly — a refused one never does.
  bool setTargetingPolicy(String padId, TargetingPolicy policy) {
    final changed = session.setTargetingPolicyAt(padId, policy);
    if (changed) {
      notifyListeners();
    }
    return changed;
  }

  void _publishIfChanged() {
    final next = _snapshot(session, paused: _paused, speed: _speed);
    if (next == _hud) {
      return;
    }
    _hud = next;
    notifyListeners();
  }

  void _publish() {
    _hud = _snapshot(session, paused: _paused, speed: _speed);
    notifyListeners();
  }

  static LevelHudState _snapshot(
    LevelSession session, {
    bool paused = false,
    int speed = 1,
  }) {
    return LevelHudState(
      coreHealth: session.coreHealth,
      maxCoreHealth: session.level.coreHealth,
      gold: session.gold,
      towerCount: session.towerCount,
      startedWaves: session.startedWaves,
      totalWaves: session.totalWaves,
      endless: session.level.endless,
      activeEnemies: session.enemies.length,
      phase: session.phase,
      canStartWave: session.canStartNextWave,
      kills: session.kills,
      leaks: session.leaks,
      goldEarned: session.goldEarned,
      transitionSecondsRemaining: session.transitionRemainingSeconds.ceil(),
      isPaused: paused,
      speed: speed,
    );
  }
}
