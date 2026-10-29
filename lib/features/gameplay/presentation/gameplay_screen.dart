import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:up_tower_defense/app/lifecycle/app_orientation.dart';
import 'package:up_tower_defense/app/routes.dart';
import 'package:up_tower_defense/features/campaign/application/campaign_providers.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_progress.dart';
import 'package:up_tower_defense/features/campaign/domain/level_rating.dart';
import 'package:up_tower_defense/features/gameplay/application/content_providers.dart';
import 'package:up_tower_defense/features/gameplay/application/endless_providers.dart';
import 'package:up_tower_defense/features/gameplay/application/level_controller.dart';
import 'package:up_tower_defense/features/gameplay/application/map_selection.dart';
import 'package:up_tower_defense/features/gameplay/data/level_bundle.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/build_pad.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/map_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/targeting_policy.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_instance.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_level_stats.dart';
import 'package:up_tower_defense/features/gameplay/flame/flame_audio_sfx_sink.dart';
import 'package:up_tower_defense/features/gameplay/flame/flutter_haptics_sink.dart';
import 'package:up_tower_defense/features/gameplay/flame/game.dart';
import 'package:up_tower_defense/features/settings/application/settings_providers.dart';

/// Hosts the Flame game for one level attempt.
///
/// Responsibilities are limited to the shell contract: load the level, lock
/// landscape, forward app-lifecycle changes to the engine, show the HUD, and leave
/// cleanly. Gameplay rules belong to the domain layer.
class GameplayScreen extends ConsumerStatefulWidget {
  const GameplayScreen({
    super.key,
    this.game,
    this.levelId,
    this.endless = false,
  });

  /// Injected game for tests. When null the screen loads the level and creates
  /// one, handing ownership to [GameWidget], which disposes it on unmount.
  final UpTowerDefenseGame? game;

  /// Campaign level to play. When null the screen opens the campaign's next
  /// unfinished level, which is what the Play button does.
  final String? levelId;

  /// Whether this screen hosts the endless challenge (D62): the level comes
  /// from [endlessBundleProvider] and the attempt records a best score instead
  /// of campaign progress.
  final bool endless;

