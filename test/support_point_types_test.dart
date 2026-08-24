import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/l10n/app_localizations.dart';
import 'package:terrestrial_forest_monitor/providers/language.dart';
import 'package:terrestrial_forest_monitor/services/validation_types.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/array-element-cardlist.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/displaced-marker.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/landmark-points.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/plot-support-points.dart';

/// The style is JSON at runtime, so build the fixtures the same way: a const
/// Dart literal would hand the widgets `List<String>`/`Map<String, int>` where
/// production has `List<dynamic>`/`Map<String, dynamic>`.
dynamic _json(dynamic value) => jsonDecode(jsonEncode(value));

final Map<String, dynamic> schema = _json({
  'type': 'array',
  'items': {
    'type': 'object',
    'properties': {
      'point_type': {'type': 'integer'},
      'note': {
        'type': ['string', 'null'],
      },
    },
  },
});

/// Same shape as `plot_support_points_grid.items` in the style-map: point_type
/// is hidden and carries the constant this list stamps on rows it creates.
final List<dynamic> columnItems = _json([
  {'name': 'point_type', 'display': false, 'default': 5},
  {'name': 'note'},
]);

Widget _host(Widget child) => ChangeNotifierProvider<Language>.value(
  value: Language(const Locale('de')),
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('de'),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

/// Mimics FormWrapper: owns the record and merges every widget write back.
class _Host extends StatefulWidget {
  const _Host({required this.data, required this.builder});

  final Map<String, dynamic> data;
  final Widget Function(
    Map<String, dynamic> data,
    void Function(Map<String, dynamic>) onDataChanged,
  )
  builder;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late final Map<String, dynamic> _data = widget.data;

  @override
  Widget build(BuildContext context) =>
      _host(widget.builder(_data, (updated) => setState(() => _data.addAll(updated))));
}

List<Map<String, dynamic>> _points(Map<String, dynamic> data) =>
    (data['plot_support_points'] as List).cast<Map<String, dynamic>>();

void main() {
  group('ArrayElementCardList without filterBy in the style', () {
    // A style deployed before `options.filterBy` existed still separates the
    // point types, because the hidden constant fields of columnItems say which
    // rows this list creates – and therefore owns.
    testWidgets('falls back to the hidden constant fields of columnItems', (tester) async {
      List<dynamic>? written;
      final data = <dynamic>[
        {'point_type': 5, 'note': 'GNSS'},
        {'point_type': 1, 'note': 'versetzte Markierung'},
        {'point_type': 2, 'note': 'Geländepunkt'},
      ];

      await tester.pumpWidget(
        _host(
          ArrayElementCardList(
            jsonSchema: schema,
            data: data,
            label: 'GNSS-Hilfspunkt',
            columnItems: columnItems,
            layoutOptions: _json({'maxRows': 1}) as Map<String, dynamic>,
            onDataChanged: (updated) => written = updated,
          ),
        ),
      );

      expect(find.text('GNSS-Hilfspunkt (1)'), findsOneWidget);
      expect(find.text('GNSS-Hilfspunkt (2)'), findsNothing);
      // maxRows is not consumed by the foreign rows
      expect(find.text('Maximal 1 Einträge'), findsOneWidget);

      // ... and the foreign rows survive a write from this list
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(written!.map((r) => (r as Map)['point_type']).toList(), [1, 2]);
    });

    testWidgets('an explicit filterBy still wins over the fallback', (tester) async {
      final data = <dynamic>[
        {'point_type': 5, 'note': 'GNSS'},
        {'point_type': 2, 'note': 'Geländepunkt'},
      ];

      await tester.pumpWidget(
        _host(
          ArrayElementCardList(
            jsonSchema: schema,
            data: data,
            label: 'Geländepunkt',
            columnItems: columnItems, // hidden default says 5
            layoutOptions: _json({
              'filterBy': {'point_type': 2},
            }),
            onDataChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Geländepunkt (1)'), findsOneWidget);
      expect(find.text('Geländepunkt (2)'), findsNothing);
      expect(find.text('Geländepunkt'), findsOneWidget); // the note of the rendered row
    });
  });

  group('ArrayElementCardList validation paths', () {
    // Validation errors address the record's array, so a rendered row must be
    // identified by its index in the full array – not by its position in the
    // filtered view.
    testWidgets('use the row index of the full array, not of the filtered view', (tester) async {
      final data = <dynamic>[
        {'point_type': 1, 'note': 'versetzte Markierung'},
        {'point_type': 5, 'note': 'GNSS'},
      ];

      await tester.pumpWidget(
        _host(
          ArrayElementCardList(
            jsonSchema: schema,
            data: data,
            label: 'GNSS-Hilfspunkt',
            propertyName: 'plot_support_points',
            columnItems: columnItems,
            layoutOptions: _json({
              'filterBy': {'point_type': 5},
            }),
            validationResult: TFMValidationResult(
              ajvValid: false,
              ajvErrors: [
                ValidationError(
                  instancePath: '/plot_support_points/1/note',
                  message: 'Fehler an der GNSS-Zeile',
                ),
              ],
              tfmAvailable: true,
              tfmErrors: const [],
            ),
            onDataChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Fehler an der GNSS-Zeile'), findsOneWidget);
    });
  });

  group('point_type declared by the style', () {
    testWidgets('DisplacedMarker adds the point_type from options.filterBy', (tester) async {
      final data = <String, dynamic>{'marker_status': 3, 'plot_support_points': <dynamic>[]};

      await tester.pumpWidget(
        _Host(
          data: data,
          builder: (d, onChanged) => DisplacedMarker(
            data: d,
            layoutOptions: _json({
              'filterBy': {'point_type': 3},
            }),
            onDataChanged: onChanged,
          ),
        ),
      );

      await tester.tap(find.text('Versetzte Markierung anlegen'));
      await tester.pumpAndSettle();

      expect(_points(data).single['point_type'], 3);
      // and it edits that row, not a hardcoded point_type 1 one
      await tester.enterText(find.byType(TextField).last, 'Beschreibung');
      await tester.pumpAndSettle();
      expect(_points(data).single['note'], 'Beschreibung');
    });

    testWidgets('DisplacedMarker falls back to point_type 1 without options', (tester) async {
      final data = <String, dynamic>{'marker_status': 3, 'plot_support_points': <dynamic>[]};

      await tester.pumpWidget(
        _Host(
          data: data,
          builder: (d, onChanged) => DisplacedMarker(data: d, onDataChanged: onChanged),
        ),
      );

      await tester.tap(find.text('Versetzte Markierung anlegen'));
      await tester.pumpAndSettle();

      expect(_points(data).single['point_type'], 1);
    });

    testWidgets('LandmarkPoints adds the point_type from options.filterBy', (tester) async {
      final data = <String, dynamic>{
        'plot_support_points': [
          {'point_type': 5, 'note': 'GNSS'},
        ],
      };

      await tester.pumpWidget(
        _Host(
          data: data,
          builder: (d, onChanged) => LandmarkPoints(
            data: d,
            layoutOptions: _json({
              'filterBy': {'point_type': 4},
            }),
            onDataChanged: onChanged,
          ),
        ),
      );

      await tester.tap(find.text('Geländepunkt hinzufügen'));
      await tester.pumpAndSettle();

      expect(_points(data).length, 2);
      expect(_points(data)[1]['point_type'], 4);
      expect(find.text('Geländepunkt 1'), findsOneWidget);
    });

    testWidgets('LandmarkPoints falls back to point_type 2 without options', (tester) async {
      final data = <String, dynamic>{'plot_support_points': <dynamic>[]};

      await tester.pumpWidget(
        _Host(
          data: data,
          builder: (d, onChanged) => LandmarkPoints(data: d, onDataChanged: onChanged),
        ),
      );

      await tester.tap(find.text('Geländepunkt hinzufügen'));
      await tester.pumpAndSettle();

      expect(_points(data).single['point_type'], 2);
    });

    testWidgets('PlotSupportPoints lists the previous points of the declared type', (tester) async {
      final previous = <String, dynamic>{
        'plot_support_points': [
          {'point_type': 1, 'note': 'versetzte Markierung', 'azimuth': 42},
          {'point_type': 2, 'note': 'Geländepunkt'},
        ],
      };

      await tester.pumpWidget(
        _host(
          PlotSupportPoints(
            previousProperties: previous,
            layoutOptions: _json({
              'filterBy': {'point_type': 2},
            }),
          ),
        ),
      );

      expect(find.text('Geländepunkt'), findsOneWidget);
      expect(find.text('versetzte Markierung'), findsNothing);
    });

    testWidgets('PlotSupportPoints falls back to point_type 1 without options', (tester) async {
      final previous = <String, dynamic>{
        'plot_support_points': [
          {'point_type': 1, 'note': 'versetzte Markierung'},
          {'point_type': 2, 'note': 'Geländepunkt'},
        ],
      };

      await tester.pumpWidget(_host(PlotSupportPoints(previousProperties: previous)));

      expect(find.text('versetzte Markierung'), findsOneWidget);
      expect(find.text('Geländepunkt'), findsNothing);
    });
  });
}
