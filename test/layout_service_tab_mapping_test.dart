import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:terrestrial_forest_monitor/models/layout_config.dart';
import 'package:terrestrial_forest_monitor/services/layout_service.dart';

/// Cut-down copy of TFM-validation validation/style-map.json: the tabs that
/// matter for attributing an error path to a tab. Bestockung carries the
/// `array_summary` of the WZP4 trees (#348) and must not claim `/tree/...`
/// errors because of it (#477); its own fields live in nested tabs.
// Round-tripped through JSON so every nested map is a Map<String, dynamic>,
// as LayoutConfig.fromJson expects from a parsed style_default.
LayoutConfig _layout() => LayoutConfig.fromJson(jsonDecode(jsonEncode(_styleMap)) as Map<String, dynamic>);

const Map<String, dynamic> _styleMap = {
  'version': 'test',
  'layout': {
    'id': 'root',
    'type': 'tabs',
    'items': [
      {'id': 'messages', 'type': 'object', 'component': 'messages_chat'},
      {
        'id': 'habitat_and_stocking',
        'label': 'Ecke',
        'type': 'column',
        'items': [
          {
            'id': 'tract_marking',
            'type': 'card',
            'items': [
              {'id': 'plot_support_points', 'type': 'object', 'component': 'plot_support_points'},
              {
                'id': 'general',
                'type': 'form',
                'properties': [
                  {'name': 'marker_profile'},
                  {'name': 'marker_status'},
                ],
              },
            ],
          },
        ],
      },
      {'id': 'tree', 'label': 'WZP4', 'type': 'array', 'component': 'datagrid', 'property': 'tree'},
      {'id': 'edges', 'label': 'Ränder', 'type': 'array', 'component': 'cardlist', 'property': 'edges'},
      {
        'id': 'stocking',
        'label': 'Bestockung',
        'type': 'column',
        'items': [
          {
            'id': 'stocking',
            'type': 'card',
            'items': [
              {
                'id': 'general',
                'type': 'form',
                'properties': [
                  {'name': 'stand_structure'},
                  {'name': 'stand_age'},
                ],
              },
            ],
          },
          {
            'id': 'stocking_tabs',
            'type': 'tabs',
            'items': [
              {
                'id': 'lt4m',
                'label': 'kleiner 4 Meter Höhe',
                'type': 'column',
                'items': [
                  {
                    'id': 'general',
                    'type': 'form',
                    'properties': [
                      {'name': 'trees_less_4meter_coverage'},
                      {'name': 'trees_less_4meter_layer'},
                    ],
                  },
                  {'id': 'structure_lt4m', 'type': 'array', 'component': 'datagrid', 'property': 'structure_lt4m'},
                ],
              },
              {
                'id': 'gt4m',
                'label': 'größer 4 Meter Höhe',
                'type': 'column',
                'items': [
                  {
                    'id': 'wzp4_tree_count',
                    'type': 'object',
                    'component': 'array_summary',
                    'property': 'tree',
                    'options': {
                      'filter': [
                        {'field': 'tree_status', 'operator': 'in', 'values': [0, 1]},
                      ],
                    },
                  },
                  {
                    'id': 'general',
                    'type': 'form',
                    'properties': [
                      {'name': 'trees_greater_4meter_mirrored'},
                      {'name': 'trees_greater_4meter_basal_area_factor'},
                    ],
                  },
                  {'id': 'structure_gt4m', 'type': 'array', 'component': 'datagrid', 'property': 'structure_gt4m'},
                ],
              },
            ],
          },
        ],
      },
    ],
  },
  'components': <String, dynamic>{},
};

void main() {
  group('LayoutService.getPropertyPathsForTab', () {
    test('collects form fields through nested cards, columns and tabs', () {
      final paths = LayoutService.getPropertyPathsForTab(_layout(), 'stocking');
      expect(
        paths,
        containsAll([
          'stand_structure',
          'stand_age',
          'trees_less_4meter_coverage',
          'trees_less_4meter_layer',
          'structure_lt4m',
          'trees_greater_4meter_mirrored',
          'trees_greater_4meter_basal_area_factor',
          'structure_gt4m',
        ]),
      );
    });

    test('skips the array_summary so Bestockung does not own the WZP4 trees', () {
      expect(LayoutService.getPropertyPathsForTab(_layout(), 'stocking'), isNot(contains('tree')));
      expect(LayoutService.getPropertyPathsForTab(_layout(), 'tree'), ['tree']);
    });

    test('returns nothing for an unknown tab or missing layout', () {
      expect(LayoutService.getPropertyPathsForTab(_layout(), 'nope'), isEmpty);
      expect(LayoutService.getPropertyPathsForTab(null, 'stocking'), isEmpty);
    });
  });

  group('LayoutService.findTabIdForError', () {
    final layout = _layout();

    test('attributes Bestockung fields to Bestockung, not to Ecke (#477 screenshots)', () {
      // 614006 / 614106: the two errors the app's result dialog listed under "Ecke"
      expect(LayoutService.findTabIdForError(layout, instancePath: '/trees_less_4meter_coverage'), 'stocking');
      expect(LayoutService.findTabIdForError(layout, instancePath: '/trees_less_4meter_layer'), 'stocking');
      // 613912: Zählfaktor warning
      expect(
        LayoutService.findTabIdForError(layout, instancePath: '/trees_greater_4meter_basal_area_factor'),
        'stocking',
      );
    });

    test('attributes tree rows to WZP4 even though Bestockung shows their count', () {
      expect(LayoutService.findTabIdForError(layout, instancePath: '/tree/3/dbh'), 'tree');
      expect(LayoutService.findTabIdForError(layout, instancePath: '/tree'), 'tree');
    });

    test('attributes Ecke fields to Ecke', () {
      expect(LayoutService.findTabIdForError(layout, instancePath: '/marker_status'), 'habitat_and_stocking');
    });

    test('matches whole path segments only', () {
      // "tree_status" is not under the "tree" array
      expect(LayoutService.findTabIdForError(layout, instancePath: '/tree_status'), isNull);
      expect(LayoutService.findTabIdForError(layout, instancePath: '/edges_count'), isNull);
    });

    test('uses missingProperty for a root-level required error', () {
      expect(
        LayoutService.findTabIdForError(layout, instancePath: '', missingProperty: 'structure_gt4m'),
        'stocking',
      );
      expect(LayoutService.findTabIdForError(layout, instancePath: '', missingProperty: 'edges'), 'edges');
    });

    test('returns null when no tab owns the path', () {
      expect(LayoutService.findTabIdForError(layout, instancePath: '/cluster_name'), isNull);
      expect(LayoutService.findTabIdForError(null, instancePath: '/tree/0/dbh'), isNull);
    });
  });

  test('LayoutService.getTabLabel resolves the tab caption', () {
    expect(LayoutService.getTabLabel(_layout(), 'stocking'), 'Bestockung');
    expect(LayoutService.getTabLabel(_layout(), 'messages'), 'messages');
    expect(LayoutService.getTabLabel(_layout(), 'nope'), isNull);
  });
}
