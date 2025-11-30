import 'package:universal_io/io.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class OfflineMapService {
  Database? _database;
  String? _mbtilesPath;

  Future<void> initialize() async {
    if (kIsWeb) {
      // Offline maps not supported on web
      return;
    }

    // Copy MBTiles from assets to documents directory
    final documentsDir = await getApplicationDocumentsDirectory();
    _mbtilesPath = '${documentsDir.path}/germany.mbtiles';

    final file = File(_mbtilesPath!);
    if (!await file.exists()) {
      final data = await rootBundle.load('assets/maps/germany.mbtiles');
      final bytes = data.buffer.asUint8List();
      await file.writeAsBytes(bytes);
    }

    _database = await openDatabase(_mbtilesPath!, readOnly: true);
  }

  Future<Uint8List?> getTile(int z, int x, int y) async {
    if (_database == null) await initialize();

    // MBTiles uses TMS y-axis (bottom-left origin)
    final tmsY = (1 << z) - 1 - y;

    final result = await _database!.query(
      'tiles',
      columns: ['tile_data'],
      where: 'zoom_level = ? AND tile_column = ? AND tile_row = ?',
      whereArgs: [z, x, tmsY],
    );

    if (result.isEmpty) return null;
    return result.first['tile_data'] as Uint8List;
  }

  String get mbtilesPath => _mbtilesPath ?? '';

  Future<void> dispose() async {
    await _database?.close();
  }
}
