import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:up_tower_defense/features/save/data/save_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PreferencesSaveStore', () {
    test('a second store instance reads what the first one wrote', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final first = await PreferencesSaveStore.open();
      await first.write('payload-1');
      await first.write('payload-2');

      // A fresh instance models the next app launch: nothing is carried over
      // in memory, the values come from the preference store.
      final second = await PreferencesSaveStore.open();
      expect(await second.readCurrent(), 'payload-2');
      expect(await second.readBackup(), 'payload-1');
    });

    test('the first write leaves no backup behind', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final store = await PreferencesSaveStore.open();
      await store.write('payload-1');

      expect(await store.readCurrent(), 'payload-1');
      expect(await store.readBackup(), isNull);
    });

    test('a later write never drops the payload it replaced', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final store = await PreferencesSaveStore.open();
      await store.write('one');
      await store.write('two');
      await store.write('three');

      expect(await store.readCurrent(), 'three');
      expect(await store.readBackup(), 'two');
    });

    test('preserved data sits beside the live payload', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final store = await PreferencesSaveStore.open();
      await store.write('healthy');
      await store.preserve('unreadable');

      expect(await store.readCurrent(), 'healthy');
      expect(await store.readBackup(), isNull);
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString(PreferencesSaveStore.damagedKey),
        'unreadable',
      );
    });

    test('a value of the wrong type reads as missing', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferencesSaveStore.currentKey: 42,
      });

      final store = await PreferencesSaveStore.open();

      expect(await store.readCurrent(), isNull);
      expect(await store.readBackup(), isNull);
    });
  });
}
