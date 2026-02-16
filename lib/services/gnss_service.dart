import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service to access native GNSS (GPS) satellite data on Android
/// Provides satellite count, signal strengths, and other GNSS metrics
class GnssService {
  static const MethodChannel _channel = MethodChannel('com.thuenen.tfm/gnss');
  static const EventChannel _statusChannel = EventChannel('com.thuenen.tfm/gnss_status');

  Stream<GnssStatus>? _statusStream;
  StreamSubscription? _subscription;

  /// Get the current GNSS status stream
  /// Returns satellite count, used satellites, and individual satellite data
  Stream<GnssStatus> getGnssStatusStream() {
    _statusStream ??= _statusChannel.receiveBroadcastStream().map((dynamic event) {
      if (event is Map) {
        return GnssStatus.fromMap(Map<String, dynamic>.from(event));
      }
      return GnssStatus.empty();
    });
    return _statusStream!;
  }

  /// Start listening to GNSS satellite data
  Future<bool> startGnssListener() async {
    try {
      final result = await _channel.invokeMethod('startGnssListener');
      return result == true;
    } catch (e) {
      debugPrint('Error starting GNSS listener: $e');
      return false;
    }
  }

  /// Stop listening to GNSS satellite data
  Future<bool> stopGnssListener() async {
    try {
      final result = await _channel.invokeMethod('stopGnssListener');
      return result == true;
    } catch (e) {
      debugPrint('Error stopping GNSS listener: $e');
      return false;
    }
  }

  /// Check if GNSS is available on this device
  Future<bool> isGnssAvailable() async {
    try {
      final result = await _channel.invokeMethod('isGnssAvailable');
      return result == true;
    } catch (e) {
      debugPrint('Error checking GNSS availability: $e');
      return false;
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}

/// Represents the current GNSS status including satellite information
class GnssStatus {
  final int satelliteCount;
  final int usedInFix;
  final List<SatelliteInfo> satellites;
  final DateTime timestamp;

  GnssStatus({
    required this.satelliteCount,
    required this.usedInFix,
    required this.satellites,
    required this.timestamp,
  });

  factory GnssStatus.fromMap(Map<String, dynamic> map) {
    final satList = map['satellites'] as List<dynamic>? ?? [];
    return GnssStatus(
      satelliteCount: map['satelliteCount'] as int? ?? 0,
      usedInFix: map['usedInFix'] as int? ?? 0,
      satellites: satList.map((s) => SatelliteInfo.fromMap(Map<String, dynamic>.from(s))).toList(),
      timestamp: DateTime.now(),
    );
  }

  factory GnssStatus.empty() {
    return GnssStatus(satelliteCount: 0, usedInFix: 0, satellites: [], timestamp: DateTime.now());
  }

  /// Calculate approximate HDOP from satellite data
  /// This is a rough estimation based on satellite geometry
  double? estimateHdop() {
    if (usedInFix < 4) return null;

    // Simple HDOP estimation based on number of satellites
    // More satellites generally means lower (better) HDOP
    if (usedInFix >= 8) return 1.0;
    if (usedInFix >= 6) return 1.5;
    if (usedInFix >= 4) return 2.5;
    return 3.0;
  }

  /// Calculate approximate PDOP from HDOP estimate
  double? estimatePdop() {
    final hdop = estimateHdop();
    if (hdop == null) return null;
    // PDOP is typically 1.2-1.5x HDOP
    return hdop * 1.3;
  }

  @override
  String toString() {
    return 'GnssStatus(satellites: $satelliteCount, usedInFix: $usedInFix)';
  }
}

/// Information about a single satellite
class SatelliteInfo {
  final int svid; // Satellite ID
  final int constellationType; // GPS, GLONASS, Galileo, etc.
  final double cn0DbHz; // Carrier-to-noise density (signal strength)
  final double elevation; // Elevation angle in degrees
  final double azimuth; // Azimuth angle in degrees
  final bool usedInFix; // Whether this satellite is used in the position fix

  SatelliteInfo({
    required this.svid,
    required this.constellationType,
    required this.cn0DbHz,
    required this.elevation,
    required this.azimuth,
    required this.usedInFix,
  });

  factory SatelliteInfo.fromMap(Map<String, dynamic> map) {
    return SatelliteInfo(
      svid: map['svid'] as int? ?? 0,
      constellationType: map['constellationType'] as int? ?? 0,
      cn0DbHz: (map['cn0DbHz'] as num?)?.toDouble() ?? 0.0,
      elevation: (map['elevation'] as num?)?.toDouble() ?? 0.0,
      azimuth: (map['azimuth'] as num?)?.toDouble() ?? 0.0,
      usedInFix: map['usedInFix'] as bool? ?? false,
    );
  }

  String get constellationName {
    switch (constellationType) {
      case 1:
        return 'GPS';
      case 2:
        return 'SBAS';
      case 3:
        return 'GLONASS';
      case 4:
        return 'QZSS';
      case 5:
        return 'BEIDOU';
      case 6:
        return 'GALILEO';
      case 7:
        return 'IRNSS';
      default:
        return 'UNKNOWN';
    }
  }
}
