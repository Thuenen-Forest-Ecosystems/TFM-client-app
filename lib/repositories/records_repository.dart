import 'dart:convert';
import 'dart:math' as math;
import 'package:powersync/powersync.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/services/organization_selection_service.dart';

class Record {
  final String? id;
  final Map<String, dynamic> properties;
  final String schemaName;
  final String schemaId;
  final String plotId;
  final String clusterId;
  final String plotName;
  final String clusterName;
  final Map<String, dynamic>? previousProperties;
  final int? isValid;
  final String? responsibleAdministration;
  final String? responsibleProvider;
  final String? responsibleState;
  final String? responsibleTroop;

  Record({
    this.id,
    required this.properties,
    required this.schemaName,
    required this.schemaId,
    required this.plotId,
    required this.clusterId,
    required this.plotName,
    required this.clusterName,
    this.previousProperties,
    this.isValid,
    this.responsibleAdministration,
    this.responsibleProvider,
    this.responsibleState,
    this.responsibleTroop,
  });

  factory Record.fromRow(Map<String, dynamic> row) {
    return Record(
      id: row['id'] as String?,
      properties: jsonDecode(row['properties'] as String) as Map<String, dynamic>,
      schemaName: row['schema_name'] as String,
      schemaId: row['schema_id'] as String,
      plotId: row['plot_id'] as String,
      clusterId: row['cluster_id'] as String,
      plotName: row['plot_name'] as String,
      clusterName: row['cluster_name'] as String,
      previousProperties: row['previous_properties'] != null ? jsonDecode(row['previous_properties'] as String) as Map<String, dynamic> : null,
      isValid: row['is_valid'] as int?,
      responsibleAdministration: row['responsible_administration'] as String?,
      responsibleProvider: row['responsible_provider'] as String?,
      responsibleState: row['responsible_state'] as String?,
      responsibleTroop: row['responsible_troop'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'properties': jsonEncode(properties),
      'schema_name': schemaName,
      'schema_id': schemaId,
      'plot_id': plotId,
      'cluster_id': clusterId,
      'plot_name': plotName,
      'cluster_name': clusterName,
      'previous_properties': previousProperties != null ? jsonEncode(previousProperties) : null,
      'is_valid': isValid,
      'responsible_administration': responsibleAdministration,
      'responsible_provider': responsibleProvider,
      'responsible_state': responsibleState,
      'responsible_troop': responsibleTroop,
    };
  }

  /// Extracts coordinates from previous_properties.plot_coordinates.center_location
  /// Returns a Map with 'latitude' and 'longitude' keys, or null if not available
  Map<String, double>? getCoordinates() {
    if (previousProperties == null) {
      return null;
    }

    try {
      final plotCoordinates = previousProperties!['plot_coordinates'];
      if (plotCoordinates == null) {
        return null;
      }

      final centerLocation = plotCoordinates['center_location'];
      if (centerLocation == null) {
        return null;
      }

      // Handle different possible formats (object with lat/lng or array)
      if (centerLocation is Map) {
        // Check for GeoJSON Point format
        if (centerLocation['type'] == 'Point' && centerLocation['coordinates'] is List) {
          final coords = centerLocation['coordinates'] as List;
          if (coords.length >= 2) {
            final lng = _extractDouble(coords[0]);
            final lat = _extractDouble(coords[1]);
            if (lat != null && lng != null) {
              return {'latitude': lat, 'longitude': lng};
            }
          }
        } else {
          // Fallback: direct lat/lng keys
          final lat = _extractDouble(centerLocation['latitude'] ?? centerLocation['lat']);
          final lng = _extractDouble(centerLocation['longitude'] ?? centerLocation['lng'] ?? centerLocation['lon']);

          if (lat != null && lng != null) {
            return {'latitude': lat, 'longitude': lng};
          }
        }
      } else if (centerLocation is List && centerLocation.length >= 2) {
        // Handle array format [lng, lat] or [lat, lng]
        final first = _extractDouble(centerLocation[0]);
        final second = _extractDouble(centerLocation[1]);

        if (first != null && second != null) {
          // Assume [longitude, latitude] (GeoJSON format)
          return {'latitude': second, 'longitude': first};
        }
      }
    } catch (e, stackTrace) {
      print('Error extracting coordinates: $e');
      print('Stack trace: $stackTrace');
    }

    return null;
  }

  /// Helper method to safely extract a double value
  double? _extractDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Convenience getters for latitude and longitude
  double? get latitude => getCoordinates()?['latitude'];
  double? get longitude => getCoordinates()?['longitude'];
}

class RecordsRepository {
  /// Get WHERE clause for filtering by selected organization
  /// Returns SQL condition that checks if record belongs to the selected organization
  Future<String> _getOrganizationFilter() async {
    final orgId = await OrganizationSelectionService().getSelectedOrganizationId();
    if (orgId == null || orgId.isEmpty) {
      return '1=1'; // No filter if no organization selected
    }
    return "(responsible_administration = '$orgId' OR responsible_provider = '$orgId' OR responsible_state = '$orgId')";
  }

