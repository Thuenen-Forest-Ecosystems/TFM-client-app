// Stub for path_provider on web platform
import 'dart:async';

class Directory {
  final String path;

  Directory(this.path);

  bool existsSync() => false;

  Future<bool> exists() async => false;

  Future<Directory> create({bool recursive = false}) async {
    return this;
  }

  List listSync() => [];
}

class File {
  final String path;

  File(this.path);

  bool existsSync() => false;

  Future<bool> exists() async => false;

  Future<void> writeAsBytes(List<int> bytes) async {}

  Future<List<int>> readAsBytes() async => [];

  Future<String> readAsString() async => '';

  Future<void> writeAsString(String contents) async {}
}

Future<Directory> getApplicationDocumentsDirectory() async {
  return Directory('/web-storage');
}

Future<Directory> getApplicationSupportDirectory() async {
  return Directory('/web-support');
}
