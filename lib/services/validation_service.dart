import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class ValidationService {
  static ValidationService? _instance;
  HeadlessInAppWebView? _headlessWebView;
  InAppWebViewController? _webViewController;
  bool _isInitialized = false;
  bool _isTFMLoaded = false;
  Completer<void>? _initCompleter;

  ValidationService._();

  static ValidationService get instance {
    _instance ??= ValidationService._();
    return _instance!;
  }

  Future<void> initialize({String? tfmValidationCode}) async {
    if (_isInitialized) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();

    try {
      // Load AJV library from assets
      final ajvCode = await rootBundle.loadString('assets/html/ajv7.min.js');
      print('AJV library loaded from assets');

      // Initialize headless WebView with inline AJV + optional TFM validation
      _headlessWebView = HeadlessInAppWebView(
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          allowUniversalAccessFromFileURLs: true,
          allowFileAccessFromFileURLs: true,
        ),
        initialData: InAppWebViewInitialData(
          data:
              '''
            <!DOCTYPE html>
            <html>
            <head>
              <meta charset="utf-8">
              <script>
                $ajvCode
              </script>
              ${tfmValidationCode != null ? '<script>$tfmValidationCode</script>' : ''}
            </head>
            <body>
              <script>
                console.log('AJV loaded:', typeof window.ajv7);
                console.log('TFM loaded:', typeof window.TFM);
              </script>
            </body>
            </html>
          ''',
          baseUrl: WebUri('about:blank'),
        ),
        onWebViewCreated: (controller) {
          _webViewController = controller;
          print('Headless WebView created for validation');
        },
        onLoadStop: (controller, url) async {
          print('Headless WebView loaded: $url');

          // Verify AJV is loaded
          final ajvCheck = await controller.evaluateJavascript(source: 'typeof window.ajv7');
          print('AJV type check: $ajvCheck');

          // Verify TFM is loaded (if provided)
          if (tfmValidationCode != null) {
            final tfmCheck = await controller.evaluateJavascript(source: 'typeof window.TFM');
            print('TFM type check: $tfmCheck');
            _isTFMLoaded = tfmCheck == 'function';
          }

          if (ajvCheck == 'function') {
            _isInitialized = true;
            _initCompleter?.complete();
            print('Validation service initialized successfully (TFM: $_isTFMLoaded)');
          } else {
            final error = Exception('AJV library not loaded properly. Type: $ajvCheck');
            _initCompleter?.completeError(error);
            throw error;
          }
        },
        onConsoleMessage: (controller, consoleMessage) {
          print('WebView Console: ${consoleMessage.message}');
        },
      );

      await _headlessWebView!.run();

      // Wait for the onLoadStop callback to complete initialization
      await _initCompleter!.future;
    } catch (e) {
      print('Error initializing validation service: $e');
      if (!(_initCompleter?.isCompleted ?? true)) {
        _initCompleter?.completeError(e);
      }
      rethrow;
    }
  }

  Future<ValidationResult> validate(Map<String, dynamic> schema, Map<String, dynamic> data) async {
    if (!_isInitialized || _webViewController == null) {
      throw Exception('Validation service not initialized. Call initialize() first.');
    }

    try {
      final schemaJson = jsonEncode(schema);
      final dataJson = jsonEncode(data);

      final jsCode =
          '''
        (function() {
          try {
            const ajv = new window.ajv7({ 
              allErrors: true,
              strict: false,
              validateFormats: false
            });
            const validate = ajv.compile($schemaJson);
            const valid = validate($dataJson);
            
            console.log('Validation result:', valid);
            console.log('Validation errors:', JSON.stringify(validate.errors));
            console.log('Number of errors:', validate.errors ? validate.errors.length : 0);
            
            return {
              valid: valid,
              errors: validate.errors || []
            };
          } catch (error) {
            console.error('Validation exception:', error);
            return {
              valid: false,
              errors: [{ message: error.toString() }]
            };
          }
        })();
      ''';

      final result = await _webViewController!.evaluateJavascript(source: jsCode);

      if (result == null) {
        return ValidationResult(
          isValid: false,
          errors: [ValidationError(message: 'Validation returned null')],
        );
      }

      final resultMap = result is String ? jsonDecode(result) : result;

      return ValidationResult(
        isValid: resultMap['valid'] ?? false,
        errors:
            (resultMap['errors'] as List?)?.map((e) => ValidationError.fromJson(e)).toList() ?? [],
      );
    } catch (e) {
      print('Validation error: $e');
      return ValidationResult(
        isValid: false,
        errors: [ValidationError(message: 'Validation exception: $e')],
      );
    }
  }

  /// Run TFM custom validation after AJV validation
  /// Returns combined results from both validators
  Future<TFMValidationResult> validateWithTFM({
    required Map<String, dynamic> schema,
    required Map<String, dynamic> data,
    Map<String, dynamic>? previousData,
  }) async {
    if (!_isInitialized || _webViewController == null) {
      throw Exception('Validation service not initialized. Call initialize() first.');
    }

    try {
      // First run AJV validation
      final ajvResult = await validate(schema, data);

      // If TFM is not loaded, return only AJV results
      if (!_isTFMLoaded) {
        return TFMValidationResult(
          ajvValid: ajvResult.isValid,
          ajvErrors: ajvResult.errors,
          tfmAvailable: false,
          tfmErrors: [],
        );
      }

      // Run TFM validation (runCluster expects array of clusters)
      final dataJson = jsonEncode([data]);
      final previousDataJson = previousData != null ? jsonEncode([previousData]) : 'null';

      final jsCode =
          '''
        (async function() {
          try {
            if (typeof window.TFM === 'undefined') {
              return {
                ajvValid: ${ajvResult.isValid},
                ajvErrors: ${jsonEncode(ajvResult.errors.map((e) => e.rawError).toList())},
                tfmAvailable: false,
                tfmErrors: []
              };
            }

            // Initialize TFM validator
            const tfm = new window.TFM();

            // Run TFM cluster validation
            const tfmErrors = await tfm.runCluster($dataJson, null, $previousDataJson);

            console.log('TFM validation completed. Errors:', tfmErrors ? tfmErrors.length : 0);

            return {
              ajvValid: ${ajvResult.isValid},
              ajvErrors: ${jsonEncode(ajvResult.errors.map((e) => e.rawError).toList())},
              tfmAvailable: true,
              tfmErrors: tfmErrors || []
            };
          } catch (error) {
            console.error('TFM validation exception:', error);
            return {
              ajvValid: ${ajvResult.isValid},
              ajvErrors: ${jsonEncode(ajvResult.errors.map((e) => e.rawError).toList())},
              tfmAvailable: true,
              tfmErrors: [{ 
                instancePath: '',
                error: { type: 'error', text: 'TFM validation failed: ' + error.toString() }
              }]
            };
          }
        })();
      ''';

      final result = await _webViewController!.evaluateJavascript(source: jsCode);

      print('Raw TFM validation result type: ${result.runtimeType}');

      if (result == null) {
        return TFMValidationResult(
          ajvValid: ajvResult.isValid,
          ajvErrors: ajvResult.errors,
          tfmAvailable: false,
          tfmErrors: [],
        );
      }

      final resultMap = result is String ? jsonDecode(result) : result;

      final tfmErrors =
          (resultMap['tfmErrors'] as List?)
              ?.map((e) => TFMValidationError.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];

      print('TFM validation: ${tfmErrors.length} errors/warnings');

      return TFMValidationResult(
        ajvValid: resultMap['ajvValid'] ?? false,
        ajvErrors:
            (resultMap['ajvErrors'] as List?)
                ?.map((e) => ValidationError.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        tfmAvailable: resultMap['tfmAvailable'] ?? false,
        tfmErrors: tfmErrors,
      );
    } catch (e) {
      print('TFM validation error: $e');
      return TFMValidationResult(
        ajvValid: false,
        ajvErrors: [ValidationError(message: 'Validation exception: $e')],
        tfmAvailable: false,
        tfmErrors: [],
      );
    }
  }

  void dispose() {
    _headlessWebView?.dispose();
    _isInitialized = false;
    _isTFMLoaded = false;
  }
}

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

  /// Returns true only if AJV validation passes AND there are no TFM errors (warnings are ok)
  bool get isValid => ajvValid && !hasTFMErrors;

  /// Check if there are any TFM errors (type: 'error')
  bool get hasTFMErrors => tfmErrors.any((e) => e.isError);

  /// Get only TFM errors (not warnings)
  List<TFMValidationError> get tfmOnlyErrors => tfmErrors.where((e) => e.isError).toList();

  /// Get only TFM warnings
  List<TFMValidationError> get tfmWarnings => tfmErrors.where((e) => e.isWarning).toList();

  /// Get all errors (AJV + TFM errors, excluding warnings)
  List<dynamic> get allErrors => [...ajvErrors, ...tfmOnlyErrors];

  /// Get all validation issues (AJV errors + TFM errors + TFM warnings)
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