  @override
  ConsumerState<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends ConsumerState<GameplayScreen>
    with WidgetsBindingObserver {
  MapSelection? _ownedSelection;
  LevelController? _ownedController;
  UpTowerDefenseGame? _createdGame;

  /// Whether the current attempt's result has already been recorded.
  ///
  /// One attempt records once: the flag is cleared whenever the level is no
  /// longer over, so a restart arms it again without any extra bookkeeping.
  bool _outcomeRecorded = false;

  /// Whether the attempt's victory was the first clear of that level.
  ///
  /// Captured just before the record: once progress holds the result the
  /// "just unlocked" fact is gone, and the result panel needs it to say
  /// "Unlocked: …" exactly once per level.
  bool _firstClear = false;

  UpTowerDefenseGame? get _activeGame => widget.game ?? _createdGame;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(AppOrientation.lockForGameplay());
    // An injected game is owned by the caller, so its listener is attached here;
    // an owned one is attached when the game is created.
    widget.game?.controller.addListener(_handleOutcome);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Flame pauses a backgrounded game on its own; forwarding the state here
    // keeps the rule explicit and testable, and covers any future host that is
    // not a GameWidget.
    final game = _activeGame;
    if (game == null) {
      return;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        // A player who paused before backgrounding stays paused: the system
        // resume must never override an explicit pause.
        if (!game.controller.isPaused && game.paused) {
          game.resumeEngine();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (!game.paused) {
          game.pauseEngine();
        }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(AppOrientation.releaseForMenu());
    widget.game?.controller.removeListener(_handleOutcome);
    _ownedController?.dispose();
    _ownedSelection?.dispose();
    super.dispose();
  }

  /// Records the finished attempt in campaign progress.
  ///
  /// Runs from the controller's notification, never from `build`, so progress is
  /// written once when the level actually ends. Only a victory is recorded: a
  /// defeat unlocks nothing, and keeping failed attempts out of the result map
  /// means "best result" never has to filter them out later.
  void _handleOutcome() {
    final game = _activeGame;
    if (game == null) {
      return;
    }
    final hud = game.controller.hud;
    if (!hud.isOver) {
      // A restart (or a fresh level) arms the recorder again.
      _outcomeRecorded = false;
      return;
    }
    // An endless run ends only in defeat, and what it awards is a score, not
    // an unlock: record the cleared waves and leave the campaign alone (D62).
    if (game.session.level.endless) {
      if (_outcomeRecorded || !hud.isDefeated) {
        return;
      }
      _outcomeRecorded = true;
      // The core fell on wave N, so N - 1 waves were fully cleared.
      ref.read(endlessBestProvider.notifier).recordBest(hud.startedWaves - 1);
      return;
    }

    if (_outcomeRecorded || !hud.isVictorious) {
      return;
    }
    _outcomeRecorded = true;

    final session = game.session;
    _firstClear = !ref
        .read(campaignProgressProvider)
        .isCompleted(session.level.id);
    ref
        .read(campaignProgressProvider.notifier)
        .record(
          LevelResult(
            levelId: session.level.id,
            stars: LevelRating.starsFor(
              victorious: true,
              coreHealth: hud.coreHealth,
              maxCoreHealth: hud.maxCoreHealth,
            ),
            coreHealth: hud.coreHealth,
            maxCoreHealth: hud.maxCoreHealth,
            wavesCleared: hud.startedWaves,
            totalWaves: hud.totalWaves,
          ),
        );
  }

  /// Creates the session and game once per loaded level.
  ///
  /// [GameWidget] disposes the previous game if the bundle is ever replaced, so
  /// this never leaks an engine; the controller outlives it for the screen's
  /// lifetime and is disposed in [dispose].
  UpTowerDefenseGame _gameFor(LevelBundle bundle) {
    final existing = _createdGame;
    if (existing != null) {
      return existing;
    }

    final selection = _ownedSelection ??= MapSelection();
    var controller = _ownedController;
    if (controller == null) {
      controller = LevelController(
        session: LevelSession(
          level: bundle.level,
          map: bundle.map,
          enemyCatalog: bundle.enemies,
          towerCatalog: bundle.towers,
        ),
      );
      controller.addListener(_handleOutcome);
      _ownedController = controller;
    }

    // The accessibility, audio and haptics switches are read once here: the
    // settings screen lives behind a route that disposes the game, so a change always
    // meets a fresh game instance rather than a stale one.
    final settings = ref.read(settingsProvider);
    return _createdGame = UpTowerDefenseGame(
      controller: controller,
      selection: selection,
      reducedMotion: settings.reducedMotion,
      sfxEnabled: settings.sfxEnabled,
      sfxVolume: settings.sfxVolume,
      sfxSink: const FlameAudioSfxSink(),
      hapticsEnabled: settings.hapticsEnabled,
      hapticsSink: const FlutterHapticsSink(),
    );
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.mainMenu);
  }

  /// Drops the attempt and reloads the level, used by the content-error screen.
  ///
  /// The controller is disposed with it, so a retry can never keep a session
  /// built from the bundle that failed to load.
  void _retryLevel() {
    _createdGame = null;
    _ownedController?.dispose();
    _ownedController = null;
    ref.invalidate(_bundleProvider);
  }

  /// The bundle provider for this screen: the endless level in endless mode,
  /// one level when an id was given, and otherwise the campaign's next
  /// unfinished level.
  FutureProvider<LevelBundle> get _bundleProvider => widget.endless
      ? endlessBundleProvider
      : widget.levelId == null
      ? levelToPlayProvider
      : levelBundleProvider(widget.levelId!);

  @override
  Widget build(BuildContext context) {
    // Watched for exactly one reason: recording the outcome mutates progress,
    // and that rebuild is what carries the fresh first-clear flag into the
    // result panel. It changes once per attempt, so nothing here reacts per
    // frame (the HUD's per-frame state stays in the controller).
    ref.watch(campaignProgressProvider);
    // The tutorial card belongs to the campaign's opening level and shows at
    // most once (D52): pending until the player dismisses it, and only while
    // the level being played is the one the campaign lists first.
    final tutorialPending = !ref.watch(settingsProvider).tutorialSeen;
    final definition = ref
        .watch(campaignProvider)
        .whenOrNull(data: (definition) => definition);
    final firstLevelId = definition?.levelIds.firstOrNull;

    bool showsTutorialFor(String levelId) =>
        tutorialPending && levelId == firstLevelId;

    void dismissTutorial() =>
        ref.read(settingsProvider.notifier).markTutorialSeen();

    // The unlock facts the result panel reports: the level this one opens
    // (null outside the campaign, and on the last level, which instead marks
    // the campaign complete). One rule over the same flattened order the
    // picker and the unlock check use (D33).
    ({({String id, String name})? next, bool complete}) unlockStateFor(
      String levelId,
    ) {
      final index = definition?.indexOf(levelId) ?? -1;
      if (index < 0) {
        return (next: null, complete: false);
      }
      final nextId = definition!.levelIdAt(index + 1);
      final nextName = nextId == null ? null : definition.displayNameOf(nextId);
      final next = nextId == null || nextName == null
          ? null
          : (id: nextId, name: nextName);
      return (next: next, complete: next == null);
    }

    final injected = widget.game;
    if (injected != null) {
      final unlock = unlockStateFor(injected.session.level.id);
      return _GameplayView(
        game: injected,
        onLeave: _leave,
        showTutorial: showsTutorialFor(injected.session.level.id),
        onTutorialDismissed: dismissTutorial,
        firstClear: _firstClear,
        next: unlock.next,
        campaignComplete: unlock.complete,
        endlessBest: ref.watch(endlessBestProvider),
        onNext: unlock.next == null
            ? null
            : () => context.go(AppRoutes.gameplayFor(unlock.next!.id)),
      );
    }

    return ref
        .watch(_bundleProvider)
        .when(
          data: (bundle) {
            final unlock = unlockStateFor(bundle.level.id);
            return _GameplayView(
              game: _gameFor(bundle),
              onLeave: _leave,
              showTutorial: showsTutorialFor(bundle.level.id),
              onTutorialDismissed: dismissTutorial,
              firstClear: _firstClear,
              next: unlock.next,
              campaignComplete: unlock.complete,
              endlessBest: ref.watch(endlessBestProvider),
              onNext: unlock.next == null
                  ? null
                  : () => context.go(
                      AppRoutes.gameplayFor(unlock.next!.id),
                    ),
            );
          },
          loading: () => _StatusScreen(
            title: 'Loading level',
            onLeave: _leave,
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, stackTrace) => _ContentErrorScreen(
            error: error,
            onLeave: _leave,
            onRetry: _retryLevel,
          ),
        );
  }
}

/// The playable screen: game view plus the shell overlays.
///
/// Flow controls live here and delegate straight to the game: pause, speed,
/// restart and the wave control never touch the session directly, so the same
/// rules run whether the player drives them or a test does.
class _GameplayView extends StatelessWidget {
  const _GameplayView({
    required this.game,
    required this.onLeave,
    required this.showTutorial,
    required this.onTutorialDismissed,
    this.firstClear = false,
    this.next,
    this.campaignComplete = false,
    this.onNext,
    this.endlessBest = 0,
  });

