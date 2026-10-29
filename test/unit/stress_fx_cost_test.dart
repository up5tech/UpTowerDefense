import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_event.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_phase.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';
import 'package:up_tower_defense/features/gameplay/flame/fx_layer.dart';

import '../helpers/stress_scenario.dart';

/// Stress scenario for the *effects* half of a frame (PLAN Phase 12).
///
/// `stress_frame_cost_test.dart` times the simulation; this companion times
/// what the frame spends on feedback — `FxLayer.publish` (events arrive,
/// oldest effects dropped at the cap), `FxLayer.update` (lifetimes) and
/// `FxLayer.render` (drawing the surviving cues). The render half is recorded
/// into a `PictureRecorder`, which measures the **UI thread's** cost of
/// building the draw commands: on a real frame those commands are what the
/// raster thread later paints, and that paint needs a GPU to measure. So this
/// test answers "how much of the frame does the effect layer own before
/// rasterisation" — the number that tells a device profile where to look, not
/// the replacement for it.
///
/// Two loads, because the layer has two regimes:
///   * the real event stream of the shared stress scenario — how expensive the
///     effects actually are while the crowd burns down; and
///   * a saturated layer, `maxLiveEffects` cues alive plus a trimming publish
///     every frame — the worst case the design allows, whatever the wave.
///
/// Budgets carry wide headroom (wall-clock on a shared machine is noisy) and
/// only fail on order-of-magnitude regressions; the distribution prints on
/// every run so a human can trend it.

/// Warm-up frames: JIT compiles the render switch and lifetimes tick down, so
/// the measured window reads steady state rather than startup.
const int _warmupFrames = 600;

/// The measured window of the real-stream case: 50 seconds of play at 60 fps.
const int _measuredFrames = 3000;

/// Average publish+update+render cost tolerated for the real stream.
///
/// One 60 fps frame is ~16 670µs on device; the effects half gets 1 000µs,
/// several times the observed cost here, so only an order-of-magnitude
/// regression trips this rather than CI noise.
const int _realStreamBudgetMicros = 1000;

/// The saturated case measures fewer frames: the load is constant by
/// construction, so the window only has to be long enough to be stable.
const int _saturatedWarmupFrames = 300;
const int _saturatedFrames = 1500;

/// Budget for the saturated layer, wider than the real stream because every
/// frame does the cap trim plus the maximum number of cues.
const int _saturatedBudgetMicros = 1500;

/// Live effects the real stream must reach for its timing to mean anything —
/// a measurement of three cues says nothing about a layer designed to hold 64.
const int _minRealStreamEffects = 20;

/// Every cue kind, cycled in the saturated load so each `render` branch runs:
/// ring, blast ring, death ring, leak ring with ticks, reticle and chevrons.
const List<LevelEventKind> _allKinds = [
  LevelEventKind.shot,
  LevelEventKind.hit,
  LevelEventKind.defeated,
  LevelEventKind.leaked,
  LevelEventKind.built,
  LevelEventKind.upgraded,
];

/// One frame's worth of events that keeps the layer pinned at its cap.
///
/// Positions are spread over the map's world rectangle so nothing is a repeat
/// of the last frame, and every third cue carries a blast radius so the splash
/// boundary branch of `hit` is measured too.
List<LevelEvent> _saturatedBatch(int frame) {
  return [
    for (var i = 0; i < FxLayer.maxLiveEffects + 8; i++)
      LevelEvent(
        _allKinds[(frame + i) % _allKinds.length],
        WorldPoint(
          ((frame * 37 + i * 131) % 1280).toDouble(),
          ((frame * 53 + i * 217) % 720).toDouble(),
        ),
        radius: i % 3 == 0 ? 40 : 0,
      ),
  ];
}

