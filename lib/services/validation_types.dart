// Shared validation result/error types, decoupled from any engine.
// Used by NativeSchemaValidator, PlausibilityRunner and the form widgets.

class ValidationResult {
  final bool isValid;
  final List<ValidationError> errors;

  ValidationResult({required this.isValid, required this.errors});

  @override
  String toString() => 'ValidationResult(isValid: $isValid, errors: ${errors.length})';
}

class ValidationError {
  final String? instancePath;
  final String? schemaPath;
  final String? keyword;
  final String message;
  final Map<String, dynamic>? params;
  final Map<String, dynamic> rawError;

  ValidationError({
    this.instancePath,
    this.schemaPath,
    this.keyword,
    required this.message,
    this.params,
    Map<String, dynamic>? rawError,
  }) : rawError = rawError ?? {};

  factory ValidationError.fromJson(Map<String, dynamic> json) => ValidationError(
        instancePath: json['instancePath']?.toString(),
        schemaPath: json['schemaPath']?.toString(),
        keyword: json['keyword']?.toString(),
        message: json['message']?.toString() ?? 'Unknown error',
        params: json['params'] as Map<String, dynamic>?,
        rawError: json,
      );

  String get displayMessage =>
      (instancePath != null && instancePath!.isNotEmpty) ? '$instancePath: $message' : message;

  @override
  String toString() => 'ValidationError(path: $instancePath, message: $message)';
}

class TFMValidationResult {
  final bool ajvValid;
  final List<ValidationError> ajvErrors;
  final bool tfmAvailable;
  final List<TFMValidationError> tfmErrors;

  TFMValidationResult({
    required this.ajvValid,
    required this.ajvErrors,
    required this.tfmAvailable,
    required this.tfmErrors,
  });

  /// Valid only if schema validation passes AND there are no TFM errors (warnings are ok).
  bool get isValid => ajvValid && !hasTFMErrors;
  bool get hasTFMErrors => tfmErrors.any((e) => e.isError);
  List<TFMValidationError> get tfmOnlyErrors => tfmErrors.where((e) => e.isError).toList();
  List<TFMValidationError> get tfmWarnings => tfmErrors.where((e) => e.isWarning).toList();
  List<dynamic> get allErrors => [...ajvErrors, ...tfmOnlyErrors];
  List<dynamic> get allIssues => [...ajvErrors, ...tfmErrors];

  @override
  String toString() => 'TFMValidationResult(ajvValid: $ajvValid, ajvErrors: ${ajvErrors.length}, '
      'tfmAvailable: $tfmAvailable, tfmErrors: ${tfmOnlyErrors.length}, tfmWarnings: ${tfmWarnings.length})';
}

class TFMValidationError {
  final String? instancePath;
  final Map<String, dynamic>? error;
  final String? debugInfo;

  TFMValidationError({this.instancePath, this.error, this.debugInfo});

  factory TFMValidationError.fromJson(Map<String, dynamic> json) {
    final errorField = json['error'];
    Map<String, dynamic>? errorMap;
    if (errorField is Map<String, dynamic>) {
      errorMap = errorField;
    } else if (errorField != null) {
      errorMap = {'type': 'error', 'text': errorField.toString()};
    }
    return TFMValidationError(
      instancePath: json['instancePath']?.toString(),
      error: errorMap,
      debugInfo: json['debugInfo']?.toString(),
    );
  }

  String get type => error?['type']?.toString() ?? 'error';
  bool get isError => type == 'error';
  bool get isWarning => type == 'warning';
  String get message => error?['text']?.toString() ?? 'Unknown TFM error';
  String? get note => error?['note']?.toString();

  String get displayMessage =>
      (instancePath != null && instancePath!.isNotEmpty) ? '$instancePath: $message' : message;

  @override
  String toString() => 'TFMValidationError(path: $instancePath, type: $type, message: $message)';
}
