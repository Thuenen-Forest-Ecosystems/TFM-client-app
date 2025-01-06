import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/services/utils.dart';
import 'package:terrestrial_forest_monitor/widgets/timestamp-to-timeago.dart';

class Navigation extends StatefulWidget {
  Map target;
  LatLng position;
  Navigation({super.key, required this.target, required this.position});

  @override
  State<Navigation> createState() => _NavigationState();
}

class _NavigationState extends State<Navigation> {
  @override
  Widget build(BuildContext context) {
    double? distance;
    double? bearing;

    Position? lastPosition = context.watch<GpsPositionProvider>().lastPosition;

    if (lastPosition != null) {
      distance = Geolocator.distanceBetween(
        lastPosition.latitude,
        lastPosition.longitude,
        widget.position.latitude,
        widget.position.longitude,
      );
      bearing = Geolocator.bearingBetween(
        lastPosition.latitude,
        lastPosition.longitude,
        widget.position.latitude,
        widget.position.longitude,
      );
      if (bearing < 0) {
        bearing += 360;
      }
    }

    return Stack(
      children: [
        Positioned(
          top: 5,
          left: 5,
          child: Text(
            'NAVIGATION',
            style: TextStyle(fontSize: 11),
          ),
        ),
        Positioned(
          bottom: 5,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TimestampToTimeago(
                timestamp: lastPosition?.timestamp.toIso8601String(),
                style: TextStyle(fontSize: 10),
              ),
              //Text(lastPosition?.timestamp != null ? '${lastPosition?.timestamp.toIso8601String()}' : 'No GPS signal', style: TextStyle(fontSize: 10)),
            ],
          ),
        ),
        if (context.read<GpsPositionProvider>().listeningPosition)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text('Richtungswinkel', style: TextStyle(fontSize: 15)),
                Text(bearing != null ? '${degreeToGon(bearing)}' : 'No GPS signal', style: TextStyle(fontSize: 20)),
                SizedBox(
                  width: 20,
                  child: Divider(
                    height: 20,
                    thickness: 1,
                  ),
                ),
                Text('Entfernung', style: TextStyle(fontSize: 15)),
                Text(distance != null ? prettyDistance(distance) : 'No GPS signal', style: TextStyle(fontSize: 20)),
              ],
            ),
          ),
        if (!context.read<GpsPositionProvider>().listeningPosition)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ClipOval(
                  child: Material(
                    color: Theme.of(context).primaryColor, // Button color
                    child: InkWell(
                      splashColor: Colors.red, // Splash color
                      onTap: () {
                        context.read<GpsPositionProvider>().navigateToTarget(widget.position, widget.target);
                      },
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Icon(
                          Icons.navigation,
                          color: Colors.black26,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
