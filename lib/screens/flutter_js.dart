import 'package:flutter/material.dart';
import 'package:flutter_js/flutter_js.dart';
//import 'package:flutter_js_example/ajv_example.dart';

class FlutterJsHomeScreen extends StatefulWidget {
  const FlutterJsHomeScreen({super.key});

  @override
  _FlutterJsHomeScreenState createState() => _FlutterJsHomeScreenState();
}

class _FlutterJsHomeScreenState extends State<FlutterJsHomeScreen> {
  String _jsResult = '';

  final JavascriptRuntime javascriptRuntime = getJavascriptRuntime(forceJavascriptCoreOnAndroid: false);

  String? _quickjsVersion;

  Future<String> evalJS() async {
    JsEvalResult jsResult = await javascriptRuntime.evaluateAsync("""
            if (typeof MyClass == 'undefined') {
              var MyClass = class  {
                constructor(id) {
                  this.id = id;
                }
                
                getId() { 
                  return this.id;
                }
              }
            }
            async function test() {
              var obj = new MyClass(1);
              var jsonStringified = JSON.stringify(obj);
              var value = Math.trunc(Math.random() * 100).toString();
              var asyncResult = await sendMessage("getDataAsync", JSON.stringify({"count": Math.trunc(Math.random() * 10)}));
              var err;
              try {
                await sendMessage("asyncWithError", "{}");
              } catch(e) {
                err = e.message || e;
              }
              return {"object": jsonStringified, "expression": value, "asyncResult": asyncResult, "expectedError": err};
            }
            test();
            """, sourceUrl: 'script.js');
    javascriptRuntime.executePendingJob();
    JsEvalResult asyncResult = await javascriptRuntime.handlePromise(jsResult);
    return asyncResult.stringResult;
  }

  void _initJs() async {
    // https://github.com/abner/flutter_js/blob/master/example/lib/ajv_example.dart

    javascriptRuntime.evaluate("""
      async function calculate(arg1, arg2) {
        try {
          const result = await sendMessage("getLookup", JSON.stringify({}));
          return arg1 + arg2 + result;
        } catch(e) {
          await sendMessage("jsError", e);
        }
        return arg1 + arg2;
        return {"object": jsonStringified, "expression": value, "asyncResult": asyncResult, "expectedError": err};
      }
    """);
  }

  Future<void> _validate() async {
    JsEvalResult jsResult = await javascriptRuntime.evaluateAsync("""
      calculate(1, 233);
    """);
    JsEvalResult asyncResult = await javascriptRuntime.handlePromise(jsResult);
    print(asyncResult);
    print('JS Result: ${asyncResult.stringResult}');
  }

  @override
  void initState() {
    super.initState();

    javascriptRuntime.setInspectable(true);
    javascriptRuntime.onMessage('getLookup', (args) async {
      print('getLookup');
      print(args);
      await Future.delayed(const Duration(seconds: 1));

      return 500;
    });
    javascriptRuntime.onMessage('jsError', (args) async {
      print('jsError');
      print(args);
    });
    _initJs();
    _validate();
  }

  @override
  void dispose() {
    javascriptRuntime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('FlutterJS Example')), body: ElevatedButton(onPressed: _validate, child: Text('PRESS')));
  }
}
