import 'package:flutter_test/flutter_test.dart';
import 'package:terrestrial_forest_monitor/services/native_schema_validator.dart';
import 'package:terrestrial_forest_monitor/services/validation_types.dart';

/// Proves the native Dart validator reproduces AJV's behaviour (allErrors,
/// strict:false, validateFormats:false) for every keyword the TFM schema uses,
/// including nested recursion, type unions with null, and the German messages.
///
/// The fingerprints below were captured from AJV 8 run against the same inputs.
String _fp(ValidationError e) {
  final String p;
  switch (e.keyword) {
    case 'required':
      p = e.params!['missingProperty'].toString();
    case 'enum':
      p = 'enum';
    case 'type':
      final t = e.params!['type'];
      p = t is List ? t.join(',') : t.toString();
    case 'minimum':
    case 'maximum':
      p = e.params!['limit'].toString();
    default:
      p = '';
  }
  return '${e.instancePath}|${e.keyword}|$p';
}

Set<String> _fps(List<ValidationError> errs) => errs.map(_fp).toSet();

// A miniature of the real schema: object with scalar fields + a nested array
// of objects (mirrors plot -> tree[]).
final schema = <String, dynamic>{
  'type': 'object',
  'required': ['intkey'],
  'properties': {
    'intkey': {'type': 'string'},
    'azimuth': {
      'type': ['integer'],
      'minimum': 0,
      'maximum': 399,
    },
    'dbh': {
      'type': ['integer', 'null'], // nullable union
      'minimum': 70,
    },
    'status': {
      'type': ['integer'],
      'enum': [0, 1, 2, 1111],
    },
    'tree': {
      'type': ['array'],
      'items': {
        'type': 'object',
        'required': ['tree_number'],
        'properties': {
          'tree_number': {'type': 'integer', 'minimum': 1},
          'species': {
            'type': ['integer'],
            'enum': [100, 110, 200],
          },
        },
      },
    },
  },
};

void main() {
  final v = NativeSchemaValidator();

  test('valid data produces no errors (incl. null on nullable union)', () {
    final data = {
      'intkey': 'abc',
      'azimuth': 100,
      'dbh': null, // null allowed by ["integer","null"]
      'status': 1111,
      'tree': [
        {'tree_number': 1, 'species': 110},
        {'tree_number': 5, 'species': 200},
      ],
    };
    final result = v.validate(schema, data);
    expect(result.isValid, isTrue);
    expect(result.errors, isEmpty);
  });

  test('every keyword fires with correct path/param (AJV parity)', () {
    final data = {
      // intkey missing -> required at root
      'azimuth': 500, // > maximum 399
      'dbh': 10, // < minimum 70
      'status': 7, // not in enum
      'tree': [
        {'tree_number': 0}, // < minimum 1
        {'species': 999}, // tree_number missing (required) + species not in enum
        {'tree_number': 'x', 'species': 100}, // tree_number wrong type
      ],
    };
    final got = _fps(v.validateErrors(schema, data));
    expect(
      got,
      equals(<String>{
        '|required|intkey',
        '/azimuth|maximum|399',
        '/dbh|minimum|70',
        '/status|enum|enum',
        '/tree/0/tree_number|minimum|1',
        '/tree/1|required|tree_number',
        '/tree/1/species|enum|enum',
        '/tree/2/tree_number|type|integer',
      }),
    );
  });

  test('type union reports the joined type list, like AJV', () {
    final errs = v.validateErrors(schema, {'intkey': 'a', 'dbh': 'not-a-number'});
    final e = errs.firstWhere((e) => e.instancePath == '/dbh');
    expect(e.keyword, 'type');
    expect(e.params!['type'], ['integer', 'null']);
    expect(e.message, 'muss sein: integer,null');
  });

  test('German (ajv-i18n) messages are reproduced verbatim', () {
    final errs = v.validateErrors(schema, {
      // intkey omitted -> triggers the required error asserted below
      'azimuth': 500,
      'status': 7,
      'tree': [
        {'tree_number': 0},
      ],
    });
    final byPath = {for (final e in errs) e.instancePath: e.message};
    expect(byPath['/azimuth'], 'muss <= 399 sein');
    expect(byPath['/status'], 'muss einem der vorgegebenen Werte entsprechen');
    expect(byPath['/tree/0/tree_number'], 'muss >= 1 sein');
    final reqErr = errs.firstWhere((e) => e.keyword == 'required');
    expect(reqErr.message, 'muss das erforderliche Attribut intkey enthalten');
  });
}
