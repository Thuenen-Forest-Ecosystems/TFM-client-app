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
    // Allow reinitialization only if TFM code is provided and not already loaded
    if (_isInitialized && (tfmValidationCode == null || _isTFMLoaded)) {
      print('ValidationService already initialized (TFM loaded: $_isTFMLoaded)');
      return;
    }

    // If reinitializing with TFM code, dispose existing WebView first
    if (_isInitialized && tfmValidationCode != null && !_isTFMLoaded) {
      print('Reinitializing ValidationService with TFM code');
      await _headlessWebView?.dispose();
      _webViewController = null;
      _isInitialized = false;
      _isTFMLoaded = false;
      _initCompleter = null;

      // Small delay to ensure WebView is fully disposed
      await Future.delayed(Duration(milliseconds: 100));
    }

    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();

    try {
      // Load AJV library from assets
      final ajvCode = await rootBundle.loadString('assets/html/ajv7.min.js');
      print('AJV library loaded from assets');

      // Load AJV i18n library from assets
      String ajvI18nCode = '';
      try {
        ajvI18nCode = await rootBundle.loadString('assets/html/ajv-i18n.min.js');
        print('AJV i18n library loaded from assets');
      } catch (e) {
        print('AJV i18n library not found: $e');
      }

      // Initialize headless WebView with inline AJV + optional TFM validation
      _headlessWebView = HeadlessInAppWebView(
        initialSettings: InAppWebViewSettings(javaScriptEnabled: true, allowUniversalAccessFromFileURLs: true, allowFileAccessFromFileURLs: true),
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
              <script>
                $ajvI18nCode
              </script>
              ${tfmValidationCode != null ? '<script>$tfmValidationCode</script>' : ''}
            </head>
            <body>
              <script>
                console.log('AJV loaded:', typeof window.ajv7);
                console.log('AJV i18n loaded:', typeof window.ajvI18n);
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
            print('Setting _isTFMLoaded to: $_isTFMLoaded before completing');
            _initCompleter?.complete();
            print('Validation service initialized successfully (TFM: $_isTFMLoaded)');
            print('_initCompleter completed, _isTFMLoaded is now: $_isTFMLoaded');
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
            
            if (!valid && window.ajvI18n && window.ajvI18n.de) {
               window.ajvI18n.de(validate.errors);
            }
            
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
        return ValidationResult(isValid: false, errors: [ValidationError(message: 'Validation returned null')]);
      }

      final resultMap = result is String ? jsonDecode(result) : result;

      // Normalize errors to Map<String, dynamic> via JSON round-trip to avoid Map<Object?, Object?> types
      final rawErrors = resultMap['errors'] as List?;
      List<dynamic> normalizedErrors = const [];
      if (rawErrors != null) {
        try {
          normalizedErrors = jsonDecode(jsonEncode(rawErrors)) as List<dynamic>;
        } catch (e) {
          print('Validation error normalization failed: $e');
        }
      }

      final parsedErrors = normalizedErrors.map((e) => ValidationError.fromJson(e as Map<String, dynamic>)).toList();

      return ValidationResult(isValid: resultMap['valid'] ?? false, errors: parsedErrors);
    } catch (e) {
      print('Validation error: $e');
      return ValidationResult(isValid: false, errors: [ValidationError(message: 'Validation exception: $e')]);
    }
  }

  /// Run TFM custom validation after AJV validation
  /// Returns combined results from both validators
  Future<TFMValidationResult> validateWithTFM({required Map<String, dynamic> schema, required Map<String, dynamic> data, Map<String, dynamic>? previousData}) async {
    if (!_isInitialized || _webViewController == null) {
      throw Exception('Validation service not initialized. Call initialize() first.');
    }

    try {
      // First run AJV validation
      final ajvResult = await validate(schema, data);

      // If TFM is not loaded, return only AJV results
      print('TFM validation check: _isTFMLoaded = $_isTFMLoaded');
      if (!_isTFMLoaded) {
        print('TFM not loaded, returning AJV-only results');
        return TFMValidationResult(ajvValid: ajvResult.isValid, ajvErrors: ajvResult.errors, tfmAvailable: false, tfmErrors: []);
      }

      // Run TFM validation (runPlots expects array of plot objects)
      // Wrap data in array as runPlots expects: [plotData, ...]
      final dataJson = jsonEncode([data]);
      final previousDataJson = previousData != null ? jsonEncode([previousData]) : 'null';

      final jsCode =
          '''
          try {
            console.log('TFM type in validation:', typeof window.TFM);
            console.log('TFM constructor:', window.TFM);
            
            if (typeof window.TFM === 'undefined' || typeof window.TFM !== 'function') {
              console.log('TFM not available for validation');
              return {
                ajvValid: ${ajvResult.isValid},
                ajvErrors: ${jsonEncode(ajvResult.errors.map((e) => e.rawError).toList())},
                tfmAvailable: false,
                tfmErrors: []
              };
            }

            console.log('TFM is available, initializing...');
            // Initialize TFM validator
            const tfm = new window.TFM();

            // Run TFM plot validation
            // dataJson and previousDataJson are already JSON strings, parse them
            const currentData = $dataJson;
            const previousData = $previousDataJson;
            
            console.log('Current plot data:', currentData);
            console.log('Previous plot data:', previousData);
            console.log('Current data keys:', currentData[0] ? Object.keys(currentData[0]).slice(0, 10) : 'none');
            console.log('Previous data keys:', previousData && previousData[0] ? Object.keys(previousData[0]).slice(0, 10) : 'none');
            
            const tfmErrors = await tfm.runPlots(currentData, null, previousData);

            console.log('tfmErrors:');
            console.log(JSON.stringify(tfmErrors));
            console.log('TFM validation completed. Errors:', tfmErrors ? tfmErrors.length : 0);

            const result = {
              ajvValid: ${ajvResult.isValid},
              ajvErrors: ${jsonEncode(ajvResult.errors.map((e) => e.rawError).toList())},
              tfmAvailable: true,
              tfmErrors: tfmErrors || []
            };
            
            console.log('Returning result:', JSON.stringify(result));
            return result;
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
      ''';

      final callResult = await _webViewController!.callAsyncJavaScript(functionBody: jsCode, arguments: {});

      final result = callResult?.value;

      print('Raw TFM validation result type: ${result.runtimeType}');
      print('Raw TFM validation result: $result');

      if (result == null) {
        return TFMValidationResult(ajvValid: ajvResult.isValid, ajvErrors: ajvResult.errors, tfmAvailable: false, tfmErrors: []);
      }

      final resultMap = result is String ? jsonDecode(result) : result;
      print('Result map tfmAvailable: ${resultMap['tfmAvailable']}');
      print('Result map keys: ${resultMap.keys}');

      final tfmErrors = (resultMap['tfmErrors'] as List?)?.map((e) => TFMValidationError.fromJson(e as Map<String, dynamic>)).toList() ?? [];

      print('TFM validation: ${tfmErrors.length} errors/warnings');

      return TFMValidationResult(
        ajvValid: resultMap['ajvValid'] ?? false,
        ajvErrors: (resultMap['ajvErrors'] as List?)?.map((e) => ValidationError.fromJson(e as Map<String, dynamic>)).toList() ?? [],
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

  ValidationError({this.instancePath, this.schemaPath, this.keyword, required this.message, this.params, Map<String, dynamic>? rawError}) : rawError = rawError ?? {};

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

  TFMValidationResult({required this.ajvValid, required this.ajvErrors, required this.tfmAvailable, required this.tfmErrors});

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
    return TFMValidationError(instancePath: json['instancePath'] as String?, error: json['error'] as Map<String, dynamic>?, debugInfo: json['debugInfo'] as String?);
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