  Future<List<Record>> getRecordsByCluster(String clusterId) async {
    final orgFilter = await _getOrganizationFilter();
    final results = await db.execute('SELECT * FROM records WHERE cluster_id = ? AND $orgFilter', [clusterId]);
    return results.map((row) => Record.fromRow(row)).toList();
  }

  Future<List<Record>> getRecordsByPlot(String plotId) async {
    final orgFilter = await _getOrganizationFilter();
    final results = await db.execute('SELECT * FROM records WHERE plot_id = ? AND $orgFilter', [plotId]);
    return results.map((row) => Record.fromRow(row)).toList();
  }

  Stream<List<Record>> watchRecordsByCluster(String clusterId) async* {
    final orgFilter = await _getOrganizationFilter();
    yield* db.watch('SELECT * FROM records WHERE cluster_id = ? AND $orgFilter', parameters: [clusterId]).map((results) => results.map((row) => Record.fromRow(row)).toList());
  }

  Stream<List<Record>> watchRecordsByPlot(String plotId) async* {
    final orgFilter = await _getOrganizationFilter();
    yield* db.watch('SELECT * FROM records WHERE plot_id = ? AND $orgFilter', parameters: [plotId]).map((results) => results.map((row) => Record.fromRow(row)).toList());
  }

  Future<List<Record>> getRecordsByClusterAndPlot(String clusterName, String plotName) async {
    final orgFilter = await _getOrganizationFilter();
    final results = await db.execute('SELECT * FROM records WHERE cluster_name = ? AND plot_name = ? AND $orgFilter', [clusterName, plotName]);
    return results.map((row) => Record.fromRow(row)).toList();
  }

  Future<List<Record>> getAllRecords() async {
    final orgFilter = await _getOrganizationFilter();
    final results = await db.execute('SELECT * FROM records WHERE $orgFilter');
    return results.map((row) => Record.fromRow(row)).toList();
  }

  // group by cluster_name
  Future<List<Record>> getRecordsGroupedByCluster({String orderBy = 'cluster_name', int offset = 0, int limit = 100}) async {
    final orgFilter = await _getOrganizationFilter();
    final results = await db.execute('SELECT * FROM records WHERE $orgFilter GROUP BY cluster_name ORDER BY $orderBy LIMIT ? OFFSET ?', [limit, offset]);
    return results.map((row) => Record.fromRow(row)).toList();
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) + math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }

  /// Get records grouped by cluster, ordered by distance from a point
  /// Calculates distance in Dart for accuracy
  Future<List<Record>> getRecordsGroupedByClusterOrderedByDistance({required double latitude, required double longitude, int? limit}) async {
    final orgFilter = await _getOrganizationFilter();
    // Get all records grouped by cluster
    final results = await db.execute('''
      SELECT *
      FROM records
      WHERE previous_properties IS NOT NULL
        AND json_extract(previous_properties, '\$.plot_coordinates.center_location.coordinates[0]') IS NOT NULL
        AND json_extract(previous_properties, '\$.plot_coordinates.center_location.coordinates[1]') IS NOT NULL
        AND $orgFilter
      GROUP BY cluster_name
    ''');

    final records = results.map((row) => Record.fromRow(row)).toList();

    // Calculate distances and sort
    records.sort((a, b) {
      final coordsA = a.getCoordinates();
      final coordsB = b.getCoordinates();

      if (coordsA == null) return 1;
      if (coordsB == null) return -1;

      final distA = _calculateDistance(latitude, longitude, coordsA['latitude']!, coordsA['longitude']!);
      final distB = _calculateDistance(latitude, longitude, coordsB['latitude']!, coordsB['longitude']!);

      return distA.compareTo(distB);
    });

    return limit != null ? records.take(limit).toList() : records;
  }

