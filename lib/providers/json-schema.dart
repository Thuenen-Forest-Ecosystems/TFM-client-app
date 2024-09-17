import 'package:flutter/foundation.dart';
import 'package:json_schema/json_schema.dart';

// https://pub.dev/documentation/json_schema/latest/json_schema/JsonSchema-class.html

class JsonSchemaProvider with ChangeNotifier, DiagnosticableTreeMixin {
  Map _schema = const {};
  Map _values = const {};

  late JsonSchema _jsonSchema;

  JsonSchemaProvider();

  Map get schema => _schema;
  Map get values => _values;

  void initiate(Map schema, Map values) {
    _schema = schema;
    _values = values;
    _jsonSchema = JsonSchema.create(_schema);

    notifyListeners();
  }

  void validate() {
    final isValid = _jsonSchema.validate(_values);
    // Get the errors
    for (var error in isValid.errors) {
      print(error.instancePath);
      print(error.runtimeType);
      print(error.schemaPath);
    }
  }

  /*
  /// Makes `Counter` readable inside the devtools by listing all of its properties
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('locale', _schema.toString()));
  }
  */
}
