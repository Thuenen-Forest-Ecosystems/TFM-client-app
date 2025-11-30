import 'dart:async';

class ValidationService {
  static ValidationService? _instance;

  ValidationService._();

  static ValidationService get instance {
    _instance ??= ValidationService._();
    return _instance!;
  }

  Future<void> initialize({String? tfmValidationCode}) async {
    print('ValidationService: Web platform - validation not supported');
  }

  Future<ValidationResult> validate(
    Map<String, dynamic> schema,
    Map<String, dynamic> data, {
    String? validationCode,
  }) async {
    // On web, just return valid - no actual validation
    print('ValidationService: Web platform - skipping validation');
    return ValidationResult(isValid: true, errors: []);
  }

  Future<Map<String, dynamic>> validateWithAJV({
    required Map<String, dynamic> schema,
    required Map<String, dynamic> data,
  }) async {
    throw UnsupportedError('AJV validation not available on web platform');
  }

  Future<TFMValidationResult> validateWithTFM({
    required Map<String, dynamic> data,
    String? validationCode,
  }) async {
    throw UnsupportedError('TFM validation not available on web platform');
  }

  Future<void> dispose() async {
    print('ValidationService: Web dispose - no-op');
  }
}

// Validation result classes - must match validation_service_io.dart
class ValidationResult {
  final bool isValid;
  final List<ValidationError> errors;

  ValidationResult({required this.isValid, required this.errors});

  @override
  String toString() {
    return 'ValidationResult(isValid: $isValid, errors: ${errors.length})';
  }
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

  factory ValidationError.fromJson(Map<String, dynamic> json) {
    return ValidationError(
      instancePath: json['instancePath'] as String?,
      schemaPath: json['schemaPath'] as String?,
      keyword: json['keyword'] as String?,
      message: json['message'] as String? ?? 'Unknown error',
      params: json['params'] as Map<String, dynamic>?,
      rawError: json,
    );
  }

  @override
  String toString() {
    return 'ValidationError(path: $instancePath, message: $message, rawError: $rawError)';
  }
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

  bool get isValid => ajvValid && !hasTFMErrors;
  bool get hasTFMErrors => tfmErrors.any((e) => e.isError);
  List<TFMValidationError> get tfmOnlyErrors => tfmErrors.where((e) => e.isError).toList();
  List<TFMValidationError> get tfmWarnings => tfmErrors.where((e) => e.isWarning).toList();
  List<dynamic> get allErrors => [...ajvErrors, ...tfmOnlyErrors];
  List<dynamic> get allIssues => [...ajvErrors, ...tfmErrors];

  @override
  String toString() {
    return 'TFMValidationResult(ajvValid: $ajvValid, ajvErrors: ${ajvErrors.length}, '
        'tfmAvailable: $tfmAvailable, tfmErrors: ${tfmOnlyErrors.length}, tfmWarnings: ${tfmWarnings.length})';
  }
}

class TFMValidationError {
  final String? instancePath;
  final Map<String, dynamic>? error;
  final String? debugInfo;

  TFMValidationError({this.instancePath, this.error, this.debugInfo});

  factory TFMValidationError.fromJson(Map<String, dynamic> json) {
    return TFMValidationError(
      instancePath: json['instancePath'] as String?,
      error: json['error'] as Map<String, dynamic>?,
      debugInfo: json['debugInfo'] as String?,
    );
  }

  String get type => error?['type'] ?? 'error';
  bool get isError => type == 'error';
  bool get isWarning => type == 'warning';
  String get message => error?['text'] ?? 'Unknown TFM error';
  String? get note => error?['note'];

  @override
  String toString() {
    return 'TFMValidationError(path: $instancePath, type: $type, message: $message)';
  }
}
