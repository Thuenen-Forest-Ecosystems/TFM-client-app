import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class ValidationService {
  static ValidationService? _instance;
  HeadlessInAppWebView? _headlessWebView;
  InAppWebViewController? _webViewController;
  bool _isInitialized = false;
  Completer<void>? _initCompleter;

  ValidationService._();

  static ValidationService get instance {
    _instance ??= ValidationService._();
    return _instance!;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();

    try {
      // Load AJV library from assets
      final ajvCode = await rootBundle.loadString('assets/html/ajv7.min.js');
      print('AJV library loaded from assets');

      // Initialize headless WebView with inline AJV
      _headlessWebView = HeadlessInAppWebView(
        initialSettings: InAppWebViewSettings(javaScriptEnabled: true, allowUniversalAccessFromFileURLs: true, allowFileAccessFromFileURLs: true),
        initialData: InAppWebViewInitialData(
          data: '''
            <!DOCTYPE html>
            <html>
            <head>
              <meta charset="utf-8">
              <script>
                $ajvCode
              </script>
            </head>
            <body>
              <script>
                console.log('AJV loaded:', typeof window.ajv7);
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

          if (ajvCheck == 'function') {
            _isInitialized = true;
            _initCompleter?.complete();
            print('Validation service initialized successfully');
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

      final jsCode = '''
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

      print('Raw validation result: $result');
      print('Result type: ${result.runtimeType}');

      if (result == null) {
        return ValidationResult(isValid: false, errors: [ValidationError(message: 'Validation returned null')]);
      }

      final resultMap = result is String ? jsonDecode(result) : result;

      print('Result map: $resultMap');
      print('Valid: ${resultMap['valid']}');
      print('Errors: ${resultMap['errors']}');

      return ValidationResult(isValid: resultMap['valid'] ?? false, errors: (resultMap['errors'] as List?)?.map((e) => ValidationError.fromJson(e)).toList() ?? []);
    } catch (e) {
      print('Validation error: $e');
      return ValidationResult(isValid: false, errors: [ValidationError(message: 'Validation exception: $e')]);
    }
  }

  void dispose() {
    _headlessWebView?.dispose();
    _isInitialized = false;
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
