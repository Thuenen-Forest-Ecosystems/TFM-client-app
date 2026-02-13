import 'dart:convert';

/**
 * GPS Quality Criteria Configuration
 * Defines thresholds for determining GPS measurement quality
 * Can be loaded from JSON for admin configuration
 */

enum QualityLevel { good, ok, notAcceptable }

class GpsQualityCriteria {
  final String name;
  final HdopCriteria hdop;
  final PdopCriteria pdop;
  final SatellitesCriteria satellites;
  final MeasurementCountCriteria measurementCount;

  GpsQualityCriteria({
    required this.name,
    required this.hdop,
    required this.pdop,
    required this.satellites,
    required this.measurementCount,
  });

  /// Default criteria for forestry applications
  static GpsQualityCriteria get defaultCriteria => GpsQualityCriteria(
    name: 'Default Forestry Criteria',
    hdop: HdopCriteria(good: 3.0, ok: 8.0, notAcceptable: 10.0),
    pdop: PdopCriteria(good: 3.0, ok: 8.0, notAcceptable: 10.0),
    satellites: SatellitesCriteria(good: 9, ok: 6, notAcceptable: 4),
    measurementCount: MeasurementCountCriteria(good: 100, ok: 60, notAcceptable: 60),
  );

  /// Evaluate correction signal availability (Korrektursignal)
  /// Returns good if DGPS/RTK correction is available, ok if standard GPS, notAcceptable otherwise
  static QualityLevel evaluateCorrectionSignal(dynamic fixQuality) {
    int? quality;
    if (fixQuality is int) {
      quality = fixQuality;
    } else if (fixQuality is String) {
      quality = int.tryParse(fixQuality);
    }

    // Only accept valid NMEA fix quality codes
    // 1 = GPS (standard fix, no correction)
    // 2 = DGPS (differential correction)
    // 4 = RTK Fixed
    // 5 = RTK Float
    const validQualities = {1, 2, 4, 5};

    if (quality == null || !validQualities.contains(quality)) {
      return QualityLevel.notAcceptable; // Invalid or no fix
    }

    if (quality == 2 || quality == 4 || quality == 5) {
      return QualityLevel.good; // Correction signal available
    }

    return QualityLevel.ok; // Standard GPS (quality = 1), no correction
  }

  /// Evaluate overall quality based on current GPS metrics
  /// Returns the worst quality level found across all parameters
  QualityLevel evaluateQuality({
    double? hdopValue,
    double? pdopValue,
    int? satellitesValue,
    int? measurementCountValue,
  }) {
    final levels = <QualityLevel>[];

    if (hdopValue != null) {
      levels.add(hdop.evaluate(hdopValue));
    }
    if (pdopValue != null) {
      levels.add(pdop.evaluate(pdopValue));
    }
    if (satellitesValue != null) {
      levels.add(satellites.evaluate(satellitesValue));
    }
    if (measurementCountValue != null) {
      levels.add(measurementCount.evaluate(measurementCountValue));
    }

    // If no values, return not acceptable
    if (levels.isEmpty) return QualityLevel.notAcceptable;

    // Return worst quality found
    if (levels.contains(QualityLevel.notAcceptable)) {
      return QualityLevel.notAcceptable;
    }
    if (levels.contains(QualityLevel.ok)) {
      return QualityLevel.ok;
    }
    return QualityLevel.good;
  }

  /// Get detailed quality assessment for each parameter
  Map<String, QualityLevel> evaluateDetailed({
    double? hdopValue,
    double? pdopValue,
    int? satellitesValue,
    int? measurementCountValue,
  }) {
    return {
      if (hdopValue != null) 'hdop': hdop.evaluate(hdopValue),
      if (pdopValue != null) 'pdop': pdop.evaluate(pdopValue),
      if (satellitesValue != null) 'satellites': satellites.evaluate(satellitesValue),
      if (measurementCountValue != null)
        'measurementCount': measurementCount.evaluate(measurementCountValue),
    };
  }

  // JSON serialization
  Map<String, dynamic> toJson() => {
    'name': name,
    'hdop': hdop.toJson(),
    'pdop': pdop.toJson(),
    'satellites': satellites.toJson(),
    'measurementCount': measurementCount.toJson(),
  };

