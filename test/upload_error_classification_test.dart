import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:postgrest/postgrest.dart';
import 'package:powersync/powersync.dart' show UpdateType;
import 'package:terrestrial_forest_monitor/services/powersync.dart'
    show fatalResponseCodes, isNoOpPatchPayload, UploadPausedException;

/// Replicates the classification in SupabaseConnector.uploadData
/// (lib/services/powersync.dart): fatal -> transaction dropped (old app:
/// silently; new app: quarantined). Anything else -> rethrow -> PowerSync
/// keeps the transaction and retries.
bool isDroppedAsFatal(PostgrestException e) =>
    e.code != null && fatalResponseCodes.any((re) => re.hasMatch(e.code!));

/// Replicates EXACTLY how postgrest-dart 2.5.0 (pubspec.lock) constructs the
/// exception from a non-2xx response (postgrest_builder.dart, else-branch):
/// - JSON body:      PostgrestException.fromJson(json, code: statusCode)
///                   -> code = json['code'] ?? '<statusCode>'
/// - non-JSON body:  PostgrestException(code: '<statusCode>')
PostgrestException exceptionAsPostgrestDartBuildsIt({
  required int statusCode,
  required String body,
}) {
  try {
    final errorJson = jsonDecode(body) as Map<String, dynamic>;
    return PostgrestException.fromJson(
      errorJson,
      message: body,
      code: statusCode,
      details: 'reasonPhrase',
    );
  } catch (_) {
    return PostgrestException(message: body, code: '$statusCode');
  }
}

void main() {
  group('Kong anon-write block is retryable for the OLD connector logic', () {
    test('Kong 401 with JSON body (no "code" field) -> kept in queue', () {
      final e = exceptionAsPostgrestDartBuildsIt(
        statusCode: 401,
        body: '{"message":"Anmeldung erforderlich - Schreibzugriff mit anon-Key ist blockiert"}',
      );
      expect(e.code, '401');
      expect(isDroppedAsFatal(e), isFalse,
          reason: 'Kong-401 muss retryable sein, sonst leert die alte App die Queue');
    });

    test('Kong 401 with non-JSON body -> kept in queue', () {
      final e = exceptionAsPostgrestDartBuildsIt(statusCode: 401, body: 'Unauthorized');
      expect(e.code, '401');
      expect(isDroppedAsFatal(e), isFalse);
    });

    test('Kong 403 variant -> kept in queue', () {
      final e = exceptionAsPostgrestDartBuildsIt(statusCode: 403, body: '{"message":"forbidden"}');
      expect(isDroppedAsFatal(e), isFalse);
    });

    test('CAUTION: a body with a fatal-looking "code" field WOULD be dropped', () {
      // Documents why the Kong response body must never carry a Postgres
      // error code: postgrest-dart prefers json['code'] over the HTTP status.
      final e = exceptionAsPostgrestDartBuildsIt(
        statusCode: 401,
        body: '{"message":"x","code":"42501"}',
      );
      expect(isDroppedAsFatal(e), isTrue);
    });
  });

  group('no-op PATCH detection', () {
    // powersync_diff(old, new) returns `{}` when an UPDATE writes values that
    // are already stored (e.g. re-saving an unchanged form, re-writing
    // identical validation_errors). The op is queued anyway; sending it makes
    // PostgREST answer with an empty result, which the 0-rows guard used to
    // quarantine as `rls_zero_rows` — a data-loss alarm without any data.
    test('empty PATCH payload is a no-op', () {
      expect(isNoOpPatchPayload(UpdateType.patch, <String, dynamic>{}), isTrue);
    });

    test('null PATCH payload is a no-op', () {
      expect(isNoOpPatchPayload(UpdateType.patch, null), isTrue);
    });

    test('PATCH with columns is uploaded', () {
      expect(
        isNoOpPatchPayload(UpdateType.patch, {'properties': '{"a":1}'}),
        isFalse,
        reason: 'a real change must never be skipped',
      );
    });

    test('PATCH clearing a column to null is uploaded', () {
      expect(
        isNoOpPatchPayload(UpdateType.patch, {'completed_at_troop': null}),
        isFalse,
        reason: 'powersync_diff represents a cleared column as an explicit null',
      );
    });

    test('PUT and DELETE are never skipped', () {
      // A PUT always carries at least the id (uploadData sets it), and a
      // DELETE identifies the row by id alone.
      expect(isNoOpPatchPayload(UpdateType.put, <String, dynamic>{}), isFalse);
      expect(isNoOpPatchPayload(UpdateType.delete, null), isFalse);
    });
  });

  group('session guard', () {
    test('UploadPausedException is not a PostgrestException', () {
      // uploadData() only catches PostgrestException. The guard must stay
      // outside that hierarchy so it propagates to PowerSync, which keeps the
      // CRUD transaction and retries — never drops or quarantines it.
      const e = UploadPausedException('no session');
      expect(e, isNot(isA<PostgrestException>()));
      expect(e.toString(), contains('no session'));
    });
  });

  group('genuine Postgres errors keep their classification', () {
    test('RLS denial 42501 -> dropped (old) / quarantined (new)', () {
      final e = exceptionAsPostgrestDartBuildsIt(
        statusCode: 403,
        body: '{"message":"permission denied","code":"42501"}',
      );
      expect(isDroppedAsFatal(e), isTrue);
    });

    test('NOT-NULL violation 23502 -> dropped (old) / quarantined (new)', () {
      final e = exceptionAsPostgrestDartBuildsIt(
        statusCode: 400,
        body: '{"message":"null value","code":"23502"}',
      );
      expect(isDroppedAsFatal(e), isTrue);
    });

    test('PGRST301 (JWT expired) -> kept in queue', () {
      final e = exceptionAsPostgrestDartBuildsIt(
        statusCode: 401,
        body: '{"message":"JWT expired","code":"PGRST301"}',
      );
      expect(isDroppedAsFatal(e), isFalse);
    });
  });
}
