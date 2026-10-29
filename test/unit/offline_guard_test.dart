import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the offline-first promise at the platform-configuration level.
///
/// The debug and profile manifests are allowed to request network access so the
/// Flutter VM service can attach; the shipped (main) manifest must not.
void main() {
  group('offline guarantees', () {
    test('release Android manifest requests no permissions', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(
        RegExp('<uses-permission').hasMatch(manifest),
        isFalse,
        reason:
            'The release manifest must not declare permissions; the game has '
            'to run fully offline. Move debug-only permissions to '
            'android/app/src/debug/AndroidManifest.xml.',
      );
    });

    test('network permission is confined to debug/profile tooling', () {
      for (final flavor in ['debug', 'profile']) {
        final manifest = File('android/app/src/$flavor/AndroidManifest.xml');
        expect(
          manifest.existsSync(),
          isTrue,
          reason: 'Missing $flavor manifest for the Flutter tooling overlay.',
        );
        expect(
          manifest.readAsStringSync(),
          contains('android.permission.INTERNET'),
          reason:
              'The $flavor manifest carries the VM service network permission.',
        );
      }
    });

    test('the app declares no network client as a dependency', () {
      final declared = _directDependencies(
        File('pubspec.yaml').readAsStringSync(),
      );

      expect(
        declared,
        unorderedEquals(const <String>[
          'flame',
          'flame_audio',
          'flutter',
          'flutter_riverpod',
          'go_router',
          'meta',
          'shared_preferences',
        ]),
        reason:
            'Direct dependencies are the offline promise in miniature: an '
            'HTTP client added here would break it long before any manifest '
            'notice can. A legitimate offline package joins this list '
            'deliberately, with its reason stated in pubspec.yaml — '
            'flame_audio (Phase 10) plays files from the bundle and cannot '
            'reach the network.',
      );
    });
  });
}

/// Package names declared under the top-level `dependencies:` section.
List<String> _directDependencies(String pubspec) {
  final names = <String>[];
  var inSection = false;
  for (final line in pubspec.split('\n')) {
    if (line == 'dependencies:') {
      inSection = true;
      continue;
    }
    if (!inSection) {
      continue;
    }
    if (line.isNotEmpty && !line.startsWith('  ')) {
      break; // the next top-level section (dev_dependencies, flutter)
    }
    final match = RegExp('^  ([a-zA-Z0-9_]+):').firstMatch(line);
    if (match != null) {
      names.add(match.group(1)!);
    }
  }
  return names;
}