  factory GpsQualityCriteria.fromJson(Map<String, dynamic> json) {
    return GpsQualityCriteria(
      name: json['name'] ?? 'Custom Criteria',
      hdop: HdopCriteria.fromJson(json['hdop']),
      pdop: PdopCriteria.fromJson(json['pdop']),
      satellites: SatellitesCriteria.fromJson(json['satellites']),
      measurementCount: MeasurementCountCriteria.fromJson(json['measurementCount']),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory GpsQualityCriteria.fromJsonString(String jsonString) {
    return GpsQualityCriteria.fromJson(jsonDecode(jsonString));
  }
}

/// HDOP Criteria (lower values are better)
class HdopCriteria {
  final double good; // Values <= good are excellent
  final double ok; // Values <= ok are acceptable
  final double notAcceptable; // Values > notAcceptable are not acceptable

  HdopCriteria({required this.good, required this.ok, required this.notAcceptable});

  QualityLevel evaluate(double value) {
    if (value <= good) return QualityLevel.good;
    if (value <= ok) return QualityLevel.ok;
    return QualityLevel.notAcceptable;
  }

  Map<String, dynamic> toJson() => {'good': good, 'ok': ok, 'notAcceptable': notAcceptable};

  factory HdopCriteria.fromJson(Map<String, dynamic> json) {
    return HdopCriteria(
      good: (json['good'] as num).toDouble(),
      ok: (json['ok'] as num).toDouble(),
      notAcceptable: (json['notAcceptable'] as num).toDouble(),
    );
  }
}

/// PDOP Criteria (lower values are better)
class PdopCriteria {
  final double good;
  final double ok;
  final double notAcceptable;

  PdopCriteria({required this.good, required this.ok, required this.notAcceptable});

  QualityLevel evaluate(double value) {
    if (value <= good) return QualityLevel.good;
    if (value <= ok) return QualityLevel.ok;
    return QualityLevel.notAcceptable;
  }

  Map<String, dynamic> toJson() => {'good': good, 'ok': ok, 'notAcceptable': notAcceptable};

  factory PdopCriteria.fromJson(Map<String, dynamic> json) {
    return PdopCriteria(
      good: (json['good'] as num).toDouble(),
      ok: (json['ok'] as num).toDouble(),
      notAcceptable: (json['notAcceptable'] as num).toDouble(),
    );
  }
}

/// Satellites Criteria (higher values are better)
class SatellitesCriteria {
  final int good; // Values >= good are excellent
  final int ok; // Values >= ok are acceptable
  final int notAcceptable; // Values < notAcceptable are not acceptable

  SatellitesCriteria({required this.good, required this.ok, required this.notAcceptable});

  QualityLevel evaluate(int value) {
    if (value >= good) return QualityLevel.good;
    if (value >= ok) return QualityLevel.ok;
    return QualityLevel.notAcceptable;
  }

  Map<String, dynamic> toJson() => {'good': good, 'ok': ok, 'notAcceptable': notAcceptable};

  factory SatellitesCriteria.fromJson(Map<String, dynamic> json) {
    return SatellitesCriteria(
      good: json['good'] as int,
      ok: json['ok'] as int,
      notAcceptable: json['notAcceptable'] as int,
    );
  }
}

/// Measurement Count Criteria (higher values are better)
class MeasurementCountCriteria {
  final int good; // Values >= good are excellent
  final int ok; // Values >= ok are acceptable
  final int notAcceptable; // Values < notAcceptable are not acceptable

  MeasurementCountCriteria({required this.good, required this.ok, required this.notAcceptable});

  QualityLevel evaluate(int value) {
    if (value >= good) return QualityLevel.good;
    if (value >= ok) return QualityLevel.ok;
    return QualityLevel.notAcceptable;
  }

  Map<String, dynamic> toJson() => {'good': good, 'ok': ok, 'notAcceptable': notAcceptable};

  factory MeasurementCountCriteria.fromJson(Map<String, dynamic> json) {
    return MeasurementCountCriteria(
      good: json['good'] as int,
      ok: json['ok'] as int,
      notAcceptable: json['notAcceptable'] as int,
    );
  }
}
