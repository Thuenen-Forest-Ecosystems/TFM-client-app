import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
//import './app_config.dart';
import '../models/schema.dart';
import 'package:logging/logging.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

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

late final PowerSyncDatabase db;

Future<String> getDatabasePath() async {
  const dbFilename = 'tfm-local-DB.db';
  // getApplicationSupportDirectory is not supported on Web
  if (kIsWeb) {
    return dbFilename;
  }

  try {
    final dir = await getApplicationSupportDirectory();
    return join(dir.path, dbFilename);
  } catch (e) {
    print('Error getting database path: $e');
    rethrow;
  }
}

bool isLoggedIn() {
  return Supabase.instance.client.auth.currentSession?.accessToken != null;
}

/// id of the user currently logged in
String? getUserId() {
  return Supabase.instance.client.auth.currentSession?.user.id;
}

// get the current user
User? getCurrentUser() {
  return Supabase.instance.client.auth.currentUser;
}

/// Sign up with email and password.
/// Returns the user if successful, otherwise throws an error.
Future<User> signUp(String email, String password) async {
  try {
    AuthResponse response = await Supabase.instance.client.auth.signUp(email: email, password: password);
    return response.user!;
  } catch (e) {
    print('Error logging in: $e');
    rethrow;
  }
}

/// Sign in with email and password.
/// Returns the user if successful, otherwise throws an error.
Future<User> login(String email, String password) async {
  try {
    AuthResponse response = await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
    return response.user!;
  } catch (e) {
    print('Error logging in: ${e}');
    rethrow;
  }
}

/// Explicit sign out - clear database and log out.
Future<void> logout() async {
  await Supabase.instance.client.auth.signOut();
  await db.disconnectAndClear();
  //await db.disconnect();

  // add Delay to ensure that the database is cleared before the user is logged out
  await Future.delayed(Duration(milliseconds: 100));
}

Future<List> listTables() async {
  final tables = await db.execute('SELECT * FROM sqlite_master ORDER BY name;');

  return tables;
}

Future<void> openDatabase() async {
  bool isSyncMode = true;

  final dbPath = await getDatabasePath();

  db = PowerSyncDatabase(
    schema: schema,
    path: dbPath,
    logger: attachedLogger,
  );

  /**
   * https://pub.dev/packages/sqlite_async
   * options: SqliteOptions(
        webSqliteOptions: WebSqliteOptions(
            wasmUri: 'sqlite3.wasm', workerUri: 'db_worker.js')));
   */

  try {
    await db.initialize();
    print('Database initialized');
  } catch (e) {
    print('Error initializing database: $e');
    rethrow;
  }

  try {
    print(dotenv.env['SUPABASE_URL']);
    print(dotenv.env['SUPABASE_ANON_KEY']);
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );
    print('Supabase initialized');
  } catch (e) {
    print('Error initializing Supabase: $e');
    rethrow;
  }

  SupabaseConnector? currentConnector;

  if (isLoggedIn()) {
    currentConnector = SupabaseConnector();
    db.connect(connector: currentConnector);
    print('Logged in');
  } else {
    print('Not logged in');
  }

  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    print('onAuthStateChange: ${data.event}');

    final AuthChangeEvent event = data.event;
    try {
      if (event == AuthChangeEvent.signedIn) {
        currentConnector = SupabaseConnector();
        db.connect(connector: currentConnector!);
      } else if (event == AuthChangeEvent.signedOut) {
        currentConnector = null;
        await db.disconnect();
      } else if (event == AuthChangeEvent.tokenRefreshed) {
        currentConnector?.prefetchCredentials();
      }
    } catch (e) {
      print('Error handling auth state change: $e');
      rethrow;
    }
  });

  // Demo using SQLite Full-Text Search with PowerSync.
  // See https://docs.powersync.com/usage-examples/full-text-search for more details
  //await configureFts(db);
}

class SupabaseConnector extends PowerSyncBackendConnector {
  Future<void>? _refreshFuture;

  SupabaseConnector();

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    log.info('uploading data...');
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) {
      return;
    }

    final rest = Supabase.instance.client.rest;

    try {
      for (var op in transaction.crud) {
        final table = rest.from(op.table);
        if (op.op == UpdateType.put) {
          var data = Map<String, dynamic>.of(op.opData!);
          data['id'] = op.id;
          await table.upsert(data);
        } else if (op.op == UpdateType.patch) {
          await table.update(op.opData!).eq('id', op.id);
        } else if (op.op == UpdateType.delete) {
          await table.delete().eq('id', op.id);
        }
      }

      await transaction.complete();
    } on PostgrestException catch (e) {
      if (e.code != null && fatalResponseCodes.any((re) => re.hasMatch(e.code!))) {
        await transaction.complete();
      } else {
        print('Error uploading data: $e');
        rethrow;
      }
    }
  }

  /// Get a Supabase token to authenticate against the PowerSync instance.
  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    // Wait for pending session refresh if any
    await _refreshFuture;

    // Use Supabase token for PowerSync
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      // Not logged in
      return null;
    }

    // Use the access token to authenticate against PowerSync
    final token = session.accessToken;

    // userId and expiresAt are for debugging purposes only
    final userId = session.user.id;
    final expiresAt = session.expiresAt == null ? null : DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);

    print(dotenv.env['POWERSYNC_URL']);
    print(token);
    print(userId);

    return PowerSyncCredentials(
      endpoint: dotenv.env['POWERSYNC_URL'] ?? '',
      token: token,
      userId: userId,
      expiresAt: expiresAt,
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
    _refreshFuture = Supabase.instance.client.auth.refreshSession().timeout(const Duration(seconds: 5)).then(
          (response) => null,
          onError: (error) => null,
        );
  }
}
