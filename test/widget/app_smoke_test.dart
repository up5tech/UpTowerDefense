import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:up_tower_defense/app/app.dart';
import 'package:up_tower_defense/core/constants/app_info.dart';
import 'package:up_tower_defense/features/campaign/application/campaign_providers.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_progress.dart';
import 'package:up_tower_defense/features/save/data/save_store.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('shell boots into the main menu with its entry points', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: UpTowerDefenseApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppInfo.name), findsOneWidget);
    expect(find.text(AppInfo.tagline), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Campaign'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Credits'), findsOneWidget);
  });

  testWidgets('the menu stays quiet when the save is healthy', (tester) async {
    await pumpApp(tester);

    expect(find.text('Progress is saved on this device.'), findsNothing);
    expect(find.textContaining('could not be read'), findsNothing);
    expect(
      find.text('Offline game — no account, no network required.'),
      findsOneWidget,
    );
  });

  testWidgets('the menu shows how far the campaign has gone', (tester) async {
    final container = await pumpApp(tester);

    // A fresh campaign still shows its totals, so the line reads as a stat
    // rather than as a reward the player has to earn first.
    expect(
      find.text('0 of 4 levels cleared · 0 of 12 stars'),
      findsOneWidget,
    );

    container
        .read(campaignProgressProvider.notifier)
        .record(
          const LevelResult(
            levelId: 'test_level',
            stars: 3,
            coreHealth: 10,
            maxCoreHealth: 10,
            wavesCleared: 2,
            totalWaves: 2,
          ),
        );
    await tester.pumpAndSettle();

    expect(
      find.text('1 of 4 levels cleared · 3 of 12 stars'),
      findsOneWidget,
    );
  });

  testWidgets('the menu reports a save it could not read', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PreferencesSaveStore.currentKey: '{"schemaVersion":2,"results":',
    });
    final save = await PreferencesSaveStore.open();

    await pumpApp(tester, saveStore: save);

    // Before the player opens anything, on the first screen they see.
    expect(find.textContaining('Your save could not be read'), findsOneWidget);
    expect(find.text('Progress is saved on this device.'), findsNothing);
  });
}
