import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:powersync/powersync.dart';
import 'package:powersync/sqlite3_common.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:terrestrial_forest_monitor/services/utils.dart';
import 'package:terrestrial_forest_monitor/services/log_service.dart';
import 'powersync_io.dart' if (dart.library.html) 'powersync_web.dart';

import 'schema.dart';
import 'package:logging/logging.dart';

final log = Logger('powersync-supabase');

/// Postgres Response codes that we cannot recover from by retrying.
final List<RegExp> fatalResponseCodes = [
  // Class 22 — Data Exception
  // Examples include data type mismatch.
  RegExp(r'^22...$'),
  // Class 23 — Integrity Constraint Violation.
  // Examples include NOT NULL, FOREIGN KEY and UNIQUE violations.
  RegExp(r'^23...$'),
  // INSUFFICIENT PRIVILEGE - typically a row-level security violation
  RegExp(r'^42501$'),
];

late PowerSyncDatabase db;

/// Broadcast stream that fires whenever [switchUserDatabase] completes and
/// [db] points to a new instance. Widgets that hold subscriptions to the old
/// db instance must cancel + resubscribe when they receive this event.
final _dbSwitchController = StreamController<void>.broadcast();
Stream<void> get dbSwitchEvents => _dbSwitchController.stream;

Future<FunctionResponse> inviteUserByEmail(String email, String organizationId) async {
  // final FunctionResponse response =
  return await Supabase.instance.client.functions.invoke(
    'invite-user',
    body: jsonEncode({
      'email': email,
      'metaData': {'organization_id': organizationId},
    }),
  );
}

/// Returns the SQLite file path for [userId] (per-user isolation) or the
/// legacy shared path when [userId] is null.
Future<String> getDatabasePath({String? userId}) async {
  var config = await getServerConfig();

  final base = (config['database'] ?? 'tfm') as String;
  final suffix = userId != null ? '_$userId' : '';
  final dbFilename = '$base$suffix.db';

  // getApplicationSupportDirectory is not supported on Web
  if (kIsWeb) {
    return dbFilename;
  }

  try {
    final dir = await getApplicationSupportDirectory();
    return join(dir.path, dbFilename);
  } catch (e) {
    rethrow;
  }
}

/// The userId whose db file the global [db] currently points to.
/// Used by [switchUserDatabase] to skip redundant switches when the db is
/// already set up for the same user (e.g. offline→online upgrade).
String? _currentDbUserId;

/// Switch the global [db] to the SQLite file that belongs to [userId].
/// Returns `true` when the db was actually swapped, `false` when it was
/// already the correct user's database (a no-op). Callers use the return
/// value to decide whether a [db.connect] is needed — reconnecting on every
/// auth event (e.g. tokenRefreshed) would restart in-progress syncs.
/// Initialises the new database before swapping the global reference so that
/// any code using [db] never sees an uninitialised instance.
/// The old database is only disconnected (not closed) to prevent a
/// ClosedException in any streams or watchers that still hold a reference.
Future<bool> switchUserDatabase(String userId) async {
  if (_currentDbUserId == userId) {
    return false;
  }

  final oldDb = db;
  final userDbPath = await getDatabasePath(userId: userId);

  // Initialise the new db before making it visible to the rest of the app.
  final newDb = PowerSyncDatabase(schema: schema, path: userDbPath, logger: attachedLogger);
  await newDb.initialize();

  // Atomic swap — from this point all callers use the new db.
  db = newDb;
  _currentDbUserId = userId;

  // Notify widgets so they can cancel old stream subscriptions and resubscribe
  // to the new db instance.
  _dbSwitchController.add(null);

  // Gracefully stop the old connection without closing the SQLite handle,
  // so any remaining stream listeners don't receive a ClosedException.
  try {
    await oldDb.disconnect();
  } catch (e) {
  }

  return true;
}

/// Base name of the SQLite files for the configured server (e.g. `postgres`,
/// yielding `postgres.db` / `postgres_<userId>.db`). Used to enumerate all
/// database files belonging to this app.
Future<String> getDatabaseBaseName() async {
  var config = await getServerConfig();
  return config['database'] ?? 'tfm';
}

