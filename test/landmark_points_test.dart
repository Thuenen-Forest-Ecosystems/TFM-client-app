import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/l10n/app_localizations.dart';
import 'package:terrestrial_forest_monitor/providers/language.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/array-element-cardlist.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/landmark-points.dart';

Widget _host(Widget child) => ChangeNotifierProvider<Language>.value(
  value: Language(const Locale('de')),
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('de'),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

/// Host that mimics FormWrapper: it owns the record data and merges every
/// widget write back into it, so the tests see the same read/write cycle the
/// app uses.
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
  Widget build(BuildContext context) {
    return _host(widget.builder(_data, (updated) => setState(() => _data.addAll(updated))));
  }
}

List<Map<String, dynamic>> _points(Map<String, dynamic> data) =>
    (data['plot_support_points'] as List).cast<Map<String, dynamic>>();

void main() {
  group('LandmarkPoints', () {
    testWidgets('adds a point_type 2 entry and keeps the other support points', (tester) async {
      final data = <String, dynamic>{
        'plot_support_points': [
          {'point_type': 5, 'note': 'GNSS'},
          {'point_type': 1, 'note': 'versetzt'},
        ],
      };

      await tester.pumpWidget(
        _Host(
          data: data,
          builder: (d, onChanged) => LandmarkPoints(data: d, onDataChanged: onChanged),
        ),
      );

      await tester.tap(find.text('Geländepunkt hinzufügen'));
      await tester.pumpAndSettle();

      expect(_points(data).length, 3);
      expect(_points(data).last['point_type'], 2);
      expect(_points(data)[0]['point_type'], 5);
      expect(_points(data)[1]['point_type'], 1);
      expect(find.text('Geländepunkt 1'), findsOneWidget);
    });

    testWidgets('writes distance, azimuth and description into the landmark entry', (
      tester,
    ) async {
      final data = <String, dynamic>{
        'plot_support_points': [
          {'point_type': 2, 'is_marked': false},
        ],
      };

      await tester.pumpWidget(
        _Host(
          data: data,
          builder: (d, onChanged) => LandmarkPoints(data: d, onDataChanged: onChanged),
        ),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Horizontalentfernung'), '24500');
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Azimut'), '137');
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Beschreibung'), 'Funkmast');
      await tester.pumpAndSettle();

      expect(_points(data).single['distance'], 24500);
      expect(_points(data).single['azimuth'], 137);
      expect(_points(data).single['note'], 'Funkmast');
    });

    testWidgets('edits the second landmark without touching the first', (tester) async {
      final data = <String, dynamic>{
        'plot_support_points': [
          {'point_type': 5, 'note': 'GNSS'},
          {'point_type': 2, 'note': 'A', 'azimuth': 10},
          {'point_type': 2, 'note': 'B', 'azimuth': 20},
        ],
      };

      await tester.pumpWidget(
        _Host(
          data: data,
          builder: (d, onChanged) => LandmarkPoints(data: d, onDataChanged: onChanged),
        ),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Azimut').last, '321');
      await tester.pumpAndSettle();

      expect(_points(data)[1]['azimuth'], 10);
      expect(_points(data)[2]['azimuth'], 321);
    });

    testWidgets('rejects an azimuth outside 0–399 gon', (tester) async {
      final data = <String, dynamic>{
        'plot_support_points': [
          {'point_type': 2},
        ],
      };

      await tester.pumpWidget(
        _Host(
          data: data,
          builder: (d, onChanged) => LandmarkPoints(data: d, onDataChanged: onChanged),
        ),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Azimut'), '400');
      await tester.pumpAndSettle();

      expect(find.text('0–399 Gon'), findsOneWidget);
    });

    testWidgets('removes only the selected landmark', (tester) async {
      final data = <String, dynamic>{
        'plot_support_points': [
          {'point_type': 5, 'note': 'GNSS'},
          {'point_type': 2, 'note': 'A'},
          {'point_type': 2, 'note': 'B'},
        ],
      };

      await tester.pumpWidget(
        _Host(
          data: data,
          builder: (d, onChanged) => LandmarkPoints(data: d, onDataChanged: onChanged),
        ),
      );

      await tester.tap(find.widgetWithIcon(IconButton, Icons.delete_outline).first);
      await tester.pumpAndSettle();

      expect(_points(data).length, 2);
      expect(_points(data)[0]['point_type'], 5);
      expect(_points(data)[1]['note'], 'B');
    });
  });

  group('ArrayElementCardList filterBy', () {
    const schema = {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'point_type': {'type': 'integer'},
          'note': {'type': 'string'},
        },
      },
    };

    testWidgets('renders only the rows it owns and preserves the rest on write', (tester) async {
      List<dynamic>? written;
      final data = <dynamic>[
        {'point_type': 5, 'note': 'GNSS'},
        {'point_type': 2, 'note': 'Landmarke'},
      ];

      await tester.pumpWidget(
        _host(
          ArrayElementCardList(
            jsonSchema: schema,
            data: data,
            label: 'GNSS-Hilfspunkt',
            columnItems: const [
              {'name': 'point_type', 'display': false, 'default': 5},
              {'name': 'note'},
            ],
            layoutOptions: const {
              'maxRows': 1,
              'filterBy': {'point_type': 5},
            },
            onDataChanged: (updated) => written = updated,
          ),
        ),
      );

      // Only the point_type 5 row is rendered, so maxRows: 1 is not consumed
      // by the landmark entry.
      expect(find.text('GNSS-Hilfspunkt (1)'), findsOneWidget);
      expect(find.text('GNSS-Hilfspunkt (2)'), findsNothing);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(written, isNotNull);
      expect(written!.length, 1);
      expect((written!.single as Map)['point_type'], 2);
    });
  });
}
