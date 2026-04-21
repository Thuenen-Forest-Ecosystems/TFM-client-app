// Platform-specific implementation for dart:io platforms (Android, iOS, Windows, macOS, Linux)
import 'package:universal_io/io.dart';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future downloadFileImpl(String fileName, {bool force = false}) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    String applicationDirectory = '${directory.path}/TFM';

    final path = File('$applicationDirectory/$fileName');

    if (path.existsSync() && !force) {
      return path;
    }
    final Uint8List file = await Supabase.instance.client.storage.from('tfm').download(fileName);
    await path.writeAsBytes(file);
    return path;
  } catch (e) {
    print('Error downloading file: $e');
    return null;
  }
}
