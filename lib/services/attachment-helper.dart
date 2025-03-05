import 'dart:async';

import 'package:powersync_attachments_helper/powersync_attachments_helper.dart';
import 'package:powersync_core/powersync_core.dart';
import 'package:terrestrial_forest_monitor/services/_deprecated_storage-adapter.dart';

// https://github.com/powersync-ja/powersync.dart/blob/5cd42bba7c49deb9e9182ce179f9057839e1a41d/demos/supabase-todolist/lib/attachments/queue.dart

// Assume PowerSync database is initialized elsewhere
//late PowerSyncDatabase db;
// Assume remote storage is implemented elsewhere
AbstractRemoteStorageAdapter remoteStorage = SupabaseStorageAdapter();
late AttachmentQueue attachmentQueue;

/// Function to handle errors when downloading attachments
/// Return false if you want to archive the attachment
Future<bool> onDownloadError(Attachment attachment, Object exception) async {
  if (exception.toString().contains('Object not found')) {
    return false;
  }
  return true;
}

class AttachmentQueue extends AbstractAttachmentQueue {
  AttachmentQueue(db, remoteStorage, attachmentDirectoryName)
      : super(
          db: db,
          remoteStorage: remoteStorage,
          attachmentDirectoryName: attachmentDirectoryName,
          onDownloadError: onDownloadError,
        );

  @override
  init() async {
    await super.init();
  }

  @override
  Future<Attachment> saveFile(String fileId, int size, {mediaType = 'image/jpeg'}) async {
    print('SAVE: $fileId');
    String filename = '$fileId';
    Attachment photoAttachment = Attachment(
      id: fileId,
      filename: filename,
      state: AttachmentState.queuedUpload.index,
      mediaType: mediaType,
      localUri: getLocalFilePathSuffix(filename),
      size: size,
    );

    return attachmentsService.saveAttachment(photoAttachment);
  }

  @override
  Future<Attachment> deleteFile(String fileId) async {
    String filename = '$fileId';
    Attachment photoAttachment = Attachment(id: fileId, filename: filename, state: AttachmentState.queuedDelete.index);

    return attachmentsService.saveAttachment(photoAttachment);
  }

  @override
  StreamSubscription<void> watchIds({String fileExtension = 'json'}) {
    return db.watch('''
      SELECT bucket_schema_file_name, bucket_plausability_file_name FROM schemas WHERE bucket_schema_file_name IS NOT NULL
    ''').map((results) {
      List<String> idsList = [];
      for (var row in results) {
        idsList.add(row['bucket_schema_file_name'] as String);
        idsList.add(row['bucket_plausability_file_name'] as String);
      }
      return idsList;
      return results.map((row) => row['bucket_schema_file_name'] as String).toList();
    }).listen((ids) async {
      List<String> idsInQueue = await attachmentsService.getAttachmentIds();
      List<String> relevantIds = ids.where((element) => !idsInQueue.contains(element)).toList();
      print('watchIds');
      print(relevantIds);
      print(idsInQueue);
      relevantIds = idsInQueue;

      syncingService.processIds(ids, fileExtension);
    });
  }
}

initializeAttachmentQueue(PowerSyncDatabase db) async {
  attachmentQueue = AttachmentQueue(db, remoteStorage, 'TFM');
  await attachmentQueue.init();
}
