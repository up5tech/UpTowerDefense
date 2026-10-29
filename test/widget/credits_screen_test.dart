import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/credits/application/credits_providers.dart';
import 'package:up_tower_defense/features/credits/presentation/credits_screen.dart';

import '../helpers/pump_app.dart';
import '../helpers/stub_asset_bundle.dart';

void main() {
  testWidgets('credits render the recorded art, audio and packages', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Credits'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Credits'), findsOneWidget);

    // Each tracked row shows what ships, who made it under what licence,
    // and where it came from.
    expect(find.textContaining('assets/audio/shot.wav'), findsOneWidget);
    expect(find.textContaining('Test Author'), findsOneWidget);
    expect(find.textContaining('CC0 1.0'), findsOneWidget);
    expect(find.text('https://example.com/sounds'), findsOneWidget);
    expect(find.textContaining('Another Author'), findsOneWidget);

    // Packages come from the document, not a list hardcoded in the widget.
    expect(find.text('flame'), findsOneWidget);
    expect(find.text('MIT'), findsOneWidget);
    expect(find.text('BSD-3-Clause'), findsOneWidget);
    expect(find.text('Riverpod'), findsNothing);

    // Development-only packages never ship, so they are not credited.
    expect(find.text('flame_lint'), findsNothing);

    // The licence page stays reachable regardless of the document.
    expect(find.text('Open source licences'), findsOneWidget);
  });

  testWidgets('an unreadable document fails loudly instead of showing an '
      'empty screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attributionBundleProvider.overrideWithValue(
            StubAssetBundle(const {}),
          ),
        ],
        child: const MaterialApp(home: CreditsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('could not be read'), findsOneWidget);
    expect(find.text('Open source licences'), findsOneWidget);
  });
}
