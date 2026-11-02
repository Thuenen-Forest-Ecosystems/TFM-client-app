import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'validation_types.dart';

// Indirect eval: runs in global scope, so the UMD bundle assigns globalThis.TFM.
@JS('eval')
external JSAny? _globalEval(JSString code);

/// Web counterpart of the flutter_js runner: same API, but the plausibility
/// script runs in the browser's own JS engine. The browser already provides
/// `console` and `fetch`, so no host shim is needed, and there is no separate
/// runtime to drop on pause/idle.
class PlausibilityRunner {
  PlausibilityRunner._();
  static final PlausibilityRunner instance = PlausibilityRunner._();

  bool _loaded = false;
  String? _lastScript;

  // Serialize calls so JS invocations never overlap.
  Future<void> _queue = Future.value();

  bool get isLoaded => _loaded;

  Future<void> initialize({String? tfmValidationCode}) async {
    if (tfmValidationCode != null && tfmValidationCode != _lastScript) {
      _lastScript = tfmValidationCode;
      _loaded = false;
    }
    if (_loaded || _lastScript == null) return;

    try {
      _globalEval(_lastScript!.toJS);
    } catch (e) {
      throw Exception('Failed to load plausibility script: $e');
    }
    final check = _globalEval("typeof globalThis.TFM === 'function' ? 'ok' : typeof globalThis.TFM".toJS);
    final type = (check as JSString?)?.toDart;
    if (type != 'ok') {
      throw Exception('Plausibility script did not define globalThis.TFM (got $type)');
    }
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
    if (!_loaded) await initialize();
    if (!_loaded) {
      // No script cached yet: non-blocking warning, as on native.
      return [_engineError(kPlausibilityUnavailableMessage, warning: true)];
    }

    final dataJson = jsonEncode([data]);
    final previousJson = previousData != null ? jsonEncode([previousData]) : '[]';
    final lookupsJson = treeSpeciesLookup != null ? jsonEncode({'tree_species': treeSpeciesLookup}) : '{}';

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
      final promise = _globalEval(code.toJS) as JSPromise<JSString>;
      final decoded = jsonDecode((await promise.toDart).toDart);
      if (decoded is! List) return const [];
      return decoded
          .map((e) => TFMValidationError.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      return [_engineError('Plausibility execution error: $e')];
    }
  }

  TFMValidationError _engineError(String text, {bool warning = false}) =>
      TFMValidationError(instancePath: '', error: {
        'type': warning ? 'warning' : 'error',
        'text': text,
      });

  /// Nothing to free in the browser; kept for API parity with the native runner.
  Future<void> handleAppPaused() async {}

  Future<void> dispose() async {
    _lastScript = null;
    _loaded = false;
  }
}
