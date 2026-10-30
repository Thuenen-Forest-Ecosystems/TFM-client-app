import 'package:flutter_test/flutter_test.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/auto-increment.dart';

void main() {
  final previous2012 = [for (var n = 1; n <= 12; n++) {'tree_number': n}];

  test('empty corner continues after the previous inventory (#437, 18360/3)', () {
    expect(AutoIncrement.next('tree_number', previousData: previous2012), 13);
    expect(
      AutoIncrement.next('tree_number', currentValues: [13, 14], previousData: previous2012),
      15,
    );
  });

  test('previous numbers beyond the current maximum are skipped (18283/3)', () {
    final previous = [for (var n = 1; n <= 8; n++) {'tree_number': n}];
    expect(
      AutoIncrement.next('tree_number', currentValues: [1, 2, 3, 4, 5, 6], previousData: previous),
      9,
    );
  });

  test('current maximum wins when it is higher', () {
    expect(
      AutoIncrement.next('tree_number', currentValues: [20], previousData: previous2012),
      21,
    );
  });

  test('without any numbers the default is used', () {
    expect(AutoIncrement.next('tree_number'), 1);
    expect(AutoIncrement.next('tree_number', previousData: const [], defaultValue: 5), 5);
  });

  test('numeric strings, doubles and nulls are normalized', () {
    expect(
      AutoIncrement.next(
        'tree_number',
        currentValues: ['3', null, 2.0],
        previousData: [
          {'tree_number': ' 7 '},
          {'tree_number': null},
          'not a map',
        ],
      ),
      8,
    );
  });

  test('previousFilter limits which previous rows count', () {
    final previous = [
      {'point_number': 9, 'point_type': 4},
      {'point_number': 2, 'point_type': 5},
    ];
    expect(
      AutoIncrement.next(
        'point_number',
        previousData: previous,
        previousFilter: (row) => row['point_type'] == 5,
      ),
      3,
    );
  });
}
