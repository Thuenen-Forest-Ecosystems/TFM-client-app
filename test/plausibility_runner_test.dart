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
}
