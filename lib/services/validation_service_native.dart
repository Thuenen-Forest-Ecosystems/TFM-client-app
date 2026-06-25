import 'dart:async';

import 'native_schema_validator.dart';
import 'plausibility_runner.dart';
import 'validation_types.dart';

/// In-process validation service (replaced the headless-WebView
/// `ValidationService`). Same public API — `initialize` / `validate` /
/// `validateWithTFM` / `dispose` / `handleAppPaused` — and the same result
/// types ([ValidationResult], [TFMValidationResult]).
///
/// Split architecture (no WebView, no AJV-in-JS):
///   • JSON-Schema validation  -> [NativeSchemaValidator] (pure Dart)
///   • TFM plausibility checks  -> [PlausibilityRunner] (flutter_js / QuickJS)
///
/// Both the schema and the plausibility script remain synced over Postgres, so
/// validation is still updatable without an app release.
class ValidationServiceNative {
  ValidationServiceNative._();
  static final ValidationServiceNative instance = ValidationServiceNative._();

  final NativeSchemaValidator _schema = NativeSchemaValidator();

  /// Preloads the plausibility engine with the given script (the synced
  /// `schemas.plausability_script`). Safe to call with no args to no-op.
  Future<void> initialize({String? tfmValidationCode}) async {
    await PlausibilityRunner.instance.initialize(tfmValidationCode: tfmValidationCode);
  }

  /// JSON-Schema-only validation (native Dart, synchronous under the hood).
  Future<ValidationResult> validate(
    Map<String, dynamic> schema,
    Map<String, dynamic> data,
  ) async {
    return _schema.validate(schema, data);
  }

  /// Full validation: native schema validation + TFM plausibility checks.
  /// Mirrors the WebView service's combined result so call sites are unchanged.
  Future<TFMValidationResult> validateWithTFM({
    required Map<String, dynamic> schema,
    required Map<String, dynamic> data,
    Map<String, dynamic>? previousData,
    List<Map<String, dynamic>>? treeSpeciesLookup,
  }) async {
    final ajvErrors = _schema.validateErrors(schema, data);

    List<TFMValidationError> tfmErrors = const [];
    try {
      tfmErrors = await PlausibilityRunner.instance.runPlots(
        data: data,
        previousData: previousData,
        treeSpeciesLookup: treeSpeciesLookup,
      );
    } catch (e) {
      tfmErrors = [
        TFMValidationError(instancePath: '', error: {
          'type': 'error',
          'text': 'Plausibility validation failed: $e',
        }),
      ];
    }

    return TFMValidationResult(
      ajvValid: ajvErrors.isEmpty,
      ajvErrors: ajvErrors,
      tfmAvailable: PlausibilityRunner.instance.isLoaded,
      tfmErrors: tfmErrors,
    );
  }

  Future<void> handleAppPaused() => PlausibilityRunner.instance.handleAppPaused();

  Future<void> dispose() => PlausibilityRunner.instance.dispose();
}
