import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_js/flutter_js.dart';

/// Smoke test for the flutter_js bridge mechanics the PlausibilityRunner relies
/// on: load script into globalThis, run an async function, resolve its promise,
/// and read back a JSON string. (Engine/runPlots parity with V8 is proven
/// separately under the real `qjs` binary.)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('flutter_js: console shim + async promise returning JSON', () async {
    final rt = getJavascriptRuntime(xhr: false);
    rt.evaluate('''
      if (typeof globalThis.console === 'undefined') globalThis.console = {};
      ['log','error','warn','info','debug'].forEach(function(m){
        if (typeof globalThis.console[m] !== 'function') globalThis.console[m] = function(){};
      });
      globalThis.makeResult = function(n){ console.error('noop'); return { v: n + 1 }; };
    ''');

    final asyncResult = await rt.evaluateAsync(
      "(async function(){ return JSON.stringify(globalThis.makeResult(41)); })();",
    );
    rt.executePendingJob();
    final resolved = await rt.handlePromise(asyncResult);

    // flutter_js may single- or double-encode the returned JSON string
    // depending on the platform engine; decode defensively (as the runner does).
    dynamic decoded = jsonDecode(resolved.stringResult);
    if (decoded is String) decoded = jsonDecode(decoded);
    expect(decoded, {'v': 42});
    rt.dispose();
  });
}
