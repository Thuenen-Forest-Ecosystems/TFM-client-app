// Live check against a TFM-Server: can the app still write the records
// columns protected by guard_records_app_only_columns (TFM-Server migration
// 20261106000000)?
//
// Uses the real supabase_flutter SDK, initialised exactly like
// lib/services/powersync.dart (url + anonKey, no custom headers), and the
// same REST calls as SupabaseConnector.uploadData():
//   rest.from('records').update(data).eq('id', id).select('id')
// Every change is written back afterwards.
//
// Skipped unless GUARD_TEST_URL is set — it talks to a live server:
//   GUARD_TEST_URL=http://127.0.0.1:54321 GUARD_TEST_ANON_KEY=... \
//   GUARD_TEST_EMAIL=... GUARD_TEST_PASSWORD=... \
//   GUARD_TEST_RECORD=f7a2ed08-3bd2-49f7-97d4-06a7f81ade7a \
//   flutter test test/records_guard_app_header_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _env = Platform.environment;
final _url = _env['GUARD_TEST_URL'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('app SDK can write guarded records columns', () async {
    // flutter_test answers every real HTTP request with 400; this test needs
    // the network.
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});

    // Same call as lib/services/powersync.dart — no custom headers.
    await Supabase.initialize(url: _url!, anonKey: _env['GUARD_TEST_ANON_KEY']!);
    final client = Supabase.instance.client;
    await client.auth.signInWithPassword(
      email: _env['GUARD_TEST_EMAIL']!,
      password: _env['GUARD_TEST_PASSWORD']!,
    );
    final recordId = _env['GUARD_TEST_RECORD']!;
    final rest = client.rest; // what uploadData() uses

    const cols =
        'properties,completed_at_troop,validation_errors,plausibility_errors,schema_id_validated_by';
    final original = await rest.from('records').select(cols).eq('id', recordId).single();

    try {
      // 1. properties-edit.dart: save form (PATCH as PowerSync queues it)
      final props = Map<String, dynamic>.of(original['properties'] as Map<String, dynamic>)
        ..['_guard_sdk_test'] = DateTime.now().millisecondsSinceEpoch;
      var rows = await rest.from('records').update({
        'properties': props,
        'schema_id_validated_by': original['schema_id_validated_by'],
        'validation_errors': '[]',
        'plausibility_errors': '[]',
      }).eq('id', recordId).select('id');
      expect(rows, hasLength(1), reason: 'save properties was not applied');

      // 2. finish recording: completed_at_troop
      rows = await rest
          .from('records')
          .update({'completed_at_troop': DateTime.now().toUtc().toIso8601String()})
          .eq('id', recordId)
          .select('id');
      expect(rows, hasLength(1), reason: 'completed_at_troop was not applied');

      final written = await rest.from('records').select('properties').eq('id', recordId).single();
      expect((written['properties'] as Map)['_guard_sdk_test'], props['_guard_sdk_test']);
    } finally {
      await rest.from('records').update(original).eq('id', recordId).select('id');
      final restored = await rest.from('records').select(cols).eq('id', recordId).single();
      expect(restored, original, reason: 'record not restored to its original state');
      await client.auth.signOut();
    }
  }, skip: _url == null ? 'GUARD_TEST_URL not set (live server test)' : false);
}