/// Path of the database file the global [db] currently points to.
Future<String> getActiveDatabasePath() async {
  return getDatabasePath(userId: _currentDbUserId);
}

/// Path of the legacy shared (pre per-user) database `tfm.db`, but only when
/// it exists on disk AND is not the database currently in use. Returns null
/// when there is nothing to inspect (web, no user switched in yet, or the file
/// is absent). Used to surface leftover data that was written to the shared db
/// before per-user isolation / the initialSession switch fix.
Future<String?> getLegacyDatabasePathIfPresent() async {
  if (kIsWeb) return null;
  // The active db is only a per-user file once a user has been switched in.
  // While still on the legacy db there is nothing "left behind" to show.
  if (_currentDbUserId == null) return null;

  final legacyPath = await getDatabasePath();
  final activePath = await getDatabasePath(userId: _currentDbUserId);
  if (legacyPath == activePath) return null;

  return await File(legacyPath).exists() ? legacyPath : null;
}

bool isLoggedIn() {
  return Supabase.instance.client.auth.currentSession?.accessToken != null;
}

/// id of the user currently logged in
/// Note: This function now requires a BuildContext to support offline mode.
/// For offline authentication, use getUserIdFromContext(context) instead.
String? getUserId() {
  return Supabase.instance.client.auth.currentSession?.user.id;
}

/// Get user ID from either Supabase (online) or AuthProvider (offline)
/// This function supports both online and offline authentication modes
String? getUserIdFromContext(dynamic context) {
  // Try to get from Supabase first (online mode)
  final supabaseUserId = getUserId();
  if (supabaseUserId != null) {
    return supabaseUserId;
  }

  // If no Supabase user, try to get from AuthProvider (offline mode)
  try {
    // Import at runtime to avoid circular dependencies
    final authProvider = context.read<dynamic>();
    if (authProvider.runtimeType.toString() == 'AuthProvider') {
      return authProvider.userId as String?;
    }
  } catch (e) {
  }

  return null;
}

/// id of the user currently logged in
Map<String, dynamic>? getDecriptedToken() {
  String? token = Supabase.instance.client.auth.currentSession?.accessToken;
  if (token == null) {
    return null;
  }
  return JwtDecoder.decode(token);
}

// get the current user
User? getCurrentUser() {
  return Supabase.instance.client.auth.currentUser;
}

Future getPlotsByPermissions(String schemaId) async {
  String jwToken = Supabase.instance.client.auth.currentSession?.accessToken ?? '';
  if (jwToken.isEmpty) {
    return [];
  }
  Map<String, dynamic> decodedToken = JwtDecoder.decode(jwToken);
  String troopId = decodedToken['troop_id'];

  Row data = await db.get('SELECT * FROM troop WHERE id = ?', [troopId]);

  try {
    return jsonDecode(data['plot_ids']);
  } catch (e) {
    return [];
  }
}

Future getPlotsNestedJson() async {
  List<Map> rows = await Supabase.instance.client.from('plot_nested_json').select();

  for (var row in rows) {
    db
        .get('SELECT id FROM plot_nested_json WHERE id = ?', [row['id']])
        .then((value) {
          db.execute('UPDATE plot_nested_json SET plot = ?, cluster_id = ? WHERE id = ?', [
            jsonEncode(row['plot'] ?? []),
            row['cluster_id'],
            row['id'],
          ]);
        })
        .catchError((e) {
          db.execute('INSERT INTO plot_nested_json (id, plot, cluster_id) VALUES (?, ?, ?);', [
            row['id'],
            jsonEncode(row['plot'] ?? []),
            row['cluster_id'],
          ]);
        });
  }

  return rows;
}

/// Sign up with email and password.
/// Returns the user if successful, otherwise throws an error.
Future<User> signUp(String email, String password) async {
  try {
    AuthResponse response = await Supabase.instance.client.auth.signUp(
      email: email,
      password: password,
    );
    return response.user!;
  } catch (e) {
    rethrow;
  }
}

