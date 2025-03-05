import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:terrestrial_forest_monitor/screens/storage.dart';

class StatelessTest extends StatefulWidget {
  const StatelessTest({super.key});

  @override
  State<StatelessTest> createState() => _StatelessTestState();
}

class _StatelessTestState extends State<StatelessTest> {
  HeadlessInAppWebView? headlessWebView;
  String url = "";
  late String jsString;
  late InAppWebViewController webViewController;

  Future _initHeadless() async {
    String htmlString = await rootBundle.loadString('assets/html/index.html');
    jsString = await rootBundle.loadString('assets/html/ci2027_plausability_0.0.1.js');
    //String htmlString = '<html></html>';
    headlessWebView = HeadlessInAppWebView(
      initialData: InAppWebViewInitialData(data: htmlString),
      //initialFile: htmlString,
      //initialUrlRequest: URLRequest(url: WebUri("http://localhost:5500/docs/index.html")),
      /*initialUrlRequest: URLRequest(url: WebUri("about:blank")),
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(source: "var foo = 49;", injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START),
        UserScript(source: "var bar = 2;", injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END),
      ]),*/

      //initialSettings: InAppWebViewSettings(isInspectable: kDebugMode),
      onWebViewCreated: (controller) {
        webViewController = controller;
        /*webViewController.addJavaScriptHandler(
          handlerName: "fetchData",
          callback: (args) async {
            // Access SQLite database

            const snackBar = SnackBar(
              content: Text('HeadlessInAppWebView created!'),
              duration: Duration(seconds: 1),
            );
            ScaffoldMessenger.of(context).showSnackBar(snackBar);

            /*final db = await DatabaseHelper.instance.database;
            final data = await db.query('items');*/
            return {'data': 'Hello from Flutter'};
          },
        );*/

        const snackBar = SnackBar(
          content: Text('HeadlessInAppWebView created!'),
          duration: Duration(seconds: 1),
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      },
      onConsoleMessage: (controller, consoleMessage) {
        print("Console: ${consoleMessage.message}");
      },
      onLoadStart: (controller, url) async {
        final snackBar = SnackBar(
          content: Text('onLoadStart $url'),
          duration: const Duration(seconds: 1),
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);

        setState(() {
          this.url = url?.toString() ?? '';
        });
      },
      onLoadStop: (controller, url) async {
        print('inited onLoadStart');
        final snackBar = SnackBar(
          content: Text('onLoadStop $url'),
          duration: const Duration(seconds: 1),
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);

        setState(() {
          this.url = url?.toString() ?? '';
        });
        return;
        String jsCode = """
          (function() {
            // Your JavaScript code here
            return 'Hello from JavaScript';
          })();
        """;

        var result3 = await webViewController.evaluateJavascript(source: jsCode);
        print('JavaScript result: $result3');

        var result2 = await controller.evaluateJavascript(source: "foo + bar");
        print('result2');
        print(result2);

        var result = await controller.injectJavascriptFileFromAsset(assetFilePath: "/Users/b-mini/Documents/TFM/ci2027_schema_0.0.1.json");
        print(result.runtimeType); // int
        print(result); // 30

        setState(() {
          this.url = url?.toString() ?? '';
        });
      },
    );
    headlessWebView?.run();
  }

  // Validate JSON
  // Validate JSON
  Future<void> validateJSON() async {
    // Check if AJV is loaded
    final isAjvLoaded = await webViewController.evaluateJavascript(source: "window.isAjvLoaded;");

    if (isAjvLoaded == null || isAjvLoaded == false) {
      print('ÄJV is not loaded!');
      return;
    }

    // JSON Schema
    const schema = {
      "type": "object",
      "properties": {
        "name": {"type": "string"},
        "age": {"type": "integer"},
      },
      "required": ["name", "age"]
    };

    // JSON Data
    const data = {"name": "John Doe", "age": '30'};

    // JavaScript code to validate JSON
    final jsCode = """
      function validate() {
        try{
          const ajv = new window.ajv7();
          const validate = ajv.compile(${jsonEncode(schema)});
          const valid = validate(${jsonEncode(data)});
          if (valid) {
            return "Valid JSON!";
          } else {
            return "Invalid JSON: " + JSON.stringify(validate.errors);
          }
        } catch (e) {
          return "Error: " + e;
        }
      };
      validate();
    """;
    try {
      // Run the JavaScript code
      final result = await webViewController.evaluateJavascript(source: jsCode);
      print('JavaScript result: $result');
    } catch (e) {
      print('Error: $e');
    }
    return;

    // Run the JavaScript code
    webViewController.evaluateJavascript(source: jsString);

    /*const initJS = """
        const tfm = new TFM('http://localhost:5000', 'apikey');
    """;
    webViewController.evaluateJavascript(source: initJS);*/

    var jsCode2 = """
      function validate() {
        const ajv = new Ajv();
        const validate = ajv.compile(${json.encode(schema)});
        const valid = validate(${json.encode(data)});
        if (valid) {
          return "Valid JSON!";
        } else {
          return "Invalid JSON: " + JSON.stringify(validate.errors);
        }
      };
    """;

    var result = await webViewController.evaluateJavascript(source: jsCode2);
    print('JavaScript result: $result');
  }

  @override
  void initState() {
    super.initState();
    _initHeadless();
  }

  @override
  void dispose() {
    super.dispose();
    headlessWebView?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Stateless Test'),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Text('URL: $url'),
            Center(
              child: ElevatedButton(
                  onPressed: () async {
                    await headlessWebView?.dispose();
                    await headlessWebView?.run();
                  },
                  child: const Text("Run HeadlessInAppWebView")),
            ),
            Center(
              child: ElevatedButton(
                  onPressed: () async {
                    if (headlessWebView?.isRunning() ?? false) {
                      await headlessWebView?.webViewController?.evaluateJavascript(source: "console.log('Here is the message!');");
                    } else {
                      const snackBar = SnackBar(
                        content: Text('HeadlessInAppWebView is not running. Click on "Run HeadlessInAppWebView"!'),
                        duration: Duration(milliseconds: 1500),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(snackBar);
                    }
                  },
                  child: const Text("Send console.log message")),
            ),
            Center(
              child: ElevatedButton(
                  onPressed: () async {
                    if (headlessWebView?.isRunning() ?? false) {
                      await headlessWebView?.webViewController?.evaluateJavascript(source: "TESTFN('Msg from Flutter');");
                    } else {
                      const snackBar = SnackBar(
                        content: Text('HeadlessInAppWebView is not running. Click on "Run HeadlessInAppWebView"!'),
                        duration: Duration(milliseconds: 1500),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(snackBar);
                    }
                  },
                  child: const Text("Send TESTFN message")),
            ),
            Center(
              child: ElevatedButton(
                  onPressed: () async {
                    if (headlessWebView?.isRunning() ?? false) {
                      await headlessWebView?.webViewController?.evaluateJavascript(source: "fetchDatabaseData();");
                    } else {
                      const snackBar = SnackBar(
                        content: Text('HeadlessInAppWebView is not running. Click on "Run HeadlessInAppWebView"!'),
                        duration: Duration(milliseconds: 1500),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(snackBar);
                    }
                  },
                  child: const Text("Send TESTFN message")),
            ),
            Center(
              child: ElevatedButton(
                  onPressed: () async {
                    await headlessWebView?.dispose();
                    setState(() {
                      url = '';
                    });
                  },
                  child: const Text("Dispose HeadlessInAppWebView")),
            ),
            ElevatedButton(
              onPressed: validateJSON,
              child: Text("Validate JSON"),
            ),
          ],
        ),
      ),
    );
  }
}
