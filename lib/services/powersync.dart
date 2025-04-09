import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:powersync/powersync.dart';
import 'package:powersync/sqlite3_common.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:terrestrial_forest_monitor/config.dart';
import 'package:terrestrial_forest_monitor/services/utils.dart';
import 'package:terrestrial_forest_monitor/services/attachment-helper.dart';

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

Future<String> getDatabasePath() async {
  var config = await getServerConfig();

  final dbFilename = '${config['database']}.db';
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
          db.execute('UPDATE plot_nested_json SET plot = ?, cluster_id = ? WHERE id = ?', [jsonEncode(row['plot'] ?? []), row['cluster_id'], row['id']]);
        })
        .catchError((e) {
          db.execute('INSERT INTO plot_nested_json (id, plot, cluster_id) VALUES (?, ?, ?);', [row['id'], jsonEncode(row['plot'] ?? []), row['cluster_id']]);
        });
  }

  return rows;
}

/// Sign up with email and password.
/// Returns the user if successful, otherwise throws an error.
Future<User> signUp(String email, String password) async {
  try {
    AuthResponse response = await Supabase.instance.client.auth.signUp(email: email, password: password);
    return response.user!;
  } catch (e) {
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
    print('Error logging in: $e');
    rethrow;
  }
}

/// Explicit sign out - clear database and log out.
Future<void> changeServer() async {
  //await openDatabase();
  //await logout();
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

Future downloadFile(fileName, {force = false}) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    String applicationDirectory = '${directory.path}/TFM';

    // get Files in Directory
    //final files = Directory(applicationDirectory).listSync();
    File path = File('$applicationDirectory/' + fileName);

    if (path.existsSync() && !force) {
      return path;
    }
    final Uint8List file = await Supabase.instance.client.storage.from('tfm').download(fileName);
    await path.writeAsBytes(file);
    return path;
  } catch (e) {
    print('Error downloading file: $e');
  }
}

Future<PowerSyncDatabase> openDatabase() async {
  bool isSyncMode = true;

  final dbPath = await getDatabasePath();

  db = PowerSyncDatabase(schema: schema, path: dbPath, logger: attachedLogger);

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
    var config = await getServerConfig();

    await Supabase.initialize(url: config['supabaseUrl'] ?? '', anonKey: config['anonKey'] ?? '');
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
  return db;
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

    final rest = Supabase.instance.client.rest;

    try {
      for (var op in transaction.crud) {
        final table = rest.from(op.table);
        if (op.op == UpdateType.put) {
          var data = Map<String, dynamic>.of(op.opData!);

          // Check if the table is records table
          print(op.table + ' PUT');
          if (op.table == 'records' && data['properties'] != null) {
            data['properties'] = jsonDecode(data['properties']);
            print('PS: properties: ${data['properties']}');
          }

          data['id'] = op.id;
          await table.upsert(data);
        } else if (op.op == UpdateType.patch) {
          // Check if the table is records table
          print(op.table + ' PATCH');
          if (op.table == 'records' && op.opData!['properties'] != null) {
            op.opData!['properties'] = jsonDecode(op.opData!['properties']);
            print('PS: properties: ${op.opData!['properties']}');
          }
          await table.update(op.opData!).eq('id', op.id);
        } else if (op.op == UpdateType.delete) {
          await table.delete().eq('id', op.id);
        }
      }

      await transaction
          .complete()
          .then((value) {
            print('Data uploaded successfully');
          })
          .catchError((e) {
            print('Error completing transaction: $e');
          });
    } on PostgrestException catch (e) {
      if (e.code != null && fatalResponseCodes.any((re) => re.hasMatch(e.code!))) {
        print('PS: Fatal error: ${e.code} ${e.message}');
        // print values for debugging
        print('PS: ${transaction.crud}');
        // print table name
        print('PS: ${transaction.crud[0].table}');
        await transaction.complete();
      } else {
        print('Error uploading data: $e');
        print('PS: ${transaction.crud}');
        print('PS: ${transaction.crud[0].table}');
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

    //var config = AppConfig.servers[0];
    var config = await getServerConfig();
    print('powersyncUrl INIT');
    print(config['powersyncUrl']);
    print(token);
    print(userId);
    print(expiresAt);

    return PowerSyncCredentials(endpoint: config['powersyncUrl'] ?? '', token: token, userId: userId, expiresAt: expiresAt);
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
    _refreshFuture = Supabase.instance.client.auth.refreshSession().timeout(const Duration(seconds: 5)).then((response) => null, onError: (error) => null);
  }
}