  final UpTowerDefenseGame game;
  final VoidCallback onLeave;

  /// Whether the first-level tutorial card is on screen.
  final bool showTutorial;

  /// Records the dismissal, which hides the card and every later showing.
  final VoidCallback onTutorialDismissed;

  /// Whether the victory being shown was this level's first clear — the one
  /// time the result panel may claim to have unlocked something.
  final bool firstClear;

  /// The level a victory opens, or null outside the campaign or on its end.
  final ({String id, String name})? next;

  /// Whether this level is the campaign's last (its victory completes it).
  final bool campaignComplete;

  /// Opens [next] in a fresh attempt; null when there is no next level.
  final VoidCallback? onNext;

  /// The stored endless best, so the result panel can show the record a run
  /// just challenged (0 until the first completed run).
  final int endlessBest;

  @override
  Widget build(BuildContext context) {
    final controller = game.controller;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: GameWidget<UpTowerDefenseGame>(game: game)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filledTonal(
                        onPressed: onLeave,
                        tooltip: 'Back to menu',
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 12),
                      _HudChip(label: game.session.level.displayName),
                      const SizedBox(width: 16),
                      ListenableBuilder(
                        listenable: controller,
                        builder: (context, child) {
                          final hud = controller.hud;
                          return Row(
                            children: [
                              _HudChip(
                                icon: Icons.paid_rounded,
                                label: '${hud.gold} g',
                                tint: const Color(0xFF8BF0D6),
                              ),
                              const SizedBox(width: 8),
                              _HudChip(
                                icon: Icons.favorite_rounded,
                                label: '${hud.coreHealth}/${hud.maxCoreHealth}',
                                tint: const Color(0xFFE0A34A),
                              ),
                              const SizedBox(width: 8),
                              _HudChip(
                                icon: Icons.waves_rounded,
                                label: hud.endless
                                    ? 'Wave ${hud.startedWaves}'
                                    : 'Wave '
                                          '${hud.startedWaves}/${hud.totalWaves}',
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                onPressed: hud.isOver ? null : game.togglePause,
                                tooltip: hud.isPaused ? 'Resume' : 'Pause',
                                icon: Icon(
                                  hud.isPaused
                                      ? Icons.play_arrow_rounded
                                      : Icons.pause_rounded,
                                ),
                              ),
                              const SizedBox(width: 4),
                              _SpeedButton(
                                speed: hud.speed,
                                onPressed: hud.isOver
                                    ? null
                                    : controller.toggleSpeed,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomMultiChildLayout(
              delegate: _GameplayControlsLayout(
                map: game.map,
                safeArea: MediaQuery.paddingOf(context),
              ),
              children: [
                ValueListenableBuilder<String?>(
                  valueListenable: game.selection,
                  builder: (context, selectedPadId, child) {
                    final pad = selectedPadId == null
                        ? null
                        : game.map.padById(selectedPadId);
                    if (pad == null) {
                      return LayoutId(
                        id: _GameplayControl.padPanel,
                        child: const SizedBox.shrink(),
                      );
                    }
                    return LayoutId(
                      id: _GameplayControl.padPanel,
                      child: ListenableBuilder(
                        listenable: controller,
                        builder: (context, child) {
                          return _PadPanel(
                            pad: pad,
                            session: game.session,
                            gold: controller.hud.gold,
                            onBuild: (definition) =>
                                controller.buildTower(pad.id, definition),
                            onUpgrade: () => controller.upgradeTower(pad.id),
                            onSell: () => controller.sellTower(pad.id),
                            onPriority: (policy) =>
                                controller.setTargetingPolicy(pad.id, policy),
                            onClose: game.selection.clear,
                          );
                        },
                      ),
                    );
                  },
                ),
                ListenableBuilder(
                  listenable: controller,
                  builder: (context, child) {
                    final hud = controller.hud;
                    return LayoutId(
                      id: _GameplayControl.waveButton,
                      child: hud.isOver
                          ? const SizedBox.shrink()
                          : _WaveControl(
                              hud: hud,
                              onStart: controller.startNextWave,
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
          if (showTutorial)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              // Top-centred under the HUD row: clear of the pad panel (bottom
              // left), the wave control (bottom right) and the HUD itself, so
              // the card can never intercept a tap meant for the level.
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 72, 16, 0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: _TutorialCard(onDismissed: onTutorialDismissed),
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, child) {
                final hud = controller.hud;
                if (hud.isOver) {
                  return _ResultPanel(
                    hud: hud,
                    firstClear: firstClear,
                    next: next,
                    campaignComplete: campaignComplete,
                    onNext: onNext,
                    endlessBest: endlessBest,
                    onReplay: game.restartLevel,
                    onLeave: onLeave,
                  );
                }
                if (hud.isPaused) {
                  return _PauseOverlay(
                    hud: hud,
                    onResume: game.togglePause,
                    onRestart: game.restartLevel,
                    onLeave: onLeave,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Identifies each interactive overlay laid out around the playfield.
enum _GameplayControl { padPanel, waveButton }

/// Chooses safe spots for the controls without covering an available pad.
///
/// Controls keep their familiar corners when those areas are clear. When a map
/// puts a pad there, they move to the clearest of nine edge/centre positions;
/// the wave button also avoids the build panel. The build panel keeps its
/// choices fully on screen first: once the whole menu needs the available
/// height it can no longer dodge every pad on a short landscape screen, so it
/// takes the least-covering spot instead of clipping its list.

class _GameplayControlsLayout extends MultiChildLayoutDelegate {
  _GameplayControlsLayout({required this.map, required this.safeArea});

  final MapDefinition map;
  final EdgeInsets safeArea;

  static const double _edgeInset = 16;
  static const double _hudClearance = 84;

  /// Widest the pad panel may get, and the share of the screen it may take.
  ///
  /// Wide enough that the tower details keep their chips and target controls on
  /// single rows, which is what lets the whole panel fit a landscape phone;
  /// the gameplay still stays visible around it.
  static const double _panelMaxWidth = 460;
  static const double _panelWidthFraction = 0.55;

  @override
  void performLayout(Size size) {
    final maxWidth = math.max(
      0.0,
      size.width - safeArea.horizontal - 2 * _edgeInset,
    );
    // The panel gets every pixel between the safe-area edges, so the build menu
    // and the tower details can show their whole content: a fixed fraction of
    // the screen (it used to be 30%) clips them on short landscape viewports.
    // At its preferred bottom anchor it still starts below the HUD; only a
    // panel too tall for that gap rises into the HUD strip instead of cutting
    // off its last controls.
    final maxHeight = math.max(
      0.0,
      size.height - safeArea.vertical - 2 * _edgeInset,
    );
    final maxPanelWidth = math.max(
      0.0,
      math.min(
        _panelMaxWidth,
        math.min(
          size.width * _panelWidthFraction,
          size.width - safeArea.horizontal - 2 * _edgeInset,
        ),
      ),
    );
    final constraints = BoxConstraints(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );

    final panelSize = layoutChild(
      _GameplayControl.padPanel,
      constraints.copyWith(maxWidth: maxPanelWidth),
    );
    final panelOffset = _bestOffset(
      size,
      panelSize,
      preferRight: false,
      topClearance: _edgeInset,
    );
    positionChild(_GameplayControl.padPanel, panelOffset);

    final waveSize = layoutChild(_GameplayControl.waveButton, constraints);
    final waveOffset = _bestOffset(
      size,
      waveSize,
      preferRight: true,
      avoid: panelSize.isEmpty ? const <Rect>[] : [panelOffset & panelSize],
    );
    positionChild(_GameplayControl.waveButton, waveOffset);
  }

  Offset _bestOffset(
    Size viewport,
    Size child, {
    required bool preferRight,
    List<Rect> avoid = const [],
    double topClearance = _hudClearance,
  }) {
    final left = safeArea.left + _edgeInset;
    final right = math.max(
      left,
      viewport.width - safeArea.right - _edgeInset - child.width,
    );
    final top = safeArea.top + topClearance;
    final bottom = math.max(
      top,
      viewport.height - safeArea.bottom - _edgeInset - child.height,
    );
    final middleX = (left + right) / 2;
    final middleY = (top + bottom) / 2;
    final preferred = Offset(preferRight ? right : left, bottom);
    final scale = math.min(
      viewport.width / map.worldWidth,
      viewport.height / map.worldHeight,
    );
    final mapOrigin = Offset(
      (viewport.width - map.worldWidth * scale) / 2,
      (viewport.height - map.worldHeight * scale) / 2,
    );
    final padClearance = map.buildPadRadius * scale + 12;
    final candidates = <Offset>{preferred};
    final xCandidates = <double>{left, middleX, right};
    final yCandidates = <double>{top, middleY, bottom};
    for (final pad in map.buildPads) {
      final centre = Offset(
        mapOrigin.dx + pad.position.x * scale,
        mapOrigin.dy + pad.position.y * scale,
      );
      xCandidates
        ..add((centre.dx - child.width).clamp(left, right))
        ..add(centre.dx.clamp(left, right))
        ..add((centre.dx - child.width / 2).clamp(left, right));
      yCandidates
        ..add((centre.dy - child.height).clamp(top, bottom))
        ..add(centre.dy.clamp(top, bottom))
        ..add((centre.dy - child.height / 2).clamp(top, bottom));
    }
    for (final y in yCandidates) {
      for (final x in xCandidates) {
        candidates.add(Offset(x, y));
      }
    }

    var bestOffset = preferred;
    var bestScore = double.infinity;

    for (final candidate in candidates) {
      final rect = candidate & child;
      var score = 0.0;
      for (final pad in map.buildPads) {
        final centre = Offset(
          mapOrigin.dx + pad.position.x * scale,
          mapOrigin.dy + pad.position.y * scale,
        );
        final dx = math.max(
          rect.left - centre.dx,
          math.max(0.0, centre.dx - rect.right),
        );
        final dy = math.max(
          rect.top - centre.dy,
          math.max(0.0, centre.dy - rect.bottom),
        );
        final overlap = padClearance - math.sqrt(dx * dx + dy * dy);
        if (overlap > 0) {
          score += overlap * overlap;
        }
      }
      for (final other in avoid) {
        if (rect.overlaps(other)) {
          score +=
              1000000 +
              (rect.intersect(other).width * rect.intersect(other).height);
        }
      }
      if (score < bestScore) {
        bestScore = score;
        bestOffset = candidate;
      }
    }

    return bestOffset;
  }

  @override
  bool shouldRelayout(_GameplayControlsLayout oldDelegate) =>
      map != oldDelegate.map || safeArea != oldDelegate.safeArea;
}

/// The first-level tutorial card.
///
/// Compact and top-centred so it never covers the controls it describes, and
/// every step advances only through its own buttons: the player can build,
/// start waves or pause in any order while the card is up, so no action can
/// strand the tour (PLAN Phase 11's "no soft-lock" rule). The close icon
/// dismisses from any step, and the dismissal is what the caller records.
class _TutorialCard extends StatefulWidget {
  const _TutorialCard({required this.onDismissed});

  final VoidCallback onDismissed;

  @override
  State<_TutorialCard> createState() => _TutorialCardState();
}

class _TutorialCardState extends State<_TutorialCard> {
  /// One line per idea: what the enemy goal is, how to build, how waves start.
  static const List<({String title, String body})> _steps = [
    (
      title: 'Protect the core',
      body:
          'Enemies follow the route toward your core. Every one that leaks '
          'damages it — the heart chip in the HUD is its health.',
    ),
    (
      title: 'Build on the pads',
      body:
          'Tap an open pad to build a tower. Gold is in the HUD; tapping a '
          'built tower shows its range, stats and upgrades.',
    ),
    (
      title: 'Start the wave',
      body:
          'Use the control at the bottom right to start the first wave. '
          'Later waves arrive on a countdown you can start early. Only one '
          'runs at a time.',
    ),
  ];

  int _step = 0;

  bool get _isLast => _step == _steps.length - 1;

  void _advance() {
    if (_isLast) {
      widget.onDismissed();
      return;
    }
    setState(() => _step++);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = _steps[_step];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(step.title, style: theme.textTheme.titleMedium),
                ),
                IconButton(
                  tooltip: 'Skip tutorial',
                  onPressed: widget.onDismissed,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(step.body, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Step ${_step + 1} of ${_steps.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _advance,
                  child: Text(_isLast ? 'Got it' : 'Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The next-wave control.
///
/// One control covers all three cases, and its enabled state is the domain's own
/// answer: "Start wave" before the first wave, a live countdown while the level
/// holds between waves (tapping it starts early), and a disabled label while a
/// wave is running.
class _WaveControl extends StatelessWidget {
  const _WaveControl({required this.hud, required this.onStart});

  final LevelHudState hud;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final label = switch (hud.phase) {
      LevelPhase.ready => 'Start wave',
      LevelPhase.waveTransition =>
        'Wave ${hud.startedWaves + 1} in ${hud.transitionSecondsRemaining}s',
      _ => 'Wave in progress',
    };
    final tooltip = hud.isInWaveTransition
        ? 'Start wave ${hud.startedWaves + 1} now'
        : label;

    return Tooltip(
      message: tooltip,
      child: FilledButton.icon(
        key: const ValueKey('wave-control'),
        onPressed: hud.canStartWave ? onStart : null,
        icon: Icon(
          hud.isInWaveTransition
              ? Icons.hourglass_bottom_rounded
              : Icons.play_arrow_rounded,
        ),
        label: Text(label),
      ),
    );
  }
}

/// Compact 1x/2x toggle.
class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.speed, required this.onPressed});

  final int speed;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Simulation speed',
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 40),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Text('${speed}x'),
      ),
    );
  }
}

/// Full-screen pause card.
///
/// The game's engine is paused while this is up, so the field behind it is
/// frozen — the overlay is the only thing that can change state.
class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({
    required this.hud,
    required this.onResume,
    required this.onRestart,
    required this.onLeave,
  });

  final LevelHudState hud;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColoredBox(
      color: const Color(0xB30B1016),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Paused', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    hud.endless
                        ? 'Wave ${hud.startedWaves} · '
                              '${hud.gold} g · '
                              'core ${hud.coreHealth}/${hud.maxCoreHealth}'
                        : 'Wave ${hud.startedWaves}/${hud.totalWaves} · '
                              '${hud.gold} g · '
                              'core ${hud.coreHealth}/${hud.maxCoreHealth}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onResume,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Resume'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: onRestart,
                        tooltip: 'Restart level',
                        icon: const Icon(Icons.restart_alt_rounded),
                      ),
                      const SizedBox(width: 4),
                      IconButton.filledTonal(
                        onPressed: onLeave,
                        tooltip: 'Quit to menu',
                        icon: const Icon(Icons.exit_to_app_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small rounded label used by the HUD.
class _HudChip extends StatelessWidget {
  const _HudChip({required this.label, this.icon, this.tint});

  final String label;
  final IconData? icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = this.icon;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: tint ?? theme.colorScheme.onSurface),
              const SizedBox(width: 6),
            ],
            Text(label, style: theme.textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

/// Panel for the selected pad: the build menu when it is empty, the tower's
/// details when it is occupied.
///
/// The panel reads occupancy and gold from the session/controller rather than
/// keeping its own copy, so a refused build can never leave a stale "built"
/// panel on screen.
class _PadPanel extends StatefulWidget {
  const _PadPanel({
    required this.pad,
    required this.session,
    required this.gold,
    required this.onBuild,
    required this.onUpgrade,
    required this.onSell,
    required this.onPriority,
    required this.onClose,
  });

  final BuildPad pad;
  final LevelSession session;
  final int gold;
  final ValueChanged<TowerDefinition> onBuild;
  final VoidCallback onUpgrade;
  final VoidCallback onSell;
  final ValueChanged<TargetingPolicy> onPriority;
  final VoidCallback onClose;

  @override
  State<_PadPanel> createState() => _PadPanelState();
}

class _PadPanelState extends State<_PadPanel> {
  /// A visible thumb, so a panel too tall for a very short viewport reads as
  /// scrollable instead of looking like cut-off controls.
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.pad;
    final tower = widget.session.towerAtPad(pad.id);

    return ConstrainedBox(
      key: const ValueKey('pad-panel'),
      // Kept in step with `_GameplayControlsLayout`, which lays this panel out.
      constraints: BoxConstraints(
        maxWidth: math.min(460, MediaQuery.sizeOf(context).width * 0.55),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              primary: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tower == null
                              ? 'Build pad ${pad.label}'
                              : 'Pad ${pad.label}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: widget.onClose,
                        tooltip: 'Deselect pad',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  if (tower == null)
                    ..._buildOptions(context)
                  else
                    _TowerDetails(
                      padId: pad.id,
                      tower: tower,
                      gold: widget.gold,
                      onUpgrade: widget.onUpgrade,
                      onSell: widget.onSell,
                      onPriority: widget.onPriority,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOptions(BuildContext context) {
    final theme = Theme.of(context);

    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8, right: 8),
        child: Text(
          'Choose a tower',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      for (final definition in widget.session.towerCatalog.all)
        Padding(
          padding: const EdgeInsets.only(bottom: 8, right: 8),
          child: _BuildOption(
            definition: definition,
            gold: widget.gold,
            onTap: () => widget.onBuild(definition),
          ),
        ),
    ];
  }
}

/// One affordable-or-not build choice, with its cost and the gold still missing.
class _BuildOption extends StatelessWidget {
  const _BuildOption({
    required this.definition,
    required this.gold,
    required this.onTap,
  });

  final TowerDefinition definition;
  final int gold;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final affordable = definition.isAffordableWith(gold);
    final missing = definition.buildCost - gold;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 34,
            decoration: BoxDecoration(
              color: Color(definition.colorValue),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(definition.displayName, style: theme.textTheme.titleSmall),
                Text(
                  definition.role,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${definition.buildCost} g',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: affordable
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
              ),
              if (!affordable)
                Text(
                  'Need $missing more',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      enabled: affordable,
      label: 'Build ${definition.displayName} for ${definition.buildCost} gold',
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: affordable ? 1 : 0.45,
        ),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: affordable
            ? InkWell(onTap: onTap, child: content)
            : Opacity(opacity: 0.55, child: content),
      ),
    );
  }
}

/// Details for a built tower: its level and stats, the next upgrade, the
/// sell refund and the target priority.
///
/// Every number and every enabled/disabled state comes from the session via
/// the controller, so the panel can never promise an action the domain would
/// refuse — the rule and the button are the same check.
class _TowerDetails extends StatelessWidget {
  const _TowerDetails({
    required this.padId,
    required this.tower,
    required this.gold,
    required this.onUpgrade,
    required this.onSell,
    required this.onPriority,
  });

  final String padId;
  final TowerInstance tower;
  final int gold;
  final VoidCallback onUpgrade;
  final VoidCallback onSell;
  final ValueChanged<TargetingPolicy> onPriority;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final definition = tower.definition;
    final stats = tower.stats;
    final refund = definition.refundForInvested(tower.investedGold);
    final upgradeCost = tower.nextUpgradeCost;
    final affordable = tower.isUpgradeAffordableWith(gold);
    final slow = stats.slow;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Name and role share a row: the panel has to fit a landscape phone
          // without scrolling its controls out of reach.
          Row(
            children: [
              Text(
                definition.displayName,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  definition.role,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              _StatChip(label: 'Lv ${tower.level}/${definition.maxLevel}'),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(label: 'Damage ${_formatStat(stats.damage)}'),
              _StatChip(label: 'Range ${_formatStat(stats.range)}'),
              _StatChip(
                label: 'Fire ${_formatStat(stats.fireCooldownSeconds)}s',
              ),
              if (stats.splashRadius > 0)
                _StatChip(label: 'Blast ${_formatStat(stats.splashRadius)}'),
              if (slow != null) _StatChip(label: _slowLabel(slow)),
            ],
          ),
          const SizedBox(height: 6),
          if (upgradeCost == null)
            Text(
              'Max level',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            Text(
              _nextLevelSummary(definition.levelAt(tower.level + 1)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Semantics(
              button: true,
              enabled: affordable,
              label: 'Upgrade ${definition.displayName} for $upgradeCost gold',
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: affordable ? onUpgrade : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(36),
                  ),
                  icon: const Icon(Icons.upgrade_rounded),
                  label: Text('Upgrade for $upgradeCost g'),
                ),
              ),
            ),
            if (!affordable)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Need ${upgradeCost - gold} more gold',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 6),
          // A Wrap rather than a Row: the target chips and the sell button do
          // not fit one line of a narrow panel, and wrapping keeps every
          // control on screen instead of clipping it off the edge. Sharing the
          // row also keeps the panel short enough to fit a landscape phone.
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Target',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              for (final policy in TargetingPolicy.values)
                ChoiceChip(
                  label: Text(
                    policy == TargetingPolicy.first ? 'First' : 'Strongest',
                  ),
                  selected: tower.targetingPolicy == policy,
                  onSelected: (_) => onPriority(policy),
                ),
              Semantics(
                button: true,
                label: 'Sell ${definition.displayName} for $refund gold',
                child: TextButton.icon(
                  onPressed: onSell,
                  icon: const Icon(Icons.sell_rounded, size: 18),
                  label: Text('Sell for $refund g'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(label, style: theme.textTheme.labelMedium),
      ),
    );
  }
}

/// Whole numbers print without a trailing `.0`; everything else keeps one
/// decimal, which is all the build balance uses.
String _formatStat(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

/// The slow chip: magnitude and duration together.
///
/// Duration is part of the effect, so a level that slows just as hard but for
/// longer must read as an upgrade in the panel.
String _slowLabel(SlowSpec slow) {
  final percent = (slow.magnitude * 100).round();
  return 'Slow $percent% / ${_formatStat(slow.durationSeconds)}s';
}

/// The `Next:` line of the tower panel.
///
/// Damage, range and fire rate always appear; blast and slow are appended only
/// when the level has them, so a Ranger keeps a short line while a Cannon or
/// Frost upgrade shows the effect that actually changes.
String _nextLevelSummary(TowerLevelStats next) {
  final parts = <String>[
    '${_formatStat(next.damage)} dmg',
    '${_formatStat(next.range)} range',
    '${_formatStat(next.fireCooldownSeconds)}s',
  ];
  if (next.splashRadius > 0) {
    parts.add('blast ${_formatStat(next.splashRadius)}');
  }
  final slow = next.slow;
  if (slow != null) {
    parts.add(
      'slow ${(slow.magnitude * 100).round()}% / '
      '${_formatStat(slow.durationSeconds)}s',
    );
  }
  return 'Next: ${parts.join(' · ')}';
}

/// End-of-level summary.
///
/// Every number comes from the HUD snapshot, which the session publishes: the
/// panel cannot report a kill, leak or gold piece the simulation did not record.
/// Campaign rewards, stars and a "next level" action belong to Phase 8, so this
/// offers replay and exit only.
class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.hud,
    required this.onReplay,
    required this.onLeave,
    this.firstClear = false,
    this.next,
    this.campaignComplete = false,
    this.onNext,
    this.endlessBest = 0,
  });

  final LevelHudState hud;
  final VoidCallback onReplay;
  final VoidCallback onLeave;

  /// Whether this victory was the level's first clear.
  final bool firstClear;

  /// The level this victory opens, when this level is in the campaign.
  final ({String id, String name})? next;

  /// Whether this level is the campaign's last.
  final bool campaignComplete;

  /// Opens [next]; null when there is none to open.
  final VoidCallback? onNext;

  /// The stored endless best in waves, shown by the endless result panel.
  final int endlessBest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defeated = hud.isDefeated;
    final endless = hud.endless;
    // One definition of "cleared" for the subtitle and the rows: a defeat on
    // wave N cleared N - 1, a victory (campaign only) cleared them all.
    final cleared = defeated ? hud.startedWaves - 1 : hud.startedWaves;

    // The reward a victory grants is the unlock itself (D39: no carry-over
    // gold), so this line *is* the reward message: name what opened, once,
    // or close the campaign when the last level falls.
    final nextLevel = next;
    String? unlockMessage;
    if (hud.isVictorious) {
      if (campaignComplete) {
        unlockMessage = 'Campaign complete!';
      } else if (firstClear && nextLevel != null) {
        unlockMessage = 'Unlocked: ${nextLevel.name}';
      }
    }
    final stars = LevelRating.starsFor(
      victorious: hud.isVictorious,
      coreHealth: hud.coreHealth,
      maxCoreHealth: hud.maxCoreHealth,
    );

    return ColoredBox(
      color: const Color(0xB30B1016),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    endless
                        ? 'Run over'
                        : defeated
                        ? 'Core destroyed'
                        : 'All waves cleared',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  // The unlock line takes the subtitle's slot on a victory:
                  // it *is* the reward (D39 keeps gold inside the attempt),
                  // and a second line of its own overflows the card on a
                  // 450-high landscape surface.
                  Text(
                    endless
                        ? 'You cleared $cleared waves.'
                        : unlockMessage ??
                              (defeated
                                  ? 'The core fell on wave '
                                        '${hud.startedWaves} of '
                                        '${hud.totalWaves}.'
                                  : 'The core held through all '
                                        '${hud.totalWaves} waves.'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: unlockMessage != null
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  // Stars measure a campaign victory; an endless run is
                  // scored in waves instead, so the row would show nothing.
                  if (!endless) ...[
                    const SizedBox(height: 12),
                    _RatingStars(stars: stars),
                    const SizedBox(height: 12),
                  ],
                  _ResultRow(
                    label: 'Waves cleared',
                    value: endless ? '$cleared' : '$cleared/${hud.totalWaves}',
                  ),
                  if (endless)
                    _ResultRow(
                      label: 'Best run',
                      value: '$endlessBest waves',
                    ),
                  _ResultRow(
                    label: 'Core health',
                    value: '${hud.coreHealth}/${hud.maxCoreHealth}',
                  ),
                  _ResultRow(label: 'Enemies defeated', value: '${hud.kills}'),
                  _ResultRow(label: 'Leaks', value: '${hud.leaks}'),
                  _ResultRow(
                    label: 'Gold earned',
                    value: '${hud.goldEarned} g',
                  ),
                  const SizedBox(height: 16),
                  if (onNext != null)
                    // One row for all three actions: on a 450-high landscape
                    // surface a second stacked row overflows the card, and
                    // "Next level" is the action a victory should foreground.
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: onNext,
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text('Next level'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: onReplay,
                          icon: const Icon(Icons.replay_rounded),
                          label: const Text('Replay'),
                        ),
                        TextButton.icon(
                          onPressed: onLeave,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Menu'),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: onReplay,
                            icon: const Icon(Icons.replay_rounded),
                            label: const Text('Replay'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: onLeave,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Menu'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One label/value line of the result summary.
class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}

/// The star rating earned by this attempt.
///
/// Filled and outline stars both appear, so the rating reads as "2 of 3" rather
/// than as an unlabelled number of icons — and the rule behind it is available
/// from `LevelRating.rules`.
class _RatingStars extends StatelessWidget {
  const _RatingStars({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: '$stars of ${LevelRating.maxStars} stars',
      child: Row(
        children: [
          for (var index = 0; index < LevelRating.maxStars; index++)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                index < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 28,
                color: index < stars
                    ? const Color(0xFFE8C15C)
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// Shared frame for the non-playable gameplay states.
class _StatusScreen extends StatelessWidget {
  const _StatusScreen({
    required this.title,
    required this.onLeave,
    required this.child,
  });

  final String title;
  final VoidCallback onLeave;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton.filledTonal(
                onPressed: onLeave,
                tooltip: 'Back to menu',
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      child,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when a content asset is missing, malformed, or fails validation.
class _ContentErrorScreen extends StatelessWidget {
  const _ContentErrorScreen({
    required this.error,
    required this.onLeave,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onLeave;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _StatusScreen(
      title: 'Level could not be loaded',
      onLeave: onLeave,
      child: Column(
        children: [
          if (kDebugMode)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text(
                '$error',
                textAlign: TextAlign.center,
                maxLines: 10,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