/// Sign in with email and password.
/// Returns the user if successful, otherwise throws an error.
Future<User> login(String email, String password) async {
  try {
    AuthResponse response = await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response.user!;
  } catch (e) {
    rethrow;
  }
}

/// Explicit sign out - clear database and log out.
Future<void> changeServer() async {
  //await openDatabase();
  //await logout();
}

/// Sign out and stop syncing — WITHOUT touching local data. The database,
/// including the pending upload queue and the `upload_failures` quarantine,
/// stays intact.
///
/// Wiping local data deliberately does NOT happen here. That is the job of the
/// explicit "Abmelden und Daten löschen" action on the profile screen, which
/// calls [PowerSyncDatabase.disconnectAndClear] itself behind a red
/// confirmation dialog. Having it here made every caller a silent
/// data-destroying logout — including the login dialog, which asks nothing.
Future<void> logout() async {
  await Supabase.instance.client.auth.signOut();
  await db.disconnect();
}

Future<List> listTables() async {
  final tables = await db.execute('SELECT * FROM sqlite_master ORDER BY name;');

  return tables;
}

Future downloadFile(fileName, {force = false}) async {
  return downloadFileImpl(fileName, force: force);
}

Future<PowerSyncDatabase> openDatabase() async {
  bool isSyncMode = true;

  final dbPath = await getDatabasePath();
  final logger = LogService();

  // Windows certificate workaround: PowerSync uses WebSockets which bypass HttpOverrides
  if (!kIsWeb && Platform.isWindows) {
    logger.log('🔌 PowerSync on Windows - relying on global HttpOverrides', level: LogLevel.info);
  }

  db = PowerSyncDatabase(schema: schema, path: dbPath, logger: attachedLogger);

  /**
   * https://pub.dev/packages/sqlite_async
   * options: SqliteOptions(
        webSqliteOptions: WebSqliteOptions(
            wasmUri: 'sqlite3.wasm', workerUri: 'db_worker.js')));
   */

  try {
    await db.initialize();
  } catch (e) {
    rethrow;
  }

  try {
    var config = await getServerConfig();

    await Supabase.initialize(url: config['supabaseUrl'] ?? '', anonKey: config['anonKey'] ?? '');
  } catch (e) {
    rethrow;
  }

  SupabaseConnector? currentConnector;

  if (isLoggedIn()) {
    currentConnector = SupabaseConnector();
    db.connect(connector: currentConnector);
  } else {
  }

  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {

    final AuthChangeEvent event = data.event;
    try {
      if (event == AuthChangeEvent.signedIn) {
        // AuthProvider._onAuthStateChange handles switchUserDatabase + connect
        // for the correct per-user db. Nothing to do here.
        currentConnector = null;
      } else if (event == AuthChangeEvent.signedOut) {
        currentConnector = null;
        await db.disconnect();
      } else if (event == AuthChangeEvent.tokenRefreshed) {
        // Do NOT call db.connect() here — it restarts the sync connection,
        // causing in-progress downloads to start over from scratch.
        // PowerSync automatically calls fetchCredentials() on the connector
        // when the current token expires.
      }
    } catch (e) {
      rethrow;
    }
  });

  // Note: For offline-authenticated users, PowerSync will work in offline-only mode
  // The local SQLite database remains accessible, but no sync will occur until
  // the user logs in online again

  // Demo using SQLite Full-Text Search with PowerSync.
  // See https://docs.powersync.com/usage-examples/full-text-search for more details
  //await configureFts(db);
  return db;
}

/// Thrown by [SupabaseConnector.uploadData] when there is no authenticated
/// session. PowerSync treats it like any other upload error: the CRUD
/// transaction stays in `ps_crud` and is retried after a delay — which is
/// exactly what we want, because the data must wait for a valid login instead
/// of being sent (and lost) without one.
class UploadPausedException implements Exception {
  final String message;
  const UploadPausedException(this.message);

