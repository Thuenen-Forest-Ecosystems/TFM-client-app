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

  group('compactAfterDelete (#507)', () {
    test('issue example: old 10, new 11-13, delete 11 and 12 -> 13 becomes 11', () {
      final previous = [for (var n = 1; n <= 10; n++) {'tree_number': n}];
      // Delete 11: rows are [10, 12, 13].
      var values = <dynamic>[10, 12, 13];
      final renumberable = [false, true, true];
      var moves = AutoIncrement.compactAfterDelete('tree_number',
          deletedValue: 11, values: values, renumberable: renumberable, previousData: previous);
      expect(moves, {1: 11, 2: 12});
      // Then delete the (now) 11: rows are [10, 12].
      values = [10, 12];
      moves = AutoIncrement.compactAfterDelete('tree_number',
          deletedValue: 11, values: values, renumberable: [false, true], previousData: previous);
      expect(moves, {1: 11});
    });

    test('deleting the highest number changes nothing', () {
      expect(
        AutoIncrement.compactAfterDelete('tree_number',
            deletedValue: 13, values: [10, 11, 12], renumberable: [false, true, true]),
        isEmpty,
      );
    });

    test('never reuses previous-inventory numbers, even after deleting a duplicate', () {
      final previous = [for (var n = 1; n <= 12; n++) {'tree_number': n}];
      // Empty corner in 2022, new trees started at 13; a stray new row had 5.
      expect(
        AutoIncrement.compactAfterDelete('tree_number',
            deletedValue: 5, values: [13, 14], renumberable: [true, true], previousData: previous),
        isEmpty,
      );
    });

    test('reserved (filter-hidden) numbers count like fixed rows', () {
      expect(
        AutoIncrement.compactAfterDelete('tree_number',
            deletedValue: 12,
            values: [10, 13, 14],
            renumberable: [false, true, true],
            reservedValues: [11]),
        {1: 12, 2: 13},
      );
      // A hidden row above the gap blocks moving below it.
      expect(
        AutoIncrement.compactAfterDelete('tree_number',
            deletedValue: 11,
            values: [10, 13, 14],
            renumberable: [false, true, true],
            reservedValues: [12]),
        isEmpty,
      );
    });

    test('a new row at or below the deleted number keeps its slot', () {
      expect(
        AutoIncrement.compactAfterDelete('tree_number',
            deletedValue: 12, values: [10, 11, 13, 15], renumberable: [false, true, true, true]),
        {2: 12, 3: 13},
      );
    });

    test('order of new rows is kept, unsorted input', () {
      expect(
        AutoIncrement.compactAfterDelete('tree_number',
            deletedValue: 2, values: [5, 1, 3], renumberable: [true, false, true]),
        {2: 2, 0: 3},
      );
    });

    test('a row above a fixed higher number does not jump below it', () {
      // Fixed 20 sits above the new rows: nothing may move below 21.
      expect(
        AutoIncrement.compactAfterDelete('tree_number',
            deletedValue: 11, values: [20, 12, 22], renumberable: [false, true, true]),
        {2: 21},
      );
    });

    test('unparseable deleted value is a no-op', () {
      expect(
        AutoIncrement.compactAfterDelete('tree_number',
            deletedValue: null, values: [1, 2], renumberable: [true, true]),
        isEmpty,
      );
    });
  });
}
