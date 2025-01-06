import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terrestrial_forest_monitor/brick/models/schemas.model.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/widgets/admin/storage-list.dart';
import 'package:terrestrial_forest_monitor/widgets/admin/database-list.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: false,
          automaticallyImplyLeading: true,
          title: Text('Admin'),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 800,
              minWidth: 300,
            ),
            child: ListView(
              children: <Widget>[
                Container(
                  margin: EdgeInsets.only(top: 20.0, left: 30.0, right: 30.0),
                  child: Text(
                    'Local Files',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
                Card(
                  margin: EdgeInsets.all(10.0),
                  child: StorageList(),
                ),
                Container(
                  margin: EdgeInsets.only(top: 20.0, left: 30.0, right: 30.0),
                  child: Text(
                    'Local Database',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
                Card(
                  margin: EdgeInsets.all(10.0),
                  child: DatabaseList(),
                )
              ],
            ),
          ),
        ));
  }
}