  @override
  String toString() => 'UploadPausedException: $message';
}

/// True while uploads are paused for a missing session. Static so it survives
/// the connector instances that [PowerSyncDatabase.connect] creates, and so
/// the log gets one entry per pause episode instead of one per retry.
bool _uploadPausedForMissingSession = false;

/// Preserve a CRUD op the server rejected (fatal error) or silently ignored
/// (0-row update) in the local-only `upload_failures` table, and surface the
/// event in the app log. Without this the op would vanish together with its
/// completed CRUD transaction, and the local row would revert to the server
/// state at the next checkpoint — the silent-data-loss mechanism behind the
/// 2026-08-16 incident.
Future<void> _quarantineOp(
  PowerSyncDatabase database,
  CrudEntry op, {
  required String reason,
  PostgrestException? error,
}) async {
  try {
    await database.execute(
      'INSERT INTO upload_failures '
      '(id, created_at, table_name, record_id, op, op_data, reason, error_code, error_message) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        const Uuid().v4(),
        DateTime.now().toIso8601String(),
        op.table,
        op.id,
        op.op.name,
        jsonEncode(op.opData ?? {}),
        reason,
        error?.code,
        error?.message,
      ],
    );
  } catch (e) {
    // Never let quarantine bookkeeping break the upload loop, but leave a trace.
    log.severe('Failed to quarantine dropped upload ${op.table}/${op.id}: $e');
  }
  LogService().log(
    '🚨 Upload nicht übernommen: ${op.table} ${op.id} (${op.op.name}) — $reason'
    '${error != null ? ' [${error.code}: ${error.message}]' : ''}. '
    'Daten in upload_failures gesichert.',
    level: LogLevel.error,
  );
}

class SupabaseConnector extends PowerSyncBackendConnector {
  Future<void>? _refreshFuture;

  SupabaseConnector();

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    log.info('uploading data...');
    final transaction = await database.getNextCrudTransaction();

    if (transaction == null) {
      log.info('No data to upload');
      return;
    }

    // Never upload without an authenticated session. The REST client would
    // fall back to the anon key, no RLS policy on `records` matches anon, and
    // PostgREST answers 204 / 0 rows — the queue would drain into nothing.
    // That is the root cause of the 2026-08-16 data loss. Throwing keeps the
    // transaction in ps_crud; PowerSync retries after a delay and the queue
    // flushes by itself once the user has signed in again.
    if (Supabase.instance.client.auth.currentSession == null) {
      if (!_uploadPausedForMissingSession) {
        _uploadPausedForMissingSession = true;
        LogService().log(
          '⏸️ Upload pausiert: keine gültige Anmeldung. '
          'Die Daten bleiben in der Warteschlange und werden nach der '
          'nächsten Anmeldung übertragen.',
          level: LogLevel.warning,
        );
      }
      throw const UploadPausedException('Kein angemeldeter Benutzer — Upload pausiert');
    }
    if (_uploadPausedForMissingSession) {
      _uploadPausedForMissingSession = false;
      LogService().log(
        '▶️ Anmeldung vorhanden — Upload wird fortgesetzt.',
        level: LogLevel.info,
      );
    }

    final rest = Supabase.instance.client.rest;
    final ops = transaction.crud;

