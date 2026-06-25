import 'dart:async';
import 'dart:convert';
import 'package:flutter_js/flutter_js.dart';

import 'validation_types.dart';

/// Runs the TFM plausibility script (`window.TFM` / `runPlots`) in an
/// in-process JS engine via flutter_js — QuickJS on Android/Windows/Linux,
/// JavaScriptCore on iOS/macOS — instead of a headless WebView.
///
/// Verified: the deployed UMD bundle loads and `runPlots` returns identical
/// results under genuine QuickJS and V8 (only a `console` host-binding shim is
/// needed; the engine has no regex/codegen incompatibility — that lived in AJV,
/// which now runs natively in [NativeSchemaValidator]).
///
/// The plausibility script (the synced `schemas.plausability_script` column) is
/// still updatable over Postgres without an app release; only the executor
/// changed from WebView to flutter_js.
class PlausibilityRunner {
  PlausibilityRunner._();
  static final PlausibilityRunner instance = PlausibilityRunner._();

  JavascriptRuntime? _rt;
  bool _loaded = false;
  String? _lastScript;

  // Energy: drop the runtime after idle / on background; next call re-inits
  // transparently from the remembered script.
  Timer? _idleTimer;
  static const Duration _idleTimeout = Duration(minutes: 2);

  // Serialize calls so JS invocations never overlap.
  Future<void> _queue = Future.value();

  bool get isLoaded => _loaded;

  /// Host bindings the bare engine lacks. `console.*` is required (some checks
  /// call console.error); `fetch` is stubbed because in-app lookups are passed
  /// in, so the network path is never taken.
  static const String _shim = '''
    (function(){
      if (typeof globalThis.console === 'undefined') globalThis.console = {};
      ['log','error','warn','info','debug'].forEach(function(m){
        if (typeof globalThis.console[m] !== 'function') globalThis.console[m] = function(){};
      });
      if (typeof globalThis.fetch === 'undefined') {
        globalThis.fetch = function(){ return Promise.reject(new Error('fetch disabled in plausibility runner')); };
      }
    })();
  ''';

  Future<void> initialize({String? tfmValidationCode}) async {
    if (tfmValidationCode != null) _lastScript = tfmValidationCode;
    if (_loaded && _rt != null) return;
    if (_lastScript == null) return;

    final rt = getJavascriptRuntime(xhr: false);
    rt.evaluate(_shim);
    // UMD bundle assigns globalThis.TFM (no module/define in this engine).
    final load = rt.evaluate(_lastScript!);
    if (load.isError) {
      rt.dispose();
      throw Exception('Failed to load plausibility script: ${load.stringResult}');
    }
    final check = rt.evaluate("typeof globalThis.TFM === 'function' ? 'ok' : typeof globalThis.TFM");
    if (check.stringResult != 'ok') {
      rt.dispose();
      throw Exception('Plausibility script did not define globalThis.TFM (got ${check.stringResult})');
    }
    _rt = rt;
    _loaded = true;
  }

  /// Runs `new TFM(null, null, lookups).runPlots([data], '/plot', previous)`
  /// and returns the TFM error/warning objects.
  Future<List<TFMValidationError>> runPlots({
    required Map<String, dynamic> data,
    Map<String, dynamic>? previousData,
    List<Map<String, dynamic>>? treeSpeciesLookup,
  }) {
    final completer = Completer<List<TFMValidationError>>();
    _queue = _queue.catchError((_) {}).then((_) async {
      try {
        completer.complete(await _runPlotsUnsafe(
          data: data,
          previousData: previousData,
          treeSpeciesLookup: treeSpeciesLookup,
        ));
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<List<TFMValidationError>> _runPlotsUnsafe({
    required Map<String, dynamic> data,
    Map<String, dynamic>? previousData,
    List<Map<String, dynamic>>? treeSpeciesLookup,
  }) async {
    if (!_loaded || _rt == null) await initialize();
    final rt = _rt;
    if (rt == null || !_loaded) {
      return [_engineError('Plausibility engine unavailable')];
    }
    _resetIdleTimer();

    final dataJson = jsonEncode([data]);
    final previousJson = previousData != null ? jsonEncode([previousData]) : '[]';
    final lookupsJson = treeSpeciesLookup != null ? jsonEncode({'tree_species': treeSpeciesLookup}) : '{}';

    // Returns a JSON string so we get a clean stringResult back across the bridge.
    final code = '''
      (async function(){
        try {
          var tfm = new globalThis.TFM(null, null, $lookupsJson);
          var errs = await tfm.runPlots($dataJson, '/plot', $previousJson);
          return JSON.stringify(errs || []);
        } catch (e) {
          return JSON.stringify([{ instancePath: '', error: { type: 'error',
            text: 'TFM runPlots failed: ' + (e && e.message ? e.message : e) },
            debugInfo: (e && e.stack) ? String(e.stack) : '' }]);
        }
      })();
    ''';

    try {
      final asyncResult = await rt.evaluateAsync(code);
      rt.executePendingJob();
      final resolved = await rt.handlePromise(asyncResult);
      // flutter_js may return the JSON string single- or double-encoded
      // depending on the platform engine (QuickJS vs JavaScriptCore), so decode
      // again if the first pass yields a String.
      dynamic decoded = jsonDecode(resolved.stringResult);
      if (decoded is String) decoded = jsonDecode(decoded);
      if (decoded is! List) return const [];
      return decoded
          .map((e) => TFMValidationError.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      return [_engineError('Plausibility execution error: $e')];
    }
  }

  TFMValidationError _engineError(String text) =>
      TFMValidationError(instancePath: '', error: {'type': 'error', 'text': text});

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, () {
      _queue = _queue.catchError((_) {}).then((_) => _disposeRuntimeKeepInstance());
    });
  }

  /// Drop the engine but keep the remembered script so the next call re-inits.
  Future<void> handleAppPaused() async {
    await _queue.catchError((_) {});
    await _disposeRuntimeKeepInstance();
  }

  Future<void> _disposeRuntimeKeepInstance() async {
    _idleTimer?.cancel();
    _idleTimer = null;
    final rt = _rt;
    _rt = null;
    _loaded = false;
    rt?.dispose();
  }

  Future<void> dispose() async {
    _lastScript = null;
    await _queue.catchError((_) {});
    await _disposeRuntimeKeepInstance();
  }
}
