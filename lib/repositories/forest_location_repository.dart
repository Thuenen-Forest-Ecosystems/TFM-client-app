import 'package:terrestrial_forest_monitor/services/powersync.dart';

class ForestLocationRepository {
  // Watch all forest locations (reactive)
  Stream<List<ForestLocation>> watchAll() {
    return db.watch('SELECT * FROM forest_locations ORDER BY created_at DESC').map((results) => results.map((row) => ForestLocation.fromJson(row)).toList());
  }

  // Get single location
  Future<ForestLocation?> getById(String id) async {
    final results = await db.getAll('SELECT * FROM forest_locations WHERE id = ?', [id]);
    return results.isEmpty ? null : ForestLocation.fromJson(results.first);
  }

  // Create new location
  Future<void> create(ForestLocation location) async {
    await db.execute(
      '''INSERT INTO forest_locations (id, name, latitude, longitude, created_at)
         VALUES (?, ?, ?, ?, ?)''',
      [location.id, location.name, location.latitude, location.longitude, location.createdAt.toIso8601String()],
    );
  }

  // Update location
  Future<void> update(ForestLocation location) async {
    await db.execute(
      '''UPDATE forest_locations 
         SET name = ?, latitude = ?, longitude = ?
         WHERE id = ?''',
      [location.name, location.latitude, location.longitude, location.id],
    );
  }

  // Delete location
  Future<void> delete(String id) async {
    await db.execute('DELETE FROM forest_locations WHERE id = ?', [id]);
  }

  // Search locations
  Stream<List<ForestLocation>> search(String query) {
    return db.watch('SELECT * FROM forest_locations WHERE name LIKE ? ORDER BY name', parameters: ['%$query%']).map((results) => results.map((row) => ForestLocation.fromJson(row)).toList());
  }
}

// Model class
class ForestLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final DateTime createdAt;

  ForestLocation({required this.id, required this.name, required this.latitude, required this.longitude, required this.createdAt});

  factory ForestLocation.fromJson(Map<String, dynamic> json) {
    return ForestLocation(id: json['id'] as String, name: json['name'] as String, latitude: json['latitude'] as double, longitude: json['longitude'] as double, createdAt: DateTime.parse(json['created_at'] as String));
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'latitude': latitude, 'longitude': longitude, 'created_at': createdAt.toIso8601String()};
  }
}
