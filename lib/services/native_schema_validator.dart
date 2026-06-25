import 'validation_types.dart';

/// Native Dart JSON-Schema validator covering exactly the keywords the TFM
/// schema uses: type, enum, minimum, maximum, properties, items, required.
///
/// Replaces the AJV-in-WebView path. Mirrors AJV configured with
/// {allErrors: true, strict: false, validateFormats: false} and reproduces the
/// German `ajv-i18n` messages so the UI is unchanged. Error objects keep the
/// AJV shape (instancePath / schemaPath / keyword / params / message) so
/// downstream dialogs that read `rawError` keep working.
///
/// Parity with AJV is asserted in test/native_schema_validator_test.dart.
class NativeSchemaValidator {
  final List<ValidationError> _errors = [];

  ValidationResult validate(Map<String, dynamic> schema, Map<String, dynamic> data) {
    final errors = validateErrors(schema, data);
    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }

  List<ValidationError> validateErrors(dynamic schema, dynamic data) {
    _errors.clear();
    _validate(schema, data, '', '#');
    return List.unmodifiable(_errors);
  }

  void _validate(dynamic schema, dynamic data, String instPath, String schemaPath) {
    if (schema is bool) {
      if (!schema) {
        _add(instPath, '$schemaPath/false schema', 'false schema', {},
            'boolesches Schema ist falsch');
      }
      return;
    }
    if (schema is! Map) return;

    // type
    if (schema.containsKey('type')) {
      final t = schema['type'];
      final types = t is List ? t : [t];
      if (!types.any((tt) => _isType(tt as String, data))) {
        final typeStr = t is List ? t.join(',') : t.toString();
        _add(instPath, '$schemaPath/type', 'type', {'type': t},
            'muss sein: $typeStr');
      }
    }

    // enum
    if (schema.containsKey('enum')) {
      final allowed = schema['enum'] as List;
      if (!allowed.any((v) => _deepEq(v, data))) {
        _add(instPath, '$schemaPath/enum', 'enum', {'allowedValues': allowed},
            'muss einem der vorgegebenen Werte entsprechen');
      }
    }

    // minimum / maximum (only when numeric)
    if (data is num && data is! bool) {
      if (schema.containsKey('minimum')) {
        final limit = schema['minimum'] as num;
        if (data < limit) {
          _add(instPath, '$schemaPath/minimum', 'minimum',
              {'comparison': '>=', 'limit': limit}, 'muss >= ${_numStr(limit)} sein');
        }
      }
      if (schema.containsKey('maximum')) {
        final limit = schema['maximum'] as num;
        if (data > limit) {
          _add(instPath, '$schemaPath/maximum', 'maximum',
              {'comparison': '<=', 'limit': limit}, 'muss <= ${_numStr(limit)} sein');
        }
      }
    }

    // required (only when object)
    if (data is Map && schema['required'] is List) {
      for (final r in (schema['required'] as List)) {
        if (!data.containsKey(r)) {
          _add(instPath, '$schemaPath/required', 'required', {'missingProperty': r},
              'muss das erforderliche Attribut $r enthalten');
        }
      }
    }

    // properties (recurse present keys)
    if (data is Map && schema['properties'] is Map) {
      (schema['properties'] as Map).forEach((k, sub) {
        if (data.containsKey(k)) {
          final ks = k.toString();
          _validate(sub, data[ks], '$instPath/${_esc(ks)}', '$schemaPath/properties/${_esc(ks)}');
        }
      });
    }

    // items (object form: applies to every element)
    if (data is List && schema['items'] is Map) {
      for (var i = 0; i < data.length; i++) {
        _validate(schema['items'], data[i], '$instPath/$i', '$schemaPath/items');
      }
    }
  }

  void _add(String instancePath, String schemaPath, String keyword,
      Map<String, dynamic> params, String message) {
    _errors.add(ValidationError(
      instancePath: instancePath,
      schemaPath: schemaPath,
      keyword: keyword,
      message: message,
      params: params,
      rawError: {
        'instancePath': instancePath,
        'schemaPath': schemaPath,
        'keyword': keyword,
        'params': params,
        'message': message,
      },
    ));
  }

  bool _isType(String t, dynamic d) {
    switch (t) {
      case 'null':
        return d == null;
      case 'boolean':
        return d is bool;
      case 'object':
        return d is Map;
      case 'array':
        return d is List;
      case 'string':
        return d is String;
      case 'number':
        return d is num && d is! bool;
      case 'integer':
        if (d is int) return true;
        if (d is double) return d.isFinite && d == d.roundToDouble();
        return false;
      default:
        return false;
    }
  }

  bool _deepEq(dynamic a, dynamic b) {
    if (a is num && b is num) return a == b;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEq(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final k in a.keys) {
        if (!b.containsKey(k) || !_deepEq(a[k], b[k])) return false;
      }
      return true;
    }
    return a == b;
  }

  String _numStr(num n) {
    if (n is int) return n.toString();
    if (n is double && n.isFinite && n == n.roundToDouble()) return n.toInt().toString();
    return n.toString();
  }

  String _esc(String s) => s.replaceAll('~', '~0').replaceAll('/', '~1');
}