    for (var i = 0; i < ops.length; i++) {
      final op = ops[i];
      final table = rest.from(op.table);
      try {
        if (op.op == UpdateType.put) {
          var data = Map<String, dynamic>.of(op.opData!);

          // Check if the table is records table
          if (op.table == 'records' && data['properties'] != null) {
            data['properties'] = jsonDecode(data['properties']);
          }

          data['id'] = op.id;
          // .select() makes PostgREST return the written row: a write the
          // server ignored comes back as [] instead of a bare 204.
          final rows = await table.upsert(data).select('id');
          if (rows.isEmpty) {
            await _quarantineOp(database, op, reason: 'rls_zero_rows');
          }
        } else if (op.op == UpdateType.patch) {
          // Copy instead of mutating op.opData in place, so a later retry of
          // the same op never sees an already-decoded properties value.
          var data = Map<String, dynamic>.of(op.opData!);
          if (op.table == 'records' && data['properties'] != null) {
            data['properties'] = jsonDecode(data['properties']);
          }
          // A row that is invisible under the RLS USING clause matches
          // 0 rows and PostgREST answers 204 "success" (the documented
          // BLOCKED_SILENT_RLS case). With .select() that case is an empty
          // list — quarantine it instead of treating the write as delivered.
          final rows = await table.update(data).eq('id', op.id).select('id');
          if (rows.isEmpty) {
            await _quarantineOp(database, op, reason: 'rls_zero_rows');
          }
        } else if (op.op == UpdateType.delete) {
          // 0 rows on delete means the row is already gone server-side;
          // there is nothing to preserve.
          await table.delete().eq('id', op.id);
        }
      } on PostgrestException catch (e) {
        if (e.code != null && fatalResponseCodes.any((re) => re.hasMatch(e.code!))) {
          // Retrying can never succeed. Quarantine this op and the
          // not-yet-attempted remainder of the transaction (ops before i are
          // already applied server-side), then complete the transaction so
          // the queue is not blocked — but never drop the data silently.
          await _quarantineOp(database, op, reason: 'fatal_error', error: e);
          for (final pending in ops.sublist(i + 1)) {
            await _quarantineOp(database, pending, reason: 'unattempted_after_fatal', error: e);
          }
          break;
        } else {
          // Retryable (network, auth, 5xx, ...): keep the transaction in the
          // queue; PowerSync calls uploadData again.
          rethrow;
        }
      }
    }

    await transaction
        .complete()
        .then((value) {
        })
        .catchError((e) {
        });
  }

  /// Get a Supabase token to authenticate against the PowerSync instance.
  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    // Wait for pending session refresh if any
    await _refreshFuture;

    // Use Supabase token for PowerSync
    var session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      // Not logged in
      return null;
    }

    // If the token is already expired, attempt a proactive refresh before
    // giving up. This covers cases where invalidateCredentials() was never
    // called (e.g. first reconnect after the device was offline for a long
    // time, or background sync firing against a stale session).
    var tokenExpiry = session.expiresAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
    if (tokenExpiry != null && DateTime.now().isAfter(tokenExpiry)) {
      try {
        await Supabase.instance.client.auth.refreshSession().timeout(const Duration(seconds: 30));
      } catch (e) {
        // Refresh failed (e.g. still offline) — return null so PowerSync backs off.
        return null;
      }
      // Re-read the session after a successful refresh.
      session = Supabase.instance.client.auth.currentSession;
      if (session == null) return null;
      tokenExpiry = session.expiresAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
      if (tokenExpiry != null && DateTime.now().isAfter(tokenExpiry)) return null;
    }

    var config = await getServerConfig();
    return PowerSyncCredentials(
      endpoint: config['powersyncUrl'] ?? '',
      token: session.accessToken,
      userId: session.user.id,
      expiresAt: tokenExpiry,
    );
  }

  @override
  void invalidateCredentials() {
    // Trigger a session refresh if auth fails on PowerSync.
    // Generally, sessions should be refreshed automatically by Supabase.
    // However, in some cases it can be a while before the session refresh is
    // retried. We attempt to trigger the refresh as soon as we get an auth
    // failure on PowerSync.
    //
    // This could happen if the device was offline for a while and the session
    // expired, and nothing else attempt to use the session it in the meantime.
    //
    // Timeout the refresh call to avoid waiting for long retries,
    // and ignore any errors. Errors will surface as expired tokens.
    // Use a generous timeout: 5 s was too short on slow mobile networks,
    // causing premature TimeoutExceptions whose swallowed errors left
    // fetchCredentials() returning the still-expired old token to PowerSync
    // and creating a perpetual auth-error loop.
    _refreshFuture = Supabase.instance.client.auth
        .refreshSession()
        .timeout(const Duration(seconds: 30))
        .then((response) => null, onError: (error) => null);
  }
}
