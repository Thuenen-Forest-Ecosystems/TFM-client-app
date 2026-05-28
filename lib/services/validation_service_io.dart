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
  bool _isDisposing = false;
  Completer<void>? _initCompleter;

  // Energy optimization: WebView2 (especially on Windows) runs a full browser
  // host process in the background. Disposing it during idle periods and when
  // the app is backgrounded reduces CPU/RAM usage significantly. The next
  // validate() call transparently re-initializes the engine using the last
  // known TFM code.
  Timer? _idleTimer;
  String? _lastTfmValidationCode;
  Completer<void>? _disposeCompleter;
  static const Duration _idleTimeout = Duration(minutes: 2);
  Future<void> _validationQueue = Future.value();

  ValidationService._();

  static ValidationService get instance {
    _instance ??= ValidationService._();
    return _instance!;
  }

  /// Serializes validation operations to a single pipeline so WebView JS
  /// calls never overlap across widgets/screens.
  Future<T> _enqueueValidation<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _validationQueue = _validationQueue
        .catchError((_) {})
        .then((_) async {
          try {
            completer.complete(await operation());
          } catch (e, st) {
            completer.completeError(e, st);
          }
        })
        .catchError((_) {});
    return completer.future;
  }

  Future<void> initialize({String? tfmValidationCode}) async {
    // If a dispose (idle/background) is in progress, wait for it to finish
    // before re-initializing so we don't tear down a freshly-created WebView.
    if (_disposeCompleter != null) {
      try {
        await _disposeCompleter!.future;
      } catch (_) {}
    }

    // Remember the latest TFM code so we can transparently re-initialize after
    // an idle dispose without callers having to know about the lifecycle.
    if (tfmValidationCode != null) {
      _lastTfmValidationCode = tfmValidationCode;
    }

    // Allow reinitialization only if TFM code is provided and not already loaded
    if (_isInitialized && (tfmValidationCode == null || _isTFMLoaded)) {
      return;
    }

    // If reinitializing with TFM code, dispose existing WebView first
    if (_isInitialized && tfmValidationCode != null && !_isTFMLoaded) {
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

      // Load AJV i18n library from assets
      String ajvI18nCode = '';
      try {
        ajvI18nCode = await rootBundle.loadString('assets/html/ajv-i18n.min.js');
      } catch (e) {}

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
        },
        onLoadStop: (controller, url) async {
          // Verify AJV is loaded
          final ajvCheck = await controller.evaluateJavascript(source: 'typeof window.ajv7');

          // Verify TFM is loaded (if provided)
          if (tfmValidationCode != null) {
            final tfmCheck = await controller.evaluateJavascript(source: 'typeof window.TFM');
            _isTFMLoaded = tfmCheck == 'function';
          }

          if (ajvCheck == 'function') {
            _isInitialized = true;
            _initCompleter?.complete();
          } else {
            final error = Exception('AJV library not loaded properly. Type: $ajvCheck');
            _initCompleter?.completeError(error);
            throw error;
          }
        },
        onConsoleMessage: (controller, consoleMessage) {
          // ${consoleMessage.message}
        },
      );

      await _headlessWebView!.run();

      // Wait for the onLoadStop callback to complete initialization
      await _initCompleter!.future;
    } catch (e) {
      if (!(_initCompleter?.isCompleted ?? true)) {
        _initCompleter?.completeError(e);
      }
      rethrow;
    }
  }

  Future<ValidationResult> validate(Map<String, dynamic> schema, Map<String, dynamic> data) {
    return _enqueueValidation(() => _validateUnsafe(schema, data));
  }

  Future<ValidationResult> _validateUnsafe(
    Map<String, dynamic> schema,
    Map<String, dynamic> data,
  ) async {
    await _ensureInitialized();
    _resetIdleTimer();

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
            
            // console.log('Validation result:', valid);
            // console.log('Validation errors:', JSON.stringify(validate.errors));
            // console.log('Number of errors:', validate.errors ? validate.errors.length : 0);
            
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

      final result = await _webViewController!
          .evaluateJavascript(source: jsCode)
          .timeout(const Duration(seconds: 15));

      if (result == null) {
        return ValidationResult(
          isValid: false,
          errors: [ValidationError(message: 'Validation returned null')],
        );
      }

      final resultMap = result is String ? jsonDecode(result) : result;

      // Normalize errors to Map<String, dynamic> via JSON round-trip to avoid Map<Object?, Object?> types
      final rawErrors = resultMap['errors'] as List?;
      List<dynamic> normalizedErrors = const [];
      if (rawErrors != null) {
        try {
          normalizedErrors = jsonDecode(jsonEncode(rawErrors)) as List<dynamic>;
        } catch (e) {}
      }

      final parsedErrors = normalizedErrors
          .map((e) => ValidationError.fromJson(e as Map<String, dynamic>))
          .toList();

      return ValidationResult(isValid: resultMap['valid'] ?? false, errors: parsedErrors);
    } catch (e) {
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
    List<Map<String, dynamic>>? treeSpeciesLookup,
  }) {
    return _enqueueValidation(
      () => _validateWithTFMUnsafe(
        schema: schema,
        data: data,
        previousData: previousData,
        treeSpeciesLookup: treeSpeciesLookup,
      ),
    );
  }

  Future<TFMValidationResult> _validateWithTFMUnsafe({
    required Map<String, dynamic> schema,
    required Map<String, dynamic> data,
    Map<String, dynamic>? previousData,
    List<Map<String, dynamic>>? treeSpeciesLookup,
  }) async {
    await _ensureInitialized();
    _resetIdleTimer();

    try {
      // First run AJV validation
      final ajvResult = await _validateUnsafe(schema, data);

      // If TFM is not loaded, return only AJV results
      if (!_isTFMLoaded) {
        return TFMValidationResult(
          ajvValid: ajvResult.isValid,
          ajvErrors: ajvResult.errors,
          tfmAvailable: false,
          tfmErrors: [],
        );
      }

      // Run TFM validation (runPlots expects array of plot objects)
      // Wrap data in array as runPlots expects: [plotData, ...]
      final dataJson = jsonEncode([data]);
      // Pass empty array instead of null when no previous data to avoid undefined errors in TFM
      final previousDataJson = previousData != null ? jsonEncode([previousData]) : '[]';

      // Prepare lookup tables object for TFM constructor
      final lookupTablesJson = treeSpeciesLookup != null
          ? jsonEncode({'tree_species': treeSpeciesLookup})
          : '{}';

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
            // Initialize TFM validator with lookup tables
            // TFM constructor: (host, apikey, lookupTables)
            const lookupTables = $lookupTablesJson;

            const tfm = new window.TFM(null, null, lookupTables);

            // Run TFM plot validation
            // dataJson and previousDataJson are already JSON strings, parse them
            const currentData = $dataJson;
            const previousData = $previousDataJson;
            
            let tfmErrors;
            try {
              tfmErrors = await tfm.runPlots(currentData, '/plot', previousData);
            } catch (tfmError) {
              console.error('TFM runPlots error:', tfmError);
              console.error('TFM error stack:', tfmError.stack);
              console.error('TFM error message:', tfmError.message);
              
              // Extract more details from the error
              const errorDetails = {
                message: tfmError.message,
                stack: tfmError.stack,
                name: tfmError.name
              };
              
              return {
                ajvValid: ${ajvResult.isValid},
                ajvErrors: ${jsonEncode(ajvResult.errors.map((e) => e.rawError).toList())},
                tfmAvailable: true,
                tfmErrors: [{ 
                  instancePath: '',
                  error: { 
                    type: 'error', 
                    text: 'TFM runPlots failed: ' + tfmError.message,
                    note: 'Stack: ' + (tfmError.stack || 'no stack trace')
                  },
                  debugInfo: JSON.stringify(errorDetails)
                }]
              };
            }

            console.log('tfmErrors:');
            console.log(JSON.stringify(tfmErrors));
            console.log('TFM validation completed. Errors:', tfmErrors ? tfmErrors.length : 0);

            const result = {
              ajvValid: ${ajvResult.isValid},
              ajvErrors: ${jsonEncode(ajvResult.errors.map((e) => e.rawError).toList())},
              tfmAvailable: true,
              tfmErrors: tfmErrors || []
            };
            
            // console.log('Returning result:', JSON.stringify(result));
            return result;
          } catch (error) {
            console.error('TFM validation exception:', error);
            console.error('Error stack:', error.stack);
            return {
              ajvValid: ${ajvResult.isValid},
              ajvErrors: ${jsonEncode(ajvResult.errors.map((e) => e.rawError).toList())},
              tfmAvailable: true,
              tfmErrors: [{ 
                instancePath: '',
                error: { 
                  type: 'error', 
                  text: 'TFM validation failed: ' + error.message,
                  note: 'Stack: ' + (error.stack || 'no stack trace')
                }
              }]
            };
          }
      ''';

      final callResult = await _webViewController!
          .callAsyncJavaScript(functionBody: jsCode, arguments: {})
          .timeout(const Duration(seconds: 20));

      final result = callResult?.value;

      if (result == null) {
        return TFMValidationResult(
          ajvValid: ajvResult.isValid,
          ajvErrors: ajvResult.errors,
          tfmAvailable: false,
          tfmErrors: [],
        );
      }

      // Normalize via JSON round-trip to convert Map<Object?, Object?> → Map<String, dynamic>
      // (callAsyncJavaScript can return nested maps with Object? keys/values)
      final rawMap = result is String ? jsonDecode(result) : result;
      final resultMap = jsonDecode(jsonEncode(rawMap)) as Map<String, dynamic>;

      final tfmErrors =
          (resultMap['tfmErrors'] as List?)
              ?.map((e) => TFMValidationError.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];

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
      return TFMValidationResult(
        ajvValid: false,
        ajvErrors: [ValidationError(message: 'Validation exception: $e')],
        tfmAvailable: false,
        tfmErrors: [],
      );
    }
  }

  Future<void> dispose() async {
    _idleTimer?.cancel();
    _idleTimer = null;
    _lastTfmValidationCode = null;
    await _validationQueue.catchError((_) {});
    await _disposeWebViewKeepInstance();
  }

  /// Called by AppLifecycleManager when the app is backgrounded / hidden.
  /// Disposes the WebView while preserving the singleton + remembered TFM
  /// code so the next validate() call transparently re-initializes.
  Future<void> handleAppPaused() async {
    await _validationQueue.catchError((_) {});
    await _disposeWebViewKeepInstance();
  }

  /// Ensure the WebView is up. Re-creates it (using the last known TFM code)
  /// if it was disposed by the idle timer or by an app-lifecycle event.
  Future<void> _ensureInitialized() async {
    if (_isInitialized && _webViewController != null) return;
    await initialize(tfmValidationCode: _lastTfmValidationCode);
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, () {
      // Fire-and-forget; errors are non-fatal (next validate re-initializes).
      // Queue disposal after in-flight validations complete.
      _validationQueue = _validationQueue
          .catchError((_) {})
          .then((_) => _disposeWebViewKeepInstance())
          .catchError((_) {});
    });
  }

  Future<void> _disposeWebViewKeepInstance() async {
    _idleTimer?.cancel();
    _idleTimer = null;

    if (_isDisposing) {
      if (_disposeCompleter != null) {
        try {
          await _disposeCompleter!.future;
        } catch (_) {}
      }
      return;
    }
    if (_headlessWebView == null && !_isInitialized) return;

    _isDisposing = true;
    _disposeCompleter = Completer<void>();
    try {
      final headlessWebView = _headlessWebView;
      _headlessWebView = null;
      _webViewController = null;

      if (headlessWebView != null) {
        try {
          await headlessWebView.dispose();
        } catch (_) {}
      }
    } finally {
      _isInitialized = false;
      _isTFMLoaded = false;
      _initCompleter = null;
      _isDisposing = false;
      _disposeCompleter?.complete();
      _disposeCompleter = null;
    }
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
      instancePath: json['instancePath']?.toString(),
      schemaPath: json['schemaPath']?.toString(),
      keyword: json['keyword']?.toString(),
      message: json['message']?.toString() ?? 'Unknown error',
      params: json['params'] as Map<String, dynamic>?,
      rawError: json,
    );
  }

  String get displayMessage {
    if (instancePath != null && instancePath!.isNotEmpty) {
      return '$instancePath: $message';
    }
    return message;
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

  String get displayMessage {
    if (instancePath != null && instancePath!.isNotEmpty) {
      return '$instancePath: $message';
    }
    return message;
  }

  @override
  String toString() {
    return 'TFMValidationError(path: $instancePath, type: $type, message: $message)';
  }
}
