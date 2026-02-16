import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:powersync/sqlite3_common.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrestrial_forest_monitor/config.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/services/organization_selection_service.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

bool isNumeric(String? s) {
  if (s == null) {
    return false;
  }
  return double.tryParse(s) != null;
}

String degreeToGon(double degree) {
  return '${(degree * 200 / 180).toStringAsFixed(0)} gon';
}

Future<Map<String, String>> getServerConfig() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String? serverName = prefs.getString('selectedServer');
  if (serverName != null) {
    return AppConfig.servers.firstWhere(
      (element) => serverName == element['supabaseUrl'],
      orElse: () => AppConfig.servers[0],
    );
  }
  return AppConfig.servers[0];
}

void launchStringExternal(String url) async {
  if (!await launchUrlString(url, mode: LaunchMode.externalApplication)) {
    throw Exception('Could not launch $url');
  }
}

Future<Map> plotAsJson(String plotId) async {
  Map plotRecord = Map.from(await db.get('SELECT * FROM plot WHERE id = ?', [plotId]) as Map);

  List<Map<String, dynamic>> tree = (await db.getAll('SELECT * FROM tree WHERE plot_id=?', [
    plotId,
  ])).map((t) => Map<String, dynamic>.from(t)).toList();
  plotRecord['tree'] = tree;

  List<Map<String, dynamic>> deadwood = (await db.getAll('SELECT * FROM deadwood WHERE plot_id=?', [
    plotId,
  ])).map((t) => Map<String, dynamic>.from(t)).toList();
  plotRecord['deadwood'] = deadwood;

  return plotRecord;
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
    double distance = Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      plotLatLng.latitude,
      plotLatLng.longitude,
    );
    plotsWithDistance.add({
      'plot': plot,
      'position': plotLatLng,
      'distance': distance,
      'bearing': Geolocator.bearingBetween(
        from.latitude,
        from.longitude,
        plotLatLng.latitude,
        plotLatLng.longitude,
      ),
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

Future<String> getUserStorageDirectory() async {
  if (kIsWeb) {
    return '/web-storage';
  }
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
}

Future<String> getStorageDirectory() async {
  String userStorageDirectory = await getUserStorageDirectory();
  return '$userStorageDirectory/TFM';
}

Future<String> getLocalUri(String filePath) async {
  String storageDirectory = await getStorageDirectory();
  return '$storageDirectory/$filePath';
}

double? dmsToDecimal(String dms, String direction) {
  if (dms.isEmpty ||
      (direction != 'N' && direction != 'S' && direction != 'E' && direction != 'W')) {
    return null; // Invalid input
  }

  double degrees = 0;
  double minutes = 0;

  try {
    if (direction == 'N' || direction == 'S') {
      // Latitude format DDMM.MMMM
      if (dms.length < 3) return null; // Need at least DMM.
      degrees = double.parse(dms.substring(0, 2));
      minutes = double.parse(dms.substring(2));
    } else {
      // Longitude format DDDMM.MMMM
      if (dms.length < 4) return null; // Need at least DMM.
      degrees = double.parse(dms.substring(0, 3));
      minutes = double.parse(dms.substring(3));
    }
  } catch (e) {
    print("Error parsing DMS value '$dms': $e");
    return null; // Parsing failed
  }

  double decimalDegrees = degrees + (minutes / 60.0);

  if (direction == 'W' || direction == 'S') {
    decimalDegrees = -decimalDegrees;
  }

  return decimalDegrees;
}

double? dmsToDecimal_deprecated(String dms, String direction) {
  if (dms.isEmpty ||
      (direction != 'N' && direction != 'S' && direction != 'E' && direction != 'W')) {
    return null; // Invalid input
  }

  String degreesPart = dms.substring(0, 3);
  String minutesPart = dms.substring(3);

  int degrees = int.tryParse(degreesPart) ?? 0;
  double minutes = double.tryParse(minutesPart) ?? 0.0;

  double decimalDegrees = degrees + (minutes / 60.0);

  if (direction.toUpperCase() == 'W' || direction.toUpperCase() == 'S') {
    decimalDegrees = -decimalDegrees;
  } else if (direction.toUpperCase() != 'E' && direction.toUpperCase() != 'N') {
    // Handle invalid direction input (optional: throw error or return null)
    print("Warning: Invalid direction '$direction'. Assuming positive.");
  }

  return decimalDegrees;
}

Future<ResultSet> setDeviceSettings(String key, String value) async {
  Map<String, dynamic>? currentValue = await getDeviceSettings(key);
  if (currentValue != null && currentValue['id'] != null) {
    return db.execute('UPDATE device_settings SET value = ? WHERE id = ?', [
      value,
      currentValue['id'],
    ]);
  } else {
    const uuid = Uuid();
    String settingId = uuid.v4();
    return db.execute('INSERT INTO device_settings (id, key, value) VALUES (?, ?, ?)', [
      settingId,
      key,
      value,
    ]);
  }
}

Future<Map<String, dynamic>?> getDeviceSettings(String key) async {
  try {
    return await db.get('SELECT * FROM device_settings WHERE key = ?', [key]);
  } on StateError {
    return null; // Return null if not found globally either
  }
}

Future<ResultSet> setSettings(String key, String value) async {
  Map<String, dynamic>? currentValue = await getSettings(key);

  if (currentValue != null && currentValue['id'] != null) {
    return db.execute('UPDATE user_settings SET value = ? WHERE id = ?', [
      value,
      currentValue['id'],
    ]);
  } else {
    const uuid = Uuid();
    String settingId = uuid.v4();
    return db.execute('INSERT INTO user_settings (id, key, value, user_id) VALUES (?, ?, ?, ?)', [
      settingId,
      key,
      value,
      getUserId(),
    ]);
  }
}

Future<Map<String, dynamic>?> getSettings(String key) async {
  try {
    // First, try fetching with user_id
    try {
      return await db.get('SELECT * FROM user_settings WHERE key = ? AND user_id = ?', [
        key,
        getUserId(),
      ]);
    } on StateError {
      // If not found for the specific user, try fetching without user_id (fallback)
      try {
        return await db.get('SELECT * FROM user_settings WHERE key = ?', [key]);
      } on StateError {
        // Catch 'Bad state: No element' if no row found at all
        return null; // Return null if not found globally either
      }
    }
  } catch (e) {
    // Catch any other unexpected database errors during the process
    return null; // Return null on other errors as well
  }
}

Future<Map<String, dynamic>?> getSettings_deprecated(String key) async {
  try {
    return await db.get('SELECT * FROM user_settings WHERE key = ? AND user_id = ?', [
      key,
      getUserId(),
    ]);
  } catch (e) {
    // Return null if no setting found
    return await db.get('SELECT * FROM user_settings WHERE key = ?', [key]);
  }
}

CurrentNMEA? parseData(List<int> data, CurrentNMEA? nmeaState) {
  // Allow nmeaState to be null initially
  // If nmeaState is null, create a new instance
  nmeaState ??= CurrentNMEA();

  String rawData = String.fromCharCodes(data);

  try {
    // Split by newlines in case multiple NMEA sentences were received
    List<String> sentences = rawData.split('\n');

    for (String sentence in sentences) {
      // Trim the sentence to remove any whitespace
      sentence = sentence.trim();

      // Skip empty lines
      if (sentence.isEmpty) continue;

      // Check if it's a valid NMEA sentence (starts with $)
      if (sentence.startsWith('\$')) {
        try {
          List<String> fields = sentence.split(',');

          // Ensure there are enough fields before accessing them
          if (fields.length < 2) continue;

          // Extract talker ID (e.g., GNRMC, GNGGA) - handle potential checksum *NN
          String sentenceIdentifier = fields[0];
          String talkerId = sentenceIdentifier.substring(
            1,
            sentenceIdentifier.contains('*')
                ? sentenceIdentifier.indexOf('*')
                : sentenceIdentifier.length,
          );

          // https://openrtk.readthedocs.io/en/latest/communication_port/nmea.html
          // --- GNRMC ---
          if (talkerId.endsWith('RMC')) {
            // Check for any RMC sentence (GPRMC, GNRMC, etc.)
            if (fields.length > 9) {
              String status = fields[2];
              if (status == 'A') {
                String latitude = fields[3];
                String latitudeDirection = fields[4];
                String longitude = fields[5];
                String longitudeDirection = fields[6];
                String speedOverGroundKnots = fields[7]; // <-- Get speed
                String courseOverGround = fields[8]; // <-- Get heading

                nmeaState.latitude = dmsToDecimal(latitude, latitudeDirection);
                nmeaState.longitude = dmsToDecimal(longitude, longitudeDirection);
                nmeaState.heading = double.tryParse(courseOverGround);
                nmeaState.speedKnots = double.tryParse(
                  speedOverGroundKnots,
                ); // <-- Parse and store speed
              }
            }
            // --- GNGGA ---
          } else if (talkerId.endsWith('GGA')) {
            // Check for any GGA sentence
            if (fields.length > 10) {
              // Need enough fields for altitude etc.
              String time = fields[1];
              String latitude = fields[2];
              String latitudeDirection = fields[3];
              String longitude = fields[4];
              String longitudeDirection = fields[5];
              String quality = fields[6];
              String satellites = fields[7];
              String horizontalDilution = fields[8];
              String altitude = fields[9];
              String altitudeUnits = fields[10]; // Usually 'M' for meters

              // nmeaState.timestamp = DateTime.tryParse(time) ?? DateTime.now(); // Basic time parsing

              // Update only if quality indicates a valid fix (quality > 0)
              int? fixQualityInt = int.tryParse(quality);
              if (fixQualityInt != null && fixQualityInt > 0) {
                nmeaState.latitude = dmsToDecimal(latitude, latitudeDirection);
                nmeaState.longitude = dmsToDecimal(longitude, longitudeDirection);
                nmeaState.altitude = double.tryParse(altitude);
                nmeaState.satellites = int.tryParse(satellites);
                nmeaState.hdop = double.tryParse(horizontalDilution); // Store HDOP from GGA
                nmeaState.fixQuality = quality;
              } else {
                // Fix is not valid, maybe clear relevant fields?
                // nmeaState.latitude = null;
                // nmeaState.longitude = null;
                // nmeaState.altitude = null;
                nmeaState.fixQuality = quality; // Still store the quality indicator
              }
            }
            // --- GNGSA ---
          } else if (talkerId.endsWith('GSA')) {
            // Check for any GSA sentence
            if (fields.length > 17) {
              // Need enough fields for DOPs
              String mode = fields[1]; // M=Manual, A=Automatic
              String fixType = fields[2]; // 1=No fix, 2=2D, 3=3D
              // String satelliteIds = fields.sublist(3, 15).join(', '); // Not typically stored
              String pdop = fields[15];
              String hdop = fields[16];
              String vdop = fields[17];

              // nmeaState.mode = mode; // Mode from GSA
              nmeaState.fixType = int.tryParse(fixType);
              nmeaState.pdop = double.tryParse(pdop);
              // Prefer HDOP from GGA if available, but store GSA's if GGA wasn't parsed yet
              nmeaState.hdop ??= double.tryParse(hdop);
              nmeaState.vdop = double.tryParse(vdop);
            }
            // --- GPVTG (Optional, another source for Course Over Ground) ---
          } else if (talkerId.endsWith('VTG')) {
            if (fields.length > 7) {
              // VTG often has speed in knots at index 7
              String? courseTrue = fields[1];
              String? speedKnots = fields[7];
              if (courseTrue.isNotEmpty) {
                nmeaState.heading ??= double.tryParse(courseTrue);
              }
              if (speedKnots.isNotEmpty) {
                nmeaState.speedKnots ??= double.tryParse(speedKnots); // Use VTG speed as fallback
              }
            }
          } else {
            // print('Unknown or unhandled NMEA $talkerId: $sentence');
          }
        } catch (e) {
          // Catch specific parsing errors
          print('Failed to parse NMEA sentence: $sentence');
          print('Error: $e');
          // print('Stack trace: $stackTrace'); // Uncomment for detailed debugging
        }
      }
    }
  } catch (e) {
    print('Error processing raw data: $e');
    return nmeaState; // Return current state even if there was a processing error
  }
  // print('return nmeaState: ${nmeaState.toString()}'); // More detailed print
  return nmeaState;
}

/// Get whether the current selected troop is a control troop
/// Returns null if no troop is selected or troop not found
/// Returns true if the troop has is_control_troop = 1
/// Returns false if the troop has is_control_troop = 0
Future<bool?> getCurrentIsControlTroop() async {
  try {
    final selectionService = OrganizationSelectionService();
    final troopId = await selectionService.getSelectedTroopId();

    if (troopId == null) {
      print('No troop selected, returning null for isControlTroop');
      return null;
    }

    final result = await db.get('SELECT is_control_troop FROM troop WHERE id = ?', [troopId]);
    final isControlTroop = (result['is_control_troop'] as int?) == 1;
    print('Troop $troopId is_control_troop: $isControlTroop');
    return isControlTroop;
  } catch (e) {
    print('Error getting isControlTroop: $e');
    return null;
  }
}
