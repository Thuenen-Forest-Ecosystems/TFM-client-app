import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrestrial_forest_monitor/models/layout_config.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/array-summary.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

/// The filter the Bestockung tab declares: WZP4 sample trees are the ones with
/// tree_status (PK) 0 "neuer Probebaum" or 1 "wiederholt aufgenommener
/// Probebaum".
const _wzp4Filter = {
  'filter': [
    {
      'field': 'tree_status',
      'operator': 'in',
      'values': [0, 1],
    },
  ],
};

Map<String, dynamic> _tree(int number, dynamic status) => {
  'tree_number': number,
  'tree_status': status,
};

void main() {
  group('ArraySummary', () {
    testWidgets('counts only the rows matching the declared filter', (tester) async {
      await tester.pumpWidget(
        _host(
          ArraySummary(
            rows: [
              _tree(1, 0), // neuer Probebaum
              _tree(2, 1), // wiederholt aufgenommener Probebaum
              _tree(3, 1),
              _tree(4, 2), // selektiv entnommen
              _tree(5, 10), // kein Probebaum mehr
              _tree(6, 2012), // schon 2012 ausgefallen
            ],
            label: 'Probebäume in der WZP4',
            layoutOptions: _wzp4Filter,
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('does not count a row whose filtered field is absent or null', (tester) async {
      await tester.pumpWidget(
        _host(
          ArraySummary(
            rows: [
              _tree(1, 0),
              _tree(2, null),
              {'tree_number': 3}, // freshly added row, PK not yet set
            ],
            label: 'Probebäume in der WZP4',
            layoutOptions: _wzp4Filter,
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('shows 0 for an array that is not in the record yet', (tester) async {
      await tester.pumpWidget(
        _host(
          ArraySummary(rows: null, label: 'Probebäume in der WZP4', layoutOptions: _wzp4Filter),
        ),
      );

      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('counts every row when the style declares no filter', (tester) async {
      await tester.pumpWidget(
        _host(
          ArraySummary(
            rows: [_tree(1, 0), _tree(2, 2012)],
            label: 'Einträge',
            layoutOptions: const {},
          ),
        ),
      );

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('renders label, description and icon from the style', (tester) async {
      await tester.pumpWidget(
        _host(
          ArraySummary(
            rows: [_tree(1, 0)],
            label: 'Probebäume in der WZP4',
            layoutOptions: const {'description': 'Bäume mit PK 0 oder 1'},
          ),
        ),
      );

      expect(find.text('Probebäume in der WZP4'), findsOneWidget);
      expect(find.text('Bäume mit PK 0 oder 1'), findsOneWidget);
    });

    test('the style-map item parses as an ObjectLayout', () {
      // Verbatim copy of the Bestockung entry in TFM-validation
      // validation/style-map.json. It is declared as type "object" on purpose:
      // an unknown `type` makes LayoutConfig.fromJson throw and drops the whole
      // layout, so an app version that predates this component must still be
      // able to parse the style it is served.
      final item = LayoutItem.fromJson({
        'id': 'wzp4_tree_count',
        'label': 'Probebäume in der WZP4',
        'type': 'object',
        'component': 'array_summary',
        'property': 'tree',
        'options': {
          'description': 'Bäume mit PK 0 oder 1',
          'filter': [
            {
              'field': 'tree_status',
              'operator': 'in',
              'values': [0, 1],
            },
          ],
        },
      });

      expect(item, isA<ObjectLayout>());
      final object = item as ObjectLayout;
      expect(object.component, 'array_summary');
      expect(object.property, 'tree');
      expect(object.options?['filter'], isA<List>());
    });
  });
}
