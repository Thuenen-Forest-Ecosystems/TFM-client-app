import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/services/organization_selection_service.dart';

class Record {
  final String? id;
  final Map<String, dynamic> properties;
  final String schemaName;
  final String schemaId;
  final String? schemaIdValidatedBy;
  final int? schemaVersion;
  final String plotId;
  final String clusterId;
  final String plotName;
  final String clusterName;
  final Map<String, dynamic>? previousProperties;
  final Map<String, dynamic>? previousPositionData;
  final int? isValid;
  final String? responsibleAdministration;
  final String? responsibleProvider;
  final String? responsibleState;
  final String? responsibleTroop;
  final String? updatedAt;
  final String? localUpdatedAt;
  final String? completedAtState;
  final String? completedAtTroop;
  final String? completedAtAdministration;
  final int? isToBeRecorded;
  final String? note;
  final String? validationErrors;
  final String? plausibilityErrors;
  final String? cluster;
  final int? isTraining;

  Record({
    this.id,
    required this.properties,
    required this.schemaName,
    required this.schemaId,
    this.schemaIdValidatedBy,
    this.schemaVersion,
    required this.plotId,
    required this.clusterId,
    required this.plotName,
    required this.clusterName,
    this.previousProperties,
    this.previousPositionData,
    this.isValid,
    this.responsibleAdministration,
    this.responsibleProvider,
    this.responsibleState,
    this.responsibleTroop,
    this.updatedAt,
    this.localUpdatedAt,
    this.completedAtState,
    this.completedAtTroop,
    this.completedAtAdministration,
    this.isToBeRecorded,
    this.note,
    this.validationErrors,
    this.plausibilityErrors,
    this.cluster,
    this.isTraining,
  });

