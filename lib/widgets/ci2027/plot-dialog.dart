import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/widgets/timestamp-to-timeago.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

class PlotDialog extends StatefulWidget {
  final String id;
  const PlotDialog({super.key, required this.id});

  @override
  State<PlotDialog> createState() => _PlotDialogState();
}

class _PlotDialogState extends State<PlotDialog> {
  Map? _plotData = {};
  Map? _clusterData = {};

  String _plotId = '';
  @override
  void initState() {
    _plotId = widget.id;
    super.initState();
    _getPlotData();
  }

  Future<Map> _getPlotData() async {
    return await db.get('SELECT * FROM plot WHERE id = ?', [widget.id]);
  }

  Future<Map> _getClusterData(clusterName) async {
    return await db.get('SELECT * FROM cluster WHERE cluster_name = ?', [clusterName]);
  }

  Future<void> _launchUrl(Uri url) async {
    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      //title: Text('Plot ${_plotData['plot_name']}'),
      actions: [
        // Button to open native navigation app with coordinates

        ElevatedButton.icon(
          onPressed: () {
            if (_plotData == null) {
              return;
            }
            Map plotLocation = jsonDecode(_plotData!['center_location_json']);
            LatLng plotLatLng = LatLng(plotLocation['coordinates'][1], plotLocation['coordinates'][0]);
            //_launchUrl(Uri.parse('geo:${plotLatLng.latitude},${plotLatLng.longitude}'));
            _launchUrl(Uri.parse('google.navigation:q=${plotLatLng.latitude},${plotLatLng.longitude}'));
            // comgooglemaps://?center=40.765819,-73.975866&zoom=14&views=traffic
          },
          label: Text('Navigation'),
          icon: Icon(Icons.directions_car),
        )
      ],
      content: FutureBuilder(
        future: _getPlotData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.data == null) {
            return Center(child: Text('No data available'));
          }
          _plotData = snapshot.data;
          return Column(
            children: [
              ListTile(
                title: Text('Plot: ${snapshot.data?['plot_name']}'),
                subtitle: Row(
                  children: [
                    Text('Created: '),
                    TimestampToTimeago(timestamp: snapshot.data?['created_at']),
                  ],
                ),
              ),
              FutureBuilder(
                  future: _getClusterData(snapshot.data?['cluster_id']),
                  builder: (context, clusterSnapshot) {
                    if (clusterSnapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    if (clusterSnapshot.hasError) {
                      return Center(child: Text('Error: ${clusterSnapshot.error}'));
                    }
                    if (clusterSnapshot.data == null) {
                      return Center(child: Text('No data available'));
                    }
                    return ListTile(
                      title: Text('Cluster: ${clusterSnapshot.data?['cluster_name']}'),
                      subtitle: Row(
                        children: [
                          Text('Created: '),
                          TimestampToTimeago(timestamp: clusterSnapshot.data?['created_at']),
                        ],
                      ),
                    );
                  }),
            ],
          );
        },
      ),
    );
  }
}
