import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:json_schema/json_schema.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:convert';

class TestAjv extends StatefulWidget {
  const TestAjv({super.key});

  @override
  State<TestAjv> createState() => _TestAjvState();
}

class _TestAjvState extends State<TestAjv> {
  HeadlessInAppWebView? headlessWebView;
  String? jsValidationCode;

  Map<String, dynamic> schema = {
    "type": "object",
    "properties": {
      "name": {"type": "string"},
      "age": {"type": "integer", "minimum": 0},
    },
    "required": ["name", "age"],
  };

  Map<String, dynamic> data = {"name": 2, "age": "30"};

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    // Load your local JavaScript file
    try {
      jsValidationCode = await rootBundle.loadString('assets/html/validation.js');
    } catch (e) {
    }

    // Initialize headless WebView for running JavaScript
    headlessWebView = HeadlessInAppWebView(
      initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
      onWebViewCreated: (controller) {
      },
      onLoadStop: (controller, url) async {
      },
    );

    await headlessWebView?.run();
  }

  Future<void> onPressed() async {
    // Add your onPressed logic here
    final jsonSchema = JsonSchema.create(this.schema);
    ValidationResults result = jsonSchema.validate(this.data);

    if (result.isValid) {
    } else {
      for (var error in result.errors) {
      }
    }

    // Additional JavaScript validation
    if (headlessWebView != null && jsValidationCode != null) {
      try {
        final dataJson = jsonEncode(data);
        final schemaJson = jsonEncode(schema);

        // Run the JavaScript validation
        final jsCode = '''
          $jsValidationCode
          
          // Call your custom validation function
          (function() {
            try {
              const data = $dataJson;
              const schema = $schemaJson;
              
              // Call your custom validation function from validation.js
              // Adjust the function name based on your actual JS file
              if (typeof customValidate === 'function') {
                const result = customValidate(data, schema);
                return JSON.stringify(result);
              } else {
                return JSON.stringify({
                  valid: true,
                  message: 'No custom validation function found'
                });
              }
            } catch (error) {
              return JSON.stringify({
                valid: false,
                error: error.message
              });
            }
          })();
        ''';

        final jsResult = await headlessWebView!.webViewController?.evaluateJavascript(source: jsCode);

        if (jsResult != null) {
          final validationResult = jsonDecode(jsResult.toString());

          if (validationResult['valid'] == true) {
          } else {
          }
        }
      } catch (e) {
      }
    } else {
    }
  }

  @override
  void dispose() {
    headlessWebView?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(child: ElevatedButton(onPressed: onPressed, child: const Text('Test AJV')));
  }
}