  factory Record.fromRow(Map<String, dynamic> row) {
    return Record(
      id: row['id'] as String?,
      properties: jsonDecode(row['properties'] as String) as Map<String, dynamic>,
      schemaName: row['schema_name'] as String,
      schemaId: row['schema_id'] as String,
      schemaIdValidatedBy: row['schema_id_validated_by'] as String?,
      schemaVersion: row['schema_version'] as int?,
      plotId: row['plot_id'] as String,
      clusterId: row['cluster_id'] as String,
      plotName: row['plot_name'] as String,
      clusterName: row['cluster_name'] as String,
      previousProperties: row['previous_properties'] != null
          ? jsonDecode(row['previous_properties'] as String) as Map<String, dynamic>
          : null,
      previousPositionData: row['previous_position_data'] != null
          ? jsonDecode(row['previous_position_data'] as String) as Map<String, dynamic>
          : null,
      isValid: row['is_valid'] as int?,
      responsibleAdministration: row['responsible_administration'] as String?,
      responsibleProvider: row['responsible_provider'] as String?,
      responsibleState: row['responsible_state'] as String?,
      responsibleTroop: row['responsible_troop'] as String?,
      updatedAt: row['updated_at'] as String?,
      localUpdatedAt: row['local_updated_at'] as String?,
      completedAtState: row['completed_at_state'] as String?,
      completedAtTroop: row['completed_at_troop'] as String?,
      completedAtAdministration: row['completed_at_administration'] as String?,
      isToBeRecorded: row['is_to_be_recorded'] as int?,
      note: row['note'] as String?,
      validationErrors: row['validation_errors'] as String?,
      plausibilityErrors: row['plausibility_errors'] as String?,
      cluster: row['cluster'] as String?,
      isTraining: row['is_training'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'properties': jsonEncode(properties),
      'schema_name': schemaName,
      'schema_id': schemaId,
      'schema_id_validated_by': schemaIdValidatedBy,
      'plot_id': plotId,
      'cluster_id': clusterId,
      'plot_name': plotName,
      'cluster_name': clusterName,
      'previous_properties': previousProperties != null ? jsonEncode(previousProperties) : null,
      'previous_position_data': previousPositionData != null
          ? jsonEncode(previousPositionData)
          : null,
      'is_valid': isValid,
      'responsible_administration': responsibleAdministration,
      'responsible_provider': responsibleProvider,
      'responsible_state': responsibleState,
      'responsible_troop': responsibleTroop,
      'updated_at': updatedAt,
      'local_updated_at': localUpdatedAt,
      'completed_at_state': completedAtState,
      'completed_at_troop': completedAtTroop,
      'completed_at_administration': completedAtAdministration,
      'is_to_be_recorded': isToBeRecorded,
      'note': note,
      'validation_errors': validationErrors,
      'plausibility_errors': plausibilityErrors,
      'cluster': cluster,
      'is_training': isTraining,
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
          final lng = _extractDouble(
            centerLocation['longitude'] ?? centerLocation['lng'] ?? centerLocation['lon'],
          );

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

  /// Extracts cluster data from properties or direct cluster field
  /// Returns the cluster Map, or null if not available
  Map<String, dynamic>? getCluster() {
    try {
      // First check the direct cluster field from the database
      if (cluster != null && cluster!.isNotEmpty) {
        try {
          final parsed = jsonDecode(cluster!);
          if (parsed is Map<String, dynamic>) {
            return parsed;
          } else if (parsed is Map) {
            return Map<String, dynamic>.from(parsed);
          }
        } catch (e) {
          debugPrint('Error parsing cluster field JSON: $e');
        }
      }

      // Fallback: check properties['cluster']
      final clusterFromProperties = properties['cluster'];

      if (clusterFromProperties == null) {
        return null;
      }

      // Handle different possible formats
      if (clusterFromProperties is Map<String, dynamic>) {
        return clusterFromProperties;
      } else if (clusterFromProperties is Map) {
        return Map<String, dynamic>.from(clusterFromProperties);
      } else if (clusterFromProperties is String) {
        // Try to parse JSON string
        try {
          final parsed = jsonDecode(clusterFromProperties);
          if (parsed is Map) {
            return Map<String, dynamic>.from(parsed);
          }
        } catch (e) {
          debugPrint('Error parsing cluster JSON string from properties: $e');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error extracting cluster data: $e');
      debugPrint('Stack trace: $stackTrace');
    }

    return null;
  }

  /// Creates a copy of this Record with the specified fields replaced with new values.
  Record copyWith({
    String? id,
    Map<String, dynamic>? properties,
    String? schemaName,
    String? schemaId,
    String? schemaIdValidatedBy,
    int? schemaVersion,
    String? plotId,
    String? clusterId,
    String? plotName,
    String? clusterName,
    Map<String, dynamic>? previousProperties,
    Map<String, dynamic>? previousPositionData,
    int? isValid,
    String? responsibleAdministration,
    String? responsibleProvider,
    String? responsibleState,
    String? responsibleTroop,
    String? updatedAt,
    String? localUpdatedAt,
    String? completedAtState,
    String? completedAtTroop,
    String? completedAtAdministration,
    int? isToBeRecorded,
    String? note,
    String? validationErrors,
    String? plausibilityErrors,
    String? cluster,
    int? isTraining,
  }) {
    return Record(
      id: id ?? this.id,
      properties: properties ?? this.properties,
      schemaName: schemaName ?? this.schemaName,
      schemaId: schemaId ?? this.schemaId,
      schemaIdValidatedBy: schemaIdValidatedBy ?? this.schemaIdValidatedBy,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      plotId: plotId ?? this.plotId,
      clusterId: clusterId ?? this.clusterId,
      plotName: plotName ?? this.plotName,
      clusterName: clusterName ?? this.clusterName,
      previousProperties: previousProperties ?? this.previousProperties,
      previousPositionData: previousPositionData ?? this.previousPositionData,
      isValid: isValid ?? this.isValid,
      responsibleAdministration: responsibleAdministration ?? this.responsibleAdministration,
      responsibleProvider: responsibleProvider ?? this.responsibleProvider,
      responsibleState: responsibleState ?? this.responsibleState,
      responsibleTroop: responsibleTroop ?? this.responsibleTroop,
      updatedAt: updatedAt ?? this.updatedAt,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      completedAtState: completedAtState ?? this.completedAtState,
      completedAtTroop: completedAtTroop ?? this.completedAtTroop,
      completedAtAdministration: completedAtAdministration ?? this.completedAtAdministration,
      isToBeRecorded: isToBeRecorded ?? this.isToBeRecorded,
      note: note ?? this.note,
      validationErrors: validationErrors ?? this.validationErrors,
      plausibilityErrors: plausibilityErrors ?? this.plausibilityErrors,
      cluster: cluster ?? this.cluster,
      isTraining: isTraining ?? this.isTraining,
    );
  }
}

class RecordsRepository {
  /// Get WHERE clause for filtering by selected organization and permission
  /// Returns SQL condition that checks if record belongs to the selected organization
  /// and respects user's permission level (admin vs troop member)
  Future<String> _getOrganizationFilter() async {
    final selectionService = OrganizationSelectionService();
    final orgId = await selectionService.getSelectedOrganizationId();
    final isAdmin = await selectionService.getIsOrganizationAdmin();
    final troopId = await selectionService.getSelectedTroopId();

    if (orgId == null || orgId.isEmpty) {
      return '1=1'; // No filter if no organization selected
    }

    // Base organization filter
    final orgFilter =
        "(responsible_administration = '$orgId' OR responsible_provider = '$orgId' OR responsible_state = '$orgId')";

    // If user is organization admin, show all records for the organization
    if (isAdmin) {
      return orgFilter;
    }

    // If user is troop member, only show records assigned to their troop
    if (troopId != null && troopId.isNotEmpty) {
      return "$orgFilter AND responsible_troop = '$troopId'";
    }

    // If no troop assigned, show no records (user has permission but no troop membership)
    return '1=0';
  }

  Future<List<Record>> getRecordsByCluster(String clusterId) async {
    final orgFilter = await _getOrganizationFilter();
    final results = await db.execute('SELECT * FROM records WHERE cluster_id = ? AND $orgFilter', [
      clusterId,
    ]);
    return results.map((row) => Record.fromRow(row)).toList();
  }

  Future<List<Record>> getRecordsByPlot(String plotId) async {
    final orgFilter = await _getOrganizationFilter();
    final results = await db.execute('SELECT * FROM records WHERE plot_id = ? AND $orgFilter', [
      plotId,
    ]);
    return results.map((row) => Record.fromRow(row)).toList();
  }

  Stream<List<Record>> watchRecordsByCluster(String clusterId) async* {
    final orgFilter = await _getOrganizationFilter();
    yield* db
        .watch('SELECT * FROM records WHERE cluster_id = ? AND $orgFilter', parameters: [clusterId])
        .map((results) => results.map((row) => Record.fromRow(row)).toList());
  }

  Stream<List<Record>> watchRecordsByPlot(String plotId) async* {
    final orgFilter = await _getOrganizationFilter();
    yield* db
        .watch('SELECT * FROM records WHERE plot_id = ? AND $orgFilter', parameters: [plotId])
        .map((results) => results.map((row) => Record.fromRow(row)).toList());
  }

  Future<List<Record>> getRecordsByClusterAndPlot(String clusterName, String plotName) async {
    final orgFilter = await _getOrganizationFilter();
    final results = await db.execute(
      '''SELECT r.*, s.version as schema_version 
         FROM records r 
         LEFT JOIN schemas s ON r.schema_id_validated_by = s.id 
         WHERE r.cluster_name = ? AND r.plot_name = ? AND $orgFilter''',
      [clusterName, plotName],
    );
    return results.map((row) => Record.fromRow(row)).toList();
  }

  /// Get all records that share the same cluster_name as the given record
  Future<List<Record>> getRecordsByClusterName(String clusterName) async {
    final orgFilter = await _getOrganizationFilter();
    final results = await db.execute(
      'SELECT * FROM records WHERE cluster_name = ? AND $orgFilter ORDER BY plot_name',
      [clusterName],
    );
    return results.map((row) => Record.fromRow(row)).toList();
  }

  /// Test database connectivity with a simple COUNT query
  Future<int> testSimpleQuery() async {
    try {
      debugPrint('RecordsRepository.testSimpleQuery: Running COUNT(*)...');
      final results = await db
          .execute('SELECT COUNT(*) as count FROM records')
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('RecordsRepository.testSimpleQuery: Query timed out');
              throw TimeoutException('COUNT query timed out');
            },
          );
      final count = results.first['count'] as int;
      debugPrint('RecordsRepository.testSimpleQuery: Total records in DB: $count');
      return count;
    } catch (e) {
      debugPrint('RecordsRepository.testSimpleQuery: Error: $e');
      return -1;
    }
  }

  Future<List<Record>> getAllRecords() async {
    try {
      final orgFilter = await _getOrganizationFilter().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint(
            'RecordsRepository.getAllRecords: _getOrganizationFilter timed out, using 1=1',
          );
          return '1=1';
        },
      );

      final results = await db
          .execute('SELECT * FROM records WHERE $orgFilter')
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              debugPrint('RecordsRepository.getAllRecords: Query timed out after 60 seconds');
              throw TimeoutException('Database query timed out');
            },
          );

      return results.map((row) => Record.fromRow(row)).toList();
    } catch (e, stackTrace) {
      debugPrint('RecordsRepository.getAllRecords: Error: $e');
      debugPrint('RecordsRepository.getAllRecords: Stack trace: $stackTrace');
      return [];
    }
  }

  // Get only records that have valid coordinates for map display
  Future<List<Record>> getRecordsWithCoordinates() async {
    try {
      debugPrint('RecordsRepository.getRecordsWithCoordinates: Getting organization filter...');
      final orgFilter = await _getOrganizationFilter().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint(
            'RecordsRepository.getRecordsWithCoordinates: _getOrganizationFilter timed out, using 1=1',
          );
          return '1=1';
        },
      );

      final results = await db
          .execute('''
        SELECT * FROM records 
        WHERE $orgFilter
          AND previous_properties IS NOT NULL
          AND json_extract(previous_properties, '\$.plot_coordinates.center_location.coordinates[0]') IS NOT NULL
          AND json_extract(previous_properties, '\$.plot_coordinates.center_location.coordinates[1]') IS NOT NULL
      ''')
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              debugPrint('RecordsRepository.getRecordsWithCoordinates: Query timed out');
              throw TimeoutException('Database query timed out');
            },
          );

      debugPrint(
        'RecordsRepository.getRecordsWithCoordinates: Found ${results.length} records with coordinates',
      );
      return results.map((row) => Record.fromRow(row)).toList();
    } catch (e, stackTrace) {
      debugPrint('RecordsRepository.getRecordsWithCoordinates: Error: $e');
      debugPrint('RecordsRepository.getRecordsWithCoordinates: Stack trace: $stackTrace');
      return [];
    }
  }

  // group by cluster_name
  Future<List<Record>> getRecords({int offset = 0, int limit = 100}) async {
    final orgFilter = await _getOrganizationFilter();
    final results = await db.execute('SELECT * FROM records WHERE $orgFilter LIMIT ? OFFSET ?', [
      limit,
      offset,
    ]);
    return results.map((row) => Record.fromRow(row)).toList();
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }

  /// Get records grouped by cluster, ordered by distance from a point
  /// Calculates distance in Dart for accuracy
  Future<List<Record>> getRecordsOrderedByDistance({
    required double latitude,
    required double longitude,
    int? limit,
  }) async {
    final orgFilter = await _getOrganizationFilter();
    // Get all records grouped by cluster
    final results = await db.execute('''
      SELECT *
      FROM records
      WHERE previous_properties IS NOT NULL
        AND json_extract(previous_properties, '\$.plot_coordinates.center_location.coordinates[0]') IS NOT NULL
        AND json_extract(previous_properties, '\$.plot_coordinates.center_location.coordinates[1]') IS NOT NULL
        AND $orgFilter
    ''');

    final records = results.map((row) => Record.fromRow(row)).toList();

    // Calculate distances and sort
    records.sort((a, b) {
      final coordsA = a.getCoordinates();
      final coordsB = b.getCoordinates();

      if (coordsA == null) return 1;
      if (coordsB == null) return -1;

      final distA = _calculateDistance(
        latitude,
        longitude,
        coordsA['latitude']!,
        coordsA['longitude']!,
      );
      final distB = _calculateDistance(
        latitude,
        longitude,
        coordsB['latitude']!,
        coordsB['longitude']!,
      );

      return distA.compareTo(distB);
    });

    return limit != null ? records.take(limit).toList() : records;
  }

  Stream<List<Record>> watchAllRecords() {
    debugPrint('RecordsRepository.watchAllRecords: Setting up stream...');

    // Return a stream that waits for the filter then starts watching
    return Stream.fromFuture(_getOrganizationFilter()).asyncExpand((orgFilter) {
      debugPrint('RecordsRepository.watchAllRecords: Filter ready, starting db.watch()');
      return db.watch('SELECT * FROM records WHERE $orgFilter').map((results) {
        debugPrint('RecordsRepository.watchAllRecords: db.watch emitted ${results.length} results');
        return results.map((row) => Record.fromRow(row)).toList();
      });
    });
  }

  Future<String> insertRecord(Record record) async {
    // Generate id if not provided (PowerSync requires explicit TEXT id)
    final recordId = record.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    await db.execute(
      'INSERT INTO records (id, properties, schema_name, schema_id, schema_id_validated_by, plot_id, cluster_id, plot_name, cluster_name, previous_properties, is_valid, responsible_administration, responsible_provider, responsible_state, responsible_troop, updated_at, local_updated_at, completed_at_state, completed_at_troop, completed_at_administration, is_to_be_recorded, note, validation_errors, plausibility_errors, is_training) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        recordId,
        jsonEncode(record.properties),
        record.schemaName,
        record.schemaId,
        record.schemaIdValidatedBy,
        record.plotId,
        record.clusterId,
        record.plotName,
        record.clusterName,
        record.previousProperties != null ? jsonEncode(record.previousProperties) : null,
        record.isValid,
        record.responsibleAdministration,
        record.responsibleProvider,
        record.responsibleState,
        record.responsibleTroop,
        record.updatedAt,
        record.localUpdatedAt,
        record.completedAtState,
        record.completedAtTroop,
        record.completedAtAdministration,
        record.isToBeRecorded,
        record.note,
        record.validationErrors,
        record.plausibilityErrors,
        record.isTraining,
      ],
    );

    return recordId;
  }

  Future<void> updateRecord(String id, Record record) async {
    final map = record.toMap();
    map['id'] = id;
    await db.execute(
      'UPDATE records SET ${map.keys.map((key) => '$key = ?').join(', ')} WHERE id = ?',
      [...map.values, id],
    );
  }

  /*Future<void> deleteRecord(String id) async {
    await db.execute('DELETE FROM records WHERE id = ?', [id]);
  }*/

  Future<Record?> getRecordById(String id) async {
    final results = await db.execute('SELECT * FROM records WHERE id = ?', [id]);
    if (results.isNotEmpty) {
      return Record.fromRow(results.first);
    }
    return null;
  }

  /// Get ALL records without organization filtering
  /// Use this for map tile downloads where we need to cover all areas
  Future<List<Record>> getAllRecordsUnfiltered() async {
    try {
      debugPrint('RecordsRepository.getAllRecordsUnfiltered: Fetching all records...');
      final results = await db
          .execute('SELECT * FROM records')
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              debugPrint('RecordsRepository.getAllRecordsUnfiltered: Query timed out');
              throw TimeoutException('Database query timed out');
            },
          );
      debugPrint('RecordsRepository.getAllRecordsUnfiltered: Found ${results.length} records');
      return results.map((row) => Record.fromRow(row)).toList();
    } catch (e, stackTrace) {
      debugPrint('RecordsRepository.getAllRecordsUnfiltered: Error: $e');
      debugPrint('RecordsRepository.getAllRecordsUnfiltered: Stack trace: $stackTrace');
      return [];
    }
  }

  Future<List<Record>> getLimitedRecords(int limit) async {
    final orgFilter = await _getOrganizationFilter();
    final results = await db.execute('SELECT * FROM records WHERE $orgFilter LIMIT ?', [limit]);
    return results.map((row) => Record.fromRow(row)).toList();
  }

  /// Get all records filtered by current permission
  /// Uses organization filter to respect permission settings
  Future<List<Record>> getRecordsByPermissionId() async {
    final orgFilter = await _getOrganizationFilter();
    final results = await db.execute('SELECT * FROM records WHERE $orgFilter');
    return results.map((row) => Record.fromRow(row)).toList();
  }

  /// Get records within a certain distance (in kilometers) from a point
  /// Calculates distance in Dart for accuracy
  Future<List<Record>> getRecordsByDistance({
    required double latitude,
    required double longitude,
    required double radiusKm,
    int? limit,
  }) async {
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

              final distance = _calculateDistance(
                latitude,
                longitude,
                coords['latitude']!,
                coords['longitude']!,
              );

              return {'record': record, 'distance': distance};
            })
            .where((item) => item != null && (item['distance'] as double) <= radiusKm)
            .toList()
          ..sort((a, b) => (a!['distance'] as double).compareTo(b!['distance'] as double));

    final filteredRecords = recordsWithDistance.map((item) => item!['record'] as Record).toList();

    return limit != null ? filteredRecords.take(limit).toList() : filteredRecords;
  }

  /// Get records within a bounding box (more efficient than distance for large areas)
  Future<List<Record>> getRecordsInBounds({
    required double northLat,
    required double southLat,
    required double eastLng,
    required double westLng,
    int? limit,
  }) async {
    final orgFilter = await _getOrganizationFilter();
    final query =
        '''
      SELECT *
      FROM records
      WHERE previous_properties IS NOT NULL
        AND CAST(json_extract(previous_properties, '\$.plot_coordinates.center_location.coordinates[1]') AS REAL) BETWEEN ? AND ?
        AND CAST(json_extract(previous_properties, '\$.plot_coordinates.center_location.coordinates[0]') AS REAL) BETWEEN ? AND ?
        AND $orgFilter
      ${limit != null ? 'LIMIT ?' : ''}
    ''';

    final params = limit != null
        ? [southLat, northLat, westLng, eastLng, limit]
        : [southLat, northLat, westLng, eastLng];

    final results = await db.execute(query, params);
    return results.map((row) => Record.fromRow(row)).toList();
  }
}
