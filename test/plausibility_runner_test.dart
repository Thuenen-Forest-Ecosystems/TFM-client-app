import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terrestrial_forest_monitor/services/plausibility_runner.dart';
import 'package:terrestrial_forest_monitor/services/validation_types.dart';

/// End-to-end test of the flutter_js plausibility path: load the REAL deployed
/// TFM plausibility bundle (the synced `plausability_script`) into the engine
/// and run `runPlots` against a real plot — the same inputs that return 14
/// issues under both V8 and the `qjs` (QuickJS) binary.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final script = File('test/fixtures/tfm_plausibility.umd.js').readAsStringSync();
  final plot = jsonDecode(File('test/fixtures/plot_sample.json').readAsStringSync())
      as Map<String, dynamic>;

  test('real plausibility bundle runs under flutter_js and returns issues', () async {
    await PlausibilityRunner.instance.initialize(tfmValidationCode: script);
    expect(PlausibilityRunner.instance.isLoaded, isTrue,
        reason: 'bundle should define globalThis.TFM');

    final issues = await PlausibilityRunner.instance.runPlots(
      data: plot,
      previousData: plot, // previous = current, mirrors the cross-inventory path
      treeSpeciesLookup: const [],
    );

    // No engine-level failure (would surface as an empty-path "runPlots failed").
    final engineFailures =
        issues.where((e) => e.message.contains('runPlots failed') || e.message.contains('execution error'));
    expect(engineFailures, isEmpty, reason: engineFailures.map((e) => e.message).join('\n'));

    // Real validation issues come back, well-formed, in German.
    expect(issues, isNotEmpty);
    final sample = issues.firstWhere((e) => e.isError, orElse: () => issues.first);
    expect(sample, isA<TFMValidationError>());
    expect(sample.message, isNotEmpty);
    expect(sample.instancePath, startsWith('/plot/0'));

    await PlausibilityRunner.instance.dispose();
  });

  // Regression for TFM-client-app#441: a corner form's teardown must NOT wipe
  // the shared cached script, or a form mounting during the same transition
  // loses plausibility until another clean remount. The form screen now tears
  // down via handleAppPaused(), which drops the runtime but keeps the script so
  // the next validation re-initialises lazily.
  test('handleAppPaused keeps the cached script so runPlots re-inits lazily', () async {
    await PlausibilityRunner.instance.initialize(tfmValidationCode: script);
    expect(PlausibilityRunner.instance.isLoaded, isTrue);

    // Simulates the form-screen teardown path (energy: drop the runtime).
    await PlausibilityRunner.instance.handleAppPaused();
    expect(PlausibilityRunner.instance.isLoaded, isFalse,
        reason: 'runtime is dropped on pause');

    // A subsequent validation WITHOUT any initialize() call must transparently
    // re-create the engine from the retained script — the exact path a newly
    // mounted corner form relies on.
    final issues = await PlausibilityRunner.instance.runPlots(
      data: plot,
      previousData: plot,
      treeSpeciesLookup: const [],
    );
    expect(PlausibilityRunner.instance.isLoaded, isTrue,
        reason: 'runPlots re-initialised from the retained script');
    final engineFailures = issues.where((e) =>
        e.message.contains('runPlots failed') ||
        e.message.contains('unavailable') ||
        e.message.contains('execution error'));
    expect(engineFailures, isEmpty, reason: engineFailures.map((e) => e.message).join('\n'));
    expect(issues, isNotEmpty);

    await PlausibilityRunner.instance.dispose();
  });

  // Regression: a teardown (app pause/hide, sibling corner form dispose) landing
  // while a validation is in flight must NOT surface a spurious "engine
  // unavailable". handleAppPaused() now serialises its teardown on the same
  // queue as runPlots, so it runs strictly before/after — never interleaving
  // into the runtime null-check of a running validation.
  test('teardown queued around an in-flight runPlots never reports unavailable', () async {
    await PlausibilityRunner.instance.initialize(tfmValidationCode: script);

    // Queue the teardown first, then fire the validation into the same turn —
    // the exact ordering where the old capture-then-dispose could interleave.
    final paused = PlausibilityRunner.instance.handleAppPaused();
    final issues = await PlausibilityRunner.instance.runPlots(
      data: plot,
      previousData: plot,
      treeSpeciesLookup: const [],
    );
    await paused;

    expect(issues.any((e) => e.message.contains('unavailable')), isFalse,
        reason: 'teardown must not race an in-flight validation into "unavailable"');
    expect(PlausibilityRunner.instance.isLoaded, isTrue,
        reason: 'runPlots re-initialised from the retained script after teardown');

    await PlausibilityRunner.instance.dispose();
  });

  // dispose() remains a full teardown (app close): it clears the script, and a
  // subsequent runPlots then reports the engine unavailable (as a non-blocking
  // warning) rather than silently returning "no issues".
  test('dispose clears the cached script; runPlots then reports unavailable', () async {
    await PlausibilityRunner.instance.initialize(tfmValidationCode: script);
    await PlausibilityRunner.instance.dispose();
    expect(PlausibilityRunner.instance.isLoaded, isFalse);

    final issues = await PlausibilityRunner.instance.runPlots(
      data: plot,
      previousData: plot,
      treeSpeciesLookup: const [],
    );
    expect(PlausibilityRunner.instance.isLoaded, isFalse);
    expect(issues.any((e) => e.message.contains('unavailable')), isTrue,
        reason: 'engine-unavailable is surfaced (as a non-blocking warning), not swallowed');
    expect(issues.any((e) => e.message.contains('unavailable') && e.isWarning), isTrue,
        reason: 'engine-unavailable must be non-blocking so it never blocks completion');
  });

  // Reproduces the field report: a corner shows "Plausibility engine
  // unavailable", then editing the DB `plausability_script` and reverting it to
  // the byte-identical original makes plausibility work again. This proves the
  // failure is state/lifecycle, not script CONTENT: the SAME script yields
  // "unavailable" while the runner's cache is empty, and succeeds once the
  // (identical) script is re-supplied — exactly what a PowerSync re-sync of the
  // schemas row does on the app side.
  test('same script: unavailable while cache empty, recovers verbatim on re-supply', () async {
    // 1. Runner in the stuck state (script cleared by a prior full dispose /
    //    app-quit path), and the freshly opened form has not re-supplied it yet.
    await PlausibilityRunner.instance.dispose();
    expect(PlausibilityRunner.instance.isLoaded, isFalse);

    final broken = await PlausibilityRunner.instance.runPlots(
      data: plot,
      previousData: plot,
      treeSpeciesLookup: const [],
    );
    expect(broken.any((e) => e.message.contains('unavailable')), isTrue,
        reason: 'empty cache surfaces the exact screenshot symptom');

    // 2. Re-supply the VERBATIM same script (what the DB edit-and-revert forced
    //    via re-sync). No content changed — only the cache was repopulated.
    await PlausibilityRunner.instance.initialize(tfmValidationCode: script);
    final recovered = await PlausibilityRunner.instance.runPlots(
      data: plot,
      previousData: plot,
      treeSpeciesLookup: const [],
    );
    expect(recovered.any((e) => e.message.contains('unavailable')), isFalse,
        reason: 'identical script recovers purely from re-init → app-side, not content');
    expect(recovered, isNotEmpty);

    await PlausibilityRunner.instance.dispose();
  });
}
