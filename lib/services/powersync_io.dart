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

Future<Map<String, dynamic>> downloadValidationFilesImpl(
  String directory, {
  bool force = false,
  Function(int, int)? onProgress,
}) async {
  List<String> downloadedFiles = [];
  List<String> errors = [];

  try {
    final appDirectory = await getApplicationDocumentsDirectory();
    String applicationDirectory = '${appDirectory.path}/TFM/validation/$directory';

    final validationDir = Directory(applicationDirectory);
    if (!await validationDir.exists()) {
      await validationDir.create(recursive: true);
    }

    print('Listing files in bucket "validation" at path: "$directory"');
    final response = await Supabase.instance.client.storage
        .from('validation')
        .list(path: directory);

    print('Response from list(): ${response.length} files found');
    if (response.isEmpty) {
      print('No files found in validation/$directory - check Supabase bucket structure');
    } else {
      print('Files: ${response.map((f) => f.name).join(', ')}');
    }

    int totalFiles = response.length;
    int processedFiles = 0;

    for (var fileObject in response) {
      final fileName = fileObject.name;
      final filePath = '$applicationDirectory/$fileName';

      try {
        final file = File(filePath);

        if (!force && await file.exists()) {
          downloadedFiles.add(fileName);
          processedFiles++;
          onProgress?.call(processedFiles, totalFiles);
          continue;
        }

        final fileData = await Supabase.instance.client.storage
            .from('validation')
            .download('$directory/$fileName');

        await file.writeAsBytes(fileData);
        downloadedFiles.add(fileName);
      } catch (e) {
        errors.add('$fileName: $e');
      }

      processedFiles++;
      onProgress?.call(processedFiles, totalFiles);
    }

    return {
      'success': errors.isEmpty,
      'downloadedFiles': downloadedFiles,
      'downloadedCount': downloadedFiles.length,
      'errors': errors,
    };
  } catch (e) {
    return {
      'success': false,
      'downloadedFiles': downloadedFiles,
      'downloadedCount': downloadedFiles.length,
      'errors': [...errors, 'Directory error: $e'],
    };
  }
}
