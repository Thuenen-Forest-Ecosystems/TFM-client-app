import 'dart:io';
import 'dart:typed_data';
import 'package:powersync_attachments_helper/powersync_attachments_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:terrestrial_forest_monitor/config.dart';

class SupabaseStorageAdapter implements AbstractRemoteStorageAdapter {
  @override
  Future<void> uploadFile(String filename, File file, {String mediaType = 'text/plain'}) async {
    _checkSupabaseBucketIsConfigured();

    try {
      final bucket = AppConfig.servers[0]['supabaseStorageBucket'];
      if (bucket == null) {
        throw Exception('Supabase storage bucket is not configured in .env file');
      }
      await Supabase.instance.client.storage.from(bucket).upload(filename, file, fileOptions: FileOptions(contentType: mediaType));
    } catch (error) {
      throw Exception(error);
    }
  }

  @override
  Future<Uint8List> downloadFile(String filePath) async {
    _checkSupabaseBucketIsConfigured();
    try {
      final bucket = AppConfig.servers[0]['supabaseStorageBucket'];
      if (bucket == null) {
        throw Exception('Supabase storage bucket is not configured in .env file');
      }
      print('downloadFile $filePath $bucket');
      Uint8List fileBlob = await Supabase.instance.client.storage.from(bucket).download(filePath);
      return fileBlob;
      final image = img.decodeImage(fileBlob);
      Uint8List blob = img.JpegEncoder().encode(image!);
      return blob;
    } catch (error) {
      print('downloadFile error $error');
      throw Exception(error);
    }
  }

  @override
  Future<void> deleteFile(String filename) async {
    _checkSupabaseBucketIsConfigured();

    try {
      final bucket = AppConfig.servers[0]['supabaseStorageBucket'];
      if (bucket == null) {
        throw Exception('Supabase storage bucket is not configured in .env file');
      }
      await Supabase.instance.client.storage.from(bucket).remove([filename]);
    } catch (error) {
      throw Exception(error);
    }
  }

  void _checkSupabaseBucketIsConfigured() {
    if (AppConfig.servers[0]['supabaseStorageBucket']?.isEmpty ?? true) {
      throw Exception('Supabase storage bucket is not configured in app_config.dart');
    }
  }
}
