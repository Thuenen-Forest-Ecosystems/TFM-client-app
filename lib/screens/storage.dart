import 'package:flutter/material.dart';

import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/services/utils.dart';

class TFMStorage extends StatefulWidget {
  const TFMStorage({super.key});

  @override
  State<TFMStorage> createState() => _TFMStorageState();
}

class _TFMStorageState extends State<TFMStorage> {
  Future<String> _getAttachmentQueue() async {
    String photoPath = await getLocalUri('ci2027_schema_0.0.1.json');
    return photoPath;
  }

  Future<void> _downloadFile(String fileId) async {
    await downloadFile(fileId);
  }

  Future<void> _getLocalFiles() async {
    db.get('SELECT * FROM attachments', []).then((rows) {
      print('rows');
      print(rows);
    });
  }

  @override
  void initState() {
    super.initState();

    print('attachmentQueue');
    _getLocalFiles();

    //_downloadFile('ci2027_plausability_0.0.1.js');
    //_downloadFile('ci2027_schema_0.0.1.json');

    _getAttachmentQueue();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        ElevatedButton(
          onPressed: () {
            _getAttachmentQueue();
          },
          child: const Text('Get Attachment Queue'),
        ),
      ],
    );
  }
}