/// Summarises samples the way the simulation stress test does, so the two
/// distributions read alike.
String _report(String name, List<int> samples) {
  final sorted = [...samples]..sort();
  final average =
      samples.fold<int>(0, (sum, value) => sum + value) / samples.length;
  final p95 = sorted[(sorted.length * 0.95).floor()];
  return '$name over ${samples.length} frames: '
      'avg ${average.toStringAsFixed(1)}µs, '
      'p95 ${p95.toStringAsFixed(1)}µs, '
      'worst ${sorted.last}µs';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the effect layer stays cheap under the stress wave’s own events', () async {
    final session = await startStressSession();
    final fx = FxLayer();

    final watch = Stopwatch();
    var peakEffects = 0;
    var peakEventsPerFrame = 0;
    var totalEvents = 0;
    var leftPlaying = 0;

    // Warm-up runs the full path, render included, so the hot switch is
    // compiled before the first sample is taken.
    for (var frame = 0; frame < _warmupFrames; frame++) {
      session.advance(stressFrameDt);
      fx.publish(session.drainEvents());
      fx.update(stressFrameDt);
      final recorder = PictureRecorder();
      fx.render(Canvas(recorder));
      recorder.endRecording();
    }

    final samples = <int>[];
    for (var frame = 0; frame < _measuredFrames; frame++) {
      session.advance(stressFrameDt);

      // One recorder per frame, ended outside the timing: the engine reuses a
      // canvas, so only publish+update+render belong in the number — picture
      // creation is harness bookkeeping.
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      watch
        ..reset()
        ..start();
      final events = session.drainEvents();
      fx.publish(events);
      fx.update(stressFrameDt);
      fx.render(canvas);
      watch.stop();
      samples.add(watch.elapsedMicroseconds);
      recorder.endRecording();

      peakEffects = math.max(peakEffects, fx.activeCount);
      peakEventsPerFrame = math.max(peakEventsPerFrame, events.length);
      totalEvents += events.length;
      if (session.phase != LevelPhase.playing) {
        leftPlaying += 1;
      }

      if (frame % 600 == 0) {
        // ignore: avoid_print
        print(
          '  t=${((frame + _warmupFrames) * stressFrameDt).toStringAsFixed(0)}s '
          'events this frame=${events.length} '
          'live effects=${fx.activeCount}',
        );
      }
    }

    // ignore: avoid_print
    print(
      'fx frame cost (${_report('real stream', samples)}) | '
      'peak $peakEffects live effects, peak $peakEventsPerFrame events/frame, '
      '$totalEvents events total',
    );

    expect(
      leftPlaying,
      0,
      reason:
          'the attempt left the playing phase — the effect layer would be '
          'measured against an event stream that stopped arriving',
    );
    expect(
      peakEffects,
      greaterThanOrEqualTo(_minRealStreamEffects),
      reason:
          'peak live effects was $peakEffects; the stress wave no longer '
          'produces enough cues to measure the layer meaningfully — re-read '
          'the event counts above before trusting the timing',
    );
    final average =
        samples.fold<int>(0, (sum, value) => sum + value) / samples.length;
    expect(
      average.round(),
      lessThan(_realStreamBudgetMicros),
      reason:
          'average fx publish+update+render was '
          '${average.toStringAsFixed(1)}µs against a '
          '$_realStreamBudgetMicrosµs budget. A jump this large is an '
          'algorithmic or allocation regression in FxLayer (per-frame '
          'rebuilds, uncapped effect lists), not noise — read the printed '
          'distribution and adjust the budget in the same change only after '
          'understanding why it moved.',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('a saturated effect layer stays inside the effects budget', () async {
    final fx = FxLayer();
    final watch = Stopwatch();

    for (var frame = 0; frame < _saturatedWarmupFrames; frame++) {
      fx.publish(_saturatedBatch(frame));
      fx.update(stressFrameDt);
      final recorder = PictureRecorder();
      fx.render(Canvas(recorder));
      recorder.endRecording();
    }

    final samples = <int>[];
    var peakEffects = 0;
    for (var frame = 0; frame < _saturatedFrames; frame++) {
      final batch = _saturatedBatch(frame);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      watch
        ..reset()
        ..start();
      fx.publish(batch);
      fx.update(stressFrameDt);
      fx.render(canvas);
      watch.stop();
      samples.add(watch.elapsedMicroseconds);
      recorder.endRecording();

      peakEffects = math.max(peakEffects, fx.activeCount);
    }

    // ignore: avoid_print
    print(
      'fx frame cost (${_report('saturated', samples)}) | '
      'peak $peakEffects live effects',
    );

    expect(
      peakEffects,
      FxLayer.maxLiveEffects,
      reason:
          'the saturated load never pinned the layer at its cap — without '
          'the trim running every frame this measures an easier case than the '
          'design allows',
    );
    final average =
        samples.fold<int>(0, (sum, value) => sum + value) / samples.length;
    expect(
      average.round(),
      lessThan(_saturatedBudgetMicros),
      reason:
          'average saturated fx cost was ${average.toStringAsFixed(1)}µs '
          'against a $_saturatedBudgetMicrosµs budget; a jump this large is a '
          'regression in FxLayer itself — read the printed distribution and '
          'adjust the budget in the same change only after understanding why.',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