  Stream<List<Record>> watchAllRecords() async* {
    final orgFilter = await _getOrganizationFilter();
    yield* db.watch('SELECT * FROM records WHERE $orgFilter').map((results) => results.map((row) => Record.fromRow(row)).toList());
  }

  Future<String> insertRecord(Record record) async {
    await db.execute(
      'INSERT INTO records (properties, schema_name, schema_id, plot_id, cluster_id, plot_name, cluster_name, previous_properties, is_valid, responsible_administration, responsible_provider, responsible_state, responsible_troop) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        record.properties,
        record.schemaName,
        record.schemaId,
        record.plotId,
        record.clusterId,
        record.plotName,
        record.clusterName,
        record.previousProperties,
        record.isValid,
        record.responsibleAdministration,
        record.responsibleProvider,
        record.responsibleState,
        record.responsibleTroop,
      ],
    );
    final idResult = await db.execute('SELECT last_insert_rowid() as id');
    return idResult.first['id'] as String;
  }

  Future<void> updateRecord(String id, Record record) async {
    final map = record.toMap();
    map['id'] = id;
    await db.execute('UPDATE records SET ${map.keys.map((key) => '$key = ?').join(', ')} WHERE id = ?', [...map.values, id]);
  }

  Future<void> deleteRecord(String id) async {
    await db.execute('DELETE FROM records WHERE id = ?', [id]);
  }

  Future<Record?> getRecordById(String id) async {
    final results = await db.execute('SELECT * FROM records WHERE id = ?', [id]);
    if (results.isNotEmpty) {
      return Record.fromRow(results.first);
    }
    return null;
  }

  Future<List<Record>> getLimitedRecords(int limit) async {
    final orgFilter = await _getOrganizationFilter();
    final results = await db.execute('SELECT * FROM records WHERE $orgFilter LIMIT ?', [limit]);
    return results.map((row) => Record.fromRow(row)).toList();
  }

  /// Get records within a certain distance (in kilometers) from a point
  /// Calculates distance in Dart for accuracy
  Future<List<Record>> getRecordsByDistance({required double latitude, required double longitude, required double radiusKm, int? limit}) async {
    final orgFilter = await _getOrganizationFilter();
    // Get all records with coordinates
    final results = await db.execute('''
      SELECT *
      FROM records
      WHERE previous_properties IS NOT NULL
        AND json_extract(previous_properties, '\$.plot_coordinates.center_location.coordinates[0]') IS NOT NULL
        AND json_extract(previous_properties, '\$.plot_coordinates.center_location.coordinates[1]') IS NOT NULL
        AND $orgFilter
    ''');

    final records = results.map((row) => Record.fromRow(row)).toList();

    // Filter by distance and sort
    final recordsWithDistance =
        records
            .map((record) {
              final coords = record.getCoordinates();
              if (coords == null) return null;

              final distance = _calculateDistance(latitude, longitude, coords['latitude']!, coords['longitude']!);

              return {'record': record, 'distance': distance};
            })
            .where((item) => item != null && (item['distance'] as double) <= radiusKm)
            .toList()
          ..sort((a, b) => (a!['distance'] as double).compareTo(b!['distance'] as double));

    final filteredRecords = recordsWithDistance.map((item) => item!['record'] as Record).toList();

    return limit != null ? filteredRecords.take(limit).toList() : filteredRecords;
  }

  /// Get records within a bounding box (more efficient than distance for large areas)
  Future<List<Record>> getRecordsInBounds({required double northLat, required double southLat, required double eastLng, required double westLng, int? limit}) async {
    final orgFilter = await _getOrganizationFilter();
    final query = '''
      SELECT *
      FROM records
      WHERE previous_properties IS NOT NULL
        AND CAST(json_extract(previous_properties, '\$.plot_coordinates.center_location.coordinates[1]') AS REAL) BETWEEN ? AND ?
        AND CAST(json_extract(previous_properties, '\$.plot_coordinates.center_location.coordinates[0]') AS REAL) BETWEEN ? AND ?
        AND $orgFilter
      ${limit != null ? 'LIMIT ?' : ''}
    ''';

    final params = limit != null ? [southLat, northLat, westLng, eastLng, limit] : [southLat, northLat, westLng, eastLng];

    final results = await db.execute(query, params);
    return results.map((row) => Record.fromRow(row)).toList();
  }
}
