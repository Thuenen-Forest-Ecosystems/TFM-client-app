import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/services/utils.dart';

class NavigationCar extends StatefulWidget {
  Map target;
  LatLng position;
  NavigationCar({super.key, required this.target, required this.position});

  @override
  State<NavigationCar> createState() => _NavigationCarState();
}

class _NavigationCarState extends State<NavigationCar> {
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
            'NAVIGATION CAR',
            style: TextStyle(fontSize: 11),
          ),
        ),
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
                      launchStringExternal('google.navigation:q=${widget.position.latitude},${widget.position.longitude}');
                    },
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(
                        Icons.directions_car,
                        color: Colors.black54,
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
