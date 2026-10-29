import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:up_tower_defense/features/gameplay/application/level_controller.dart';
import 'package:up_tower_defense/features/gameplay/application/map_selection.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/map_definition.dart';
import 'package:up_tower_defense/features/gameplay/flame/enemy_layer.dart';
import 'package:up_tower_defense/features/gameplay/flame/fx_layer.dart';
import 'package:up_tower_defense/features/gameplay/flame/haptics_layer.dart';
import 'package:up_tower_defense/features/gameplay/flame/map_component.dart';
import 'package:up_tower_defense/features/gameplay/flame/projectile_layer.dart';
import 'package:up_tower_defense/features/gameplay/flame/sfx_layer.dart';
import 'package:up_tower_defense/features/gameplay/flame/tower_layer.dart';

/// The Flame game for one level attempt.
///
/// The camera uses the map's own world dimensions at a fixed resolution, so the
/// playfield is identical in world units on every device; the viewport
/// letterboxes off-ratio screens instead of stretching the map.
///
/// The game advances the [LevelController] and draws what the session reports
/// (map, towers, enemies, ranges). It never decides spawns, movement, build
/// validity, damage or outcomes itself (ADR 0001).
class UpTowerDefenseGame extends FlameGame {
  UpTowerDefenseGame({
    required this.controller,
    required this.selection,
    bool reducedMotion = false,
    bool sfxEnabled = false,
    double sfxVolume = 1,
    SfxSink? sfxSink,
    bool hapticsEnabled = false,
    HapticsSink? hapticsSink,
  }) : fxLayer = FxLayer(reducedMotion: reducedMotion),
       sfxLayer = SfxLayer(
         enabled: sfxEnabled,
         sink: sfxSink,
         volume: sfxVolume,
       ),
       hapticsLayer = HapticsLayer(
         enabled: hapticsEnabled,
         sink: hapticsSink,
       ),
       super(
         camera: CameraComponent.withFixedResolution(
           width: controller.session.map.worldWidth,
           height: controller.session.map.worldHeight,
         ),
       );

  /// Authoritative simulation plus the HUD snapshot it publishes.
  final LevelController controller;

  /// Pad selection shared with the Flutter HUD.
  final MapSelection selection;

  /// Largest delta the simulation accepts in one frame.
  ///
  /// A long frame (lifecycle hiccup, debugger pause) is clamped so enemies cannot
  /// teleport past towers or a whole wave arrive at once; the loop deliberately
  /// runs slower instead of jumping. The clamp applies to real time, so at 2x a
  /// single simulation step is at most [maxFrameDelta] × 2.
  static const double maxFrameDelta = 0.1;

  /// Set once the owning [GameWidget] has disposed this instance, so tests can
  /// prove that leaving the screen releases the game.
  bool disposed = false;

  /// Feedback effects, fed from the session's published level facts.
  final FxLayer fxLayer;

  /// Sound cues, fed from the same facts in the same frame as [fxLayer].
  final SfxLayer sfxLayer;

  /// Important-action haptics, fed from those same published facts.
  final HapticsLayer hapticsLayer;

  LevelSession get session => controller.session;

  MapDefinition get map => session.map;

  @override
  Color backgroundColor() => const Color(0xFF0B1016);

  @override
  Future<void> onLoad() async {
    // The camera is centred on world (0, 0); offset the layers so the map's own
    // coordinate space (0..width, 0..height) fills the viewport.
    final offset = Vector2(-map.worldWidth / 2, -map.worldHeight / 2);
    final size = Vector2(map.worldWidth, map.worldHeight);

    world.addAll([
      MapComponent(map: map, selection: selection)
        ..position = offset
        ..size = size.clone(),
      TowerLayer(session: session, selection: selection)
        ..position = offset
        ..size = size.clone(),
      EnemyLayer(session: session)
        ..position = offset
        ..size = size.clone(),
      ProjectileLayer(session: session)
        ..position = offset
        ..size = size.clone(),
      fxLayer
        ..position = offset
        ..size = size.clone(),
    ]);
  }

  @override
  void update(double dt) {
    final clamped = dt.clamp(0.0, maxFrameDelta);
    // The controller applies the 1x/2x multiplier and returns the delta that
    // reached the domain. Effects advance by that same delta, so a hit flash
    // lasts the same number of simulation seconds at either speed.
    final simulationDelta = controller.advance(clamped);
    super.update(simulationDelta);
    // Feedback is published after the frame's component update, so an event
    // from this frame starts at full lifetime and reaches audio/haptics once.
    final events = session.drainEvents();
    fxLayer.publish(events);
    sfxLayer.handle(events);
    hapticsLayer.handle(events);
  }

  /// Pauses or resumes the attempt.
  ///
  /// Both halves matter: the controller flag freezes the simulation for any host
  /// that keeps calling [update], and the engine pause stops the ticker, which is
  /// what freezes the effects. They are toggled together so they cannot disagree.
  void togglePause() {
    if (controller.isPaused) {
      controller.resume();
      resumeEngine();
      return;
    }
    controller.pause();
    pauseEngine();
  }

  /// Restarts the attempt and clears everything the previous run left on screen.
  ///
  /// The session resets in place, the effect layer drops its effects (they
  /// describe enemies that no longer exist) and the pad selection is cleared, so
  /// the replay starts on a clean field.
  void restartLevel() {
    controller.restart();
    fxLayer.clear();
    selection.clear();
    if (paused) {
      resumeEngine();
    }
  }

  @override
  void onDispose() {
    disposed = true;
    super.onDispose();
  }
}
