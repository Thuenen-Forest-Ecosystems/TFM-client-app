import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:powersync/sqlite3_common.dart';
import 'package:url_launcher/url_launcher_string.dart';

String degreeToGon(double degree) {
  return '${(degree * 200 / 180).toStringAsFixed(0)} gon';
}

void launchStringExternal(String url) async {
  if (!await launchUrlString(
    url,
    mode: LaunchMode.externalApplication,
  )) {
    throw Exception('Could not launch $url');
  }
}

String prettyDistance(double distance) {
  if (distance > 10000) {
    return '${(distance / 1000).toStringAsFixed(0)} km';
  } else if (distance > 1000) {
    return '${(distance / 1000).toStringAsFixed(2)} km';
  } else if (distance > 10) {
    return '${distance.toStringAsFixed(0)} m';
  } else {
    return '${distance.toStringAsFixed(2)} m';
  }
}

List<Map> orderPlotByDistance(ResultSet plots, String locationAttribute, LatLng from) {
  List<Map> plotsWithDistance = [];

  //ResultSet plots = await db.getAll('SELECT * FROM plot WHERE center_location_json IS NOT NULL');

  for (var plot in plots) {
    if (plot[locationAttribute] == null) continue;
    Map plotLocation = jsonDecode(plot[locationAttribute]);
    LatLng plotLatLng = LatLng(plotLocation['coordinates'][1], plotLocation['coordinates'][0]);
    double distance = Geolocator.distanceBetween(from.latitude, from.longitude, plotLatLng.latitude, plotLatLng.longitude);
    plotsWithDistance.add({
      'plot': plot,
      'position': plotLatLng,
      'distance': distance,
      'bearing': Geolocator.bearingBetween(from.latitude, from.longitude, plotLatLng.latitude, plotLatLng.longitude),
      'prettyDistance': prettyDistance(distance),
    });
  }

  plotsWithDistance.sort((m1, m2) {
    return m1["distance"].compareTo(m2["distance"]);
  });
  return plotsWithDistance;
}

LatLngBounds getBounds(ResultSet plots, String locationAttribute) {
  double minLat = 90;
  double maxLat = -90;
  double minLon = 180;
  double maxLon = -180;

  for (var plot in plots) {
    if (plot[locationAttribute] == null) continue;
    Map plotLocation = jsonDecode(plot[locationAttribute]);
    double lat = plotLocation['coordinates'][1];
    double lon = plotLocation['coordinates'][0];
    if (lat < minLat) minLat = lat;
    if (lat > maxLat) maxLat = lat;
    if (lon < minLon) minLon = lon;
    if (lon > maxLon) maxLon = lon;
  }

  return LatLngBounds(LatLng(minLat, minLon), LatLng(maxLat, maxLon));
}

LatLng getCenterLocation(ResultSet plots, String locationAttribute) {
  double lat = 0;
  double lon = 0;
  int count = 0;

  for (var plot in plots) {
    if (plot[locationAttribute] == null) continue;
    Map plotLocation = jsonDecode(plot[locationAttribute]);
    lat += plotLocation['coordinates'][1];
    lon += plotLocation['coordinates'][0];
    count++;
  }

  return LatLng(lat / count, lon / count);
}