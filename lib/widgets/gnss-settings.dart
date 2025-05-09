import 'package:flutter/material.dart';

import 'package:terrestrial_forest_monitor/polyfill/gnss-serial-selection.dart'
    if (dart.library.html) 'package:terrestrial_forest_monitor/polyfill/gnss-serial-selection.dart'
    if (dart.library.io) 'package:terrestrial_forest_monitor/widgets/gnss-serial-selection.dart';

class GnssSettings extends StatefulWidget {
  const GnssSettings({super.key});

  @override
  State<GnssSettings> createState() => _GnssSettingsState();
}

class _GnssSettingsState extends State<GnssSettings> {
  List availableDevices = [];

  Future<List> _getAvailableDevices() async {
    // Get available devices

    return availableDevices;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GnssSerialSelection(),
        Divider(),
        FutureBuilder(
          future: _getAvailableDevices(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (snapshot.hasData) {
              if (availableDevices.isEmpty) {
                return Center(child: Container(padding: EdgeInsets.all(10.0), child: Text('No devices saved')));
              }
              return ListView.builder(
                physics: ScrollPhysics(),
                addAutomaticKeepAlives: true,
                shrinkWrap: true,
                itemCount: availableDevices.length,
                itemBuilder: (_, index) => ListTile(title: Text(availableDevices[index]['name']), subtitle: Text(availableDevices[index]['status']), trailing: Icon(Icons.more_vert)),
              );
            } else {
              return Center(child: Container(padding: EdgeInsets.all(10.0), child: Text('No devices saved')));
            }
          },
        ),
      ],
    );
  }
}
