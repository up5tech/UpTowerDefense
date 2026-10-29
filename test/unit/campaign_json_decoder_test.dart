import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/campaign/data/campaign_json_decoder.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_validation.dart';
import 'package:up_tower_defense/features/gameplay/data/content_format_exception.dart';

const String _validJson = '''
{
  "regions": [
    {
      "id": "meadow",
      "displayName": "Meadow Reach",
      "levels": [
        { "id": "meadow_01", "displayName": "First Light" },
        { "id": "meadow_02", "displayName": "Quick Feet" }
      ]
    },
    {
      "id": "ember",
      "displayName": "Ember Pass",
      "levels": [
        { "id": "ember_01", "displayName": "Cinder Gate" }
      ]
    }
  ]
}
''';

void main() {
  test('decodes regions and levels in authored order', () {
    final campaign = CampaignJsonDecoder.decode(_validJson);

    expect(campaign.regions, hasLength(2));
    expect(campaign.regions.first.id, 'meadow');
    expect(campaign.regions.first.displayName, 'Meadow Reach');
    expect(campaign.levelCount, 3);
    // The flattened order is the unlock order.
    expect(campaign.levelIds, ['meadow_01', 'meadow_02', 'ember_01']);
    expect(campaign.displayNameOf('meadow_02'), 'Quick Feet');
    expect(campaign.ordinalOf('ember_01'), 3);
    expect(campaign.regionOf('ember_01')?.id, 'ember');
  });

  test('requires a regions list', () {
    expect(
      () => CampaignJsonDecoder.decode('{}'),
      throwsA(
        isA<ContentFormatException>().having(
          (error) => error.message,
          'message',
          contains('regions must be a list'),
        ),
      ),
    );
  });

  test('names the offending level entry', () {
    expect(
      () => CampaignJsonDecoder.decode(
        _validJson.replaceFirst('"displayName": "Quick Feet"', '"name": "x"'),
      ),
      throwsA(
        isA<ContentFormatException>().having(
          (error) => error.message,
          'message',
          contains('regions[0].levels[1].displayName'),
        ),
      ),
    );
  });

  test('rejects an empty level id', () {
    expect(
      () => CampaignJsonDecoder.decode(
        _validJson.replaceFirst('"id": "meadow_01"', '"id": ""'),
      ),
      throwsA(isA<ContentFormatException>()),
    );
  });

  group('validation', () {
    List<String> issuesFor(
      String json, {
      Set<String> known = const {'meadow_01', 'meadow_02', 'ember_01'},
    }) {
      final campaign = CampaignJsonDecoder.decode(json);
      return const CampaignValidator()
          .validate(campaign: campaign, knownLevelIds: known)
          .issues;
    }

    test('the valid campaign passes', () {
      expect(issuesFor(_validJson), isEmpty);
    });

    test('reports a level the app does not ship', () {
      expect(
        issuesFor(
          _validJson.replaceFirst('"meadow_02"', '"meadow_99"'),
          known: const {'meadow_01', 'ember_01'},
        ),
        contains(contains('unknown level "meadow_99"')),
      );
    });

    test('reports a duplicated level across regions', () {
      expect(
        issuesFor(_validJson.replaceFirst('"ember_01"', '"meadow_01"')),
        contains(contains('appears more than once')),
      );
    });

    test('reports a duplicated region id', () {
      expect(
        issuesFor(_validJson.replaceFirst('"id": "ember"', '"id": "meadow"')),
        contains(contains('region id "meadow" is duplicated')),
      );
    });

    test('reports a region without levels', () {
      final json = _validJson.replaceFirst(
        '''"levels": [
        { "id": "ember_01", "displayName": "Cinder Gate" }
      ]''',
        '"levels": []',
      );

      expect(issuesFor(json), contains(contains('needs at least one level')));
    });
  });
}
