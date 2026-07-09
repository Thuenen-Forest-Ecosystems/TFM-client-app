import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terrestrial_forest_monitor/services/plausibility_runner.dart';
import 'package:terrestrial_forest_monitor/services/plausibility_script_resolver.dart';

/// Harness for the TFM-client-app#441 recovery fix. A full widget test of
/// PropertiesEdit needs a live PowerSync DB, whose native `libpowersync` engine
/// isn't loadable under host `flutter test`. Instead this drives the extracted
/// [PlausibilityScriptResolver] — the exact decision logic the form uses — with
/// a fake `schemas`-row fetcher that models the real trigger (row synced before
/// its `plausability_script` column), and chains the recovered script into the
/// REAL flutter_js [PlausibilityRunner] to prove the engine actually recovers.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final script = File('test/fixtures/tfm_plausibility.umd.js').readAsStringSync();
  final plot = jsonDecode(File('test/fixtures/plot_sample.json').readAsStringSync())
      as Map<String, dynamic>;

  group('PlausibilityScriptResolver', () {
    test('script present at load: never touches the fetcher', () async {
      var fetches = 0;
      final resolver = PlausibilityScriptResolver(
        (id) async {
          fetches++;
          return null;
        },
        initialScript: script,
      );

      expect(resolver.resolved, isTrue);
      expect(await resolver.ensure('s1'), same(script));
      expect(fetches, 0, reason: 'a cached load-time script must not hit the DB');
    });

    test('absent at load then arrives via sync: recovers on the next ensure()', () async {
      // Model the schemas row syncing before its plausability_script column:
      // the first read returns null, later reads return the real script.
      String? column;
      var fetches = 0;
      final resolver = PlausibilityScriptResolver(
        (id) async {
          fetches++;
          return column;
        },
        initialScript: null, // nothing shipped at load (the #441 trigger)
      );

      // Load-time state: no script known → the form would report "unavailable".
      expect(resolver.resolved, isFalse);
      expect(await resolver.ensure('s1'), isNull);
      expect(fetches, 1);

      // The column arrives via PowerSync.
      column = script;

      // Next validation pass re-reads the live row and recovers — no full
      // re-sync / app restart needed (the old workaround).
      expect(await resolver.ensure('s1'), same(script));
      expect(resolver.resolved, isTrue);

      // Subsequent passes are served from cache, not the DB.
      final before = fetches;
      expect(await resolver.ensure('s1'), same(script));
      expect(fetches, before, reason: 'resolved script is cached');
    });

    test('genuinely no script: stays unresolved so the false banner is suppressed',
        () async {
      final resolver = PlausibilityScriptResolver(
        (id) async => null, // schema truly ships no plausibility
        initialScript: null,
      );

      expect(await resolver.ensure('s1'), isNull);
      expect(await resolver.ensure('s1'), isNull);
      // `resolved` false is exactly what the form checks to drop a spurious
      // "engine unavailable" marker for a no-plausibility schema.
      expect(resolver.resolved, isFalse);
    });

    test('empty-string script is treated as no script', () async {
      final resolver = PlausibilityScriptResolver(
        (id) async => '',
        initialScript: '',
      );
      expect(resolver.resolved, isFalse);
      expect(await resolver.ensure('s1'), '');
      expect(resolver.resolved, isFalse);
    });

    test('null schema id: no fetch, unresolved', () async {
      var fetches = 0;
      final resolver = PlausibilityScriptResolver(
        (id) async {
          fetches++;
          return script;
        },
        initialScript: null,
      );
      expect(await resolver.ensure(null), isNull);
      expect(fetches, 0);
      expect(resolver.resolved, isFalse);
    });
  });

  // End-to-end: the resolver's recovered script must make the REAL engine run.
  // This is the whole point of the fix — proving that "script arrives late →
  // resolver recovers it → plausibility engine produces real results" without a
  // restart.
  test('recovered script drives the real plausibility engine to real results', () async {
    String? column; // starts null (sync lag), then the script arrives.
    final resolver = PlausibilityScriptResolver(
      (id) async => column,
      initialScript: null,
    );

    // 1. Load-time: engine has no script, form would show "unavailable".
    await PlausibilityRunner.instance.dispose(); // ensure empty runner cache
    expect(await resolver.ensure('s1'), isNull);

    final beforeRecovery = await PlausibilityRunner.instance.runPlots(
      data: plot,
      previousData: plot,
      treeSpeciesLookup: const [],
    );
    expect(beforeRecovery.any((e) => e.message.contains('unavailable')), isTrue,
        reason: 'no script yet → engine unavailable (the reported symptom)');

    // 2. Script arrives via sync; resolver recovers it and the form re-supplies
    //    it to the engine (mirrors the retry loop in properties-edit).
    column = script;
    final recovered = await resolver.ensure('s1');
    expect(recovered, isNotNull);
    await PlausibilityRunner.instance.initialize(tfmValidationCode: recovered);

    final afterRecovery = await PlausibilityRunner.instance.runPlots(
      data: plot,
      previousData: plot,
      treeSpeciesLookup: const [],
    );
    expect(afterRecovery.any((e) => e.message.contains('unavailable')), isFalse,
        reason: 'recovered script must clear the unavailable state');
    expect(afterRecovery, isNotEmpty,
        reason: 'engine now produces real plausibility issues');

    await PlausibilityRunner.instance.dispose();
  });
}
