import 'package:flutter/material.dart';
import 'package:powersync_attachments_helper/powersync_attachments_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class StorageList extends StatefulWidget {
  final String bucket;
  final String folder;
  const StorageList({super.key, required this.bucket, required this.folder});

  @override
  State<StorageList> createState() => _StorageListState();
}

class _StorageListState extends State<StorageList> {
  //final AbstractRemoteStorageAdapter remoteStorage;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getStorage();
  }

  void _getStorage() async {
    // https://supabase.com/docs/reference/self-hosting-storage/gets-all-buckets
    try {
      final List<Bucket> buckets = await Supabase.instance.client.storage.listBuckets();
      print('Buckets: ${buckets}');

      //final Bucket bucket = await Supabase.instance.client.storage.getBucket('TFM');
      //print('Bucket: $bucket');
    } catch (e) {
      print('Error getting bucket: $e');
    }
  }

  //https://supabase.com/blog/offline-first-flutter-apps

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: Supabase.instance.client.storage.listBuckets(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            final List<Bucket> buckets = snapshot.data as List<Bucket>;
            return Column(
              children: buckets.map((bucket) {
                return ListTile(
                  title: Text('Bucket Name: ${bucket.name}'),
                  subtitle: Text('ID: ${bucket.id}'),
                );
              }).toList(),
            );
          }
        });
  }
}
