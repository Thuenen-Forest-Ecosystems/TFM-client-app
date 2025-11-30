// Web stub for file operations
import 'dart:typed_data';

Future downloadFileImpl(String fileName, {bool force = false}) async {
  print('File download not supported on web: $fileName');
  return null;
}

Future<Map<String, dynamic>> downloadValidationFilesImpl(
  String directory, {
  bool force = false,
  Function(int, int)? onProgress,
}) async {
  print('Validation file download not supported on web');
  return {
    'success': false,
    'downloadedFiles': [],
    'downloadedCount': 0,
    'errors': ['Web not supported'],
  };
}
