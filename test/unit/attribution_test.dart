import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/credits/data/attribution_repository.dart';
import 'package:up_tower_defense/features/credits/domain/attributions.dart';

/// The credits screen is generated from `docs/ASSET_ATTRIBUTIONS.md`, so these
/// cases read that exact file: if its format changes without the parser
/// following, or the file stops being bundled, the suite fails instead of the
/// screen quietly crediting nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const parser = AttributionParser();
  final markdown = File('docs/ASSET_ATTRIBUTIONS.md').readAsStringSync();

  group('the attribution document', () {
    final credits = parser.parse(markdown);

    test('records every tracked asset with author, licence and source', () {
      expect(credits.assets, isNotEmpty);

      for (final asset in credits.assets) {
        expect(asset.assets, contains('assets/'));
        expect(asset.author, isNotEmpty);
        expect(asset.licence, isNotEmpty);
        expect(asset.source, startsWith('http'));
      }

      final authors = credits.assets.map((asset) => asset.author).toSet();
      expect(authors, contains(startsWith('Kenney')));
      expect(authors, contains('qubodup (OpenGameArt)'));
    });

    test('flattens markdown so the screen never renders raw syntax', () {
      for (final asset in credits.assets) {
        expect(asset.licence, isNot(contains('](')));
        expect(asset.licence, isNot(contains('`')));
        expect(asset.assets, isNot(contains('`')));
      }
    });

    test('credits runtime packages and excludes development-only ones', () {
      final names = credits.packages.map((package) => package.name).toList();

      expect(names, contains('flame'));
      expect(names, contains('flame_audio'));
      expect(names, isNot(contains('flame_lint')));
      expect(
        credits.packages.every((package) => package.licence.isNotEmpty),
        isTrue,
      );
    });
  });

  test('the document ships in the bundle under the key the screen reads', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);

    expect(
      manifest.listAssets(),
      contains(kAttributionAssetKey),
      reason:
          'pubspec.yaml must declare docs/ASSET_ATTRIBUTIONS.md as an '
          'asset, or the credits screen can never read the record it renders.',
    );
  });

  test('the bundled copy parses the same as the file on disk', () async {
    final bundled = await rootBundle.loadString(kAttributionAssetKey);

    expect(bundled, markdown);
    expect(parser.parse(bundled).assets, isNotEmpty);
  });

  test('a document without the table throws rather than crediting nothing', () {
    expect(
      () => parser.parse('# No table here\n'),
      throwsFormatException,
    );
  });
}
