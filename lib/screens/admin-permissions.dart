import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/components/cluster-list.dart';

class AdminPermissionsScreen extends StatefulWidget {
  const AdminPermissionsScreen({super.key});

  @override
  State<AdminPermissionsScreen> createState() => _AdminPermissionsScreenState();
}

class _AdminPermissionsScreenState extends State<AdminPermissionsScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: false, automaticallyImplyLeading: true, title: Text('Admin Permissions')),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 800, minWidth: 300),
          child: ListView(
            children: <Widget>[
              Card(child: Container(padding: EdgeInsets.all(10), child: Column(children: <Widget>[Text('List of Clusters'), ClusterList()]))),
            ],
          ),
        ),
      ),
    );
  }
}
