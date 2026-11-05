import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/domain/daily_challenge.dart';

/// The daily selector (D66, D70): a pure function of the local date and the
/// campaign's ordered level list.
const List<String> _campaignOrder = [
  'meadow_01',
  'meadow_02',
  'meadow_03',
  'meadow_04',
  'meadow_05',
  'ember_01',
  'ember_02',
  'ember_03',
  'ember_04',
  'ember_05',
  'hollow_01',
  'hollow_02',
  'hollow_03',
  'hollow_04',
  'hollow_05',
];

String _select(DateTime date) => DailyChallenge.selectLevelId(
  seed: DailyChallenge.dateKeyOf(date),
  levelIds: _campaignOrder,
);

void main() {
  test('the date key is the local calendar date as yyyyMMdd', () {
    expect(DailyChallenge.dateKeyOf(DateTime(2026, 11, 4)), 20261104);
    expect(DailyChallenge.dateKeyOf(DateTime(2026)), 20260101);
    expect(DailyChallenge.dateKeyOf(DateTime(2026, 12, 31)), 20261231);
    // A leap day is a date like any other; nothing here reads a month length.
    expect(DailyChallenge.dateKeyOf(DateTime(2024, 2, 29)), 20240229);
  });

  test('the seed is pinned, so every device picks the same level', () {
    // Pinned dates and the level each one selects. Changing the algorithm
    // changes these, which is exactly what this test is for (D70).
    expect(_select(DateTime(2026, 11, 4)), 'hollow_04');
    expect(_select(DateTime(2026)), 'hollow_04');
    expect(_select(DateTime(2026, 12, 31)), 'meadow_01');
    expect(_select(DateTime(2024, 2, 29)), 'meadow_04');
    expect(_select(DateTime(2026, 6, 15)), 'hollow_02');
  });

  test('zero state is substituted, never used as a shift seed', () {
    expect(DailyChallenge.nextSeed(0), 1085196063);
    expect(DailyChallenge.zeroState, 0x6D2B79F5);
  });

  test('every seed selects a level of the campaign, and one day at a time', () {
    final selected = <int, String>{};
    for (var day = 1; day <= 365; day++) {
      final date = DateTime(2026).add(Duration(days: day - 1));
      final levelId = _select(date);

      expect(_campaignOrder, contains(levelId), reason: '$date');
      selected[DailyChallenge.dateKeyOf(date)] = levelId;
    }

    // The point of a daily is that it varies: a selector that returned one
    // level forever would still pass the membership check above.
    expect(selected.values.toSet().length, greaterThan(5));
  });

  test('an empty campaign is a programming error, not an empty pick', () {
    expect(
      () => DailyChallenge.selectLevelId(seed: 1, levelIds: const []),
      throwsArgumentError,
    );
  });

  test('the selection depends on the ordered list, not on a level id', () {
    // Reordering the campaign reorders the days: the level, not its position,
    // is the unit of choice.
    final reordered = _campaignOrder.reversed.toList();
    final date = DateTime(2026, 11, 4);

    expect(
      DailyChallenge.selectLevelId(
        seed: DailyChallenge.dateKeyOf(date),
        levelIds: reordered,
      ),
      isNot(_select(date)),
    );
  });
}
