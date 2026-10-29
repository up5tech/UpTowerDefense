import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/gameplay_harness.dart';

void main() {
  testWidgets('game loads the map world', (tester) async {
    final game = await pumpGameplay(tester);

    expect(find.text('Test Meadow'), findsOneWidget);
    expect(game.world.children, isNotEmpty);
    expect(game.paused, isFalse);
  });

  testWidgets('world keeps the map dimensions on any screen aspect', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 450);
    addTearDown(tester.view.reset);

    final game = await pumpGameplay(tester);
    expect(
      game.camera.visibleWorldRect,
      const Rect.fromLTWH(-640, -360, 1280, 720),
    );

    // A wider phone must letterbox, not stretch the playfield.
    tester.view.physicalSize = const Size(1000, 400);
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      game.camera.visibleWorldRect,
      const Rect.fromLTWH(-640, -360, 1280, 720),
    );
  });

  testWidgets('back button pops to the previous screen and disposes the game', (
    tester,
  ) async {
    final game = await pumpGameplay(tester);

    await tester.tap(find.byTooltip('Back to menu'));
    await tester.pumpAndSettle();

    expect(find.text('menu'), findsOneWidget);
    expect(game.disposed, isTrue);
  });

  testWidgets('removing gameplay from the tree disposes the game', (
    tester,
  ) async {
    final game = await pumpGameplay(tester);
    expect(game.disposed, isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(game.disposed, isTrue);
  });

  testWidgets('backgrounding pauses the engine and resuming continues it', (
    tester,
  ) async {
    final game = await pumpGameplay(tester);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(game.paused, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(game.paused, isFalse);
  });

  testWidgets('gameplay locks landscape and restores menu orientations', (
    tester,
  ) async {
    final orientationCalls = <List<Object?>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          orientationCalls.add(call.arguments as List<Object?>);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpGameplay(tester);

    expect(orientationCalls.first, [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(orientationCalls.last, [
      'DeviceOrientation.portraitUp',
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
  });
}
