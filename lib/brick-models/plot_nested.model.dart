// Your model definition can live anywhere in lib/**/* as long as it has the .model.dart suffix
// Assume this file is saved at my_app/lib/src/users/user.model.dart

import 'package:brick_offline_first_with_supabase/brick_offline_first_with_supabase.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:brick_supabase/brick_supabase.dart';
import 'package:uuid/uuid.dart';

@ConnectOfflineFirstWithSupabase(supabaseConfig: SupabaseSerializable(tableName: 'plot_nested_json'))
class PlotNestedJson extends OfflineFirstWithSupabaseModel {
  final String? cluster_id;

  // All related data as direct properties
  // Now they're non-nullable Lists since the SQL guarantees at least empty arrays
  final List<Map<String, dynamic>> tree;
  final List<Map<String, dynamic>> deadwood;
  final List<Map<String, dynamic>> regeneration;
  final List<Map<String, dynamic>> structure_lt4m;
  final List<Map<String, dynamic>> edges;

  // Add debugging toString method to help with debugging
  @override
  String toString() {
    return 'PlotNestedJson{id: $id, cluster_id: $cluster_id, ' + 'treeCount: ${tree.length}, deadwoodCount: ${deadwood.length}}';
  }

  // Be sure to specify an index that **is not** auto incremented in your table.
  // An offline-first strategy requires distributed clients to create
  // indexes without fear of collision.
  @Supabase(unique: true)
  @Sqlite(index: true, unique: true)
  final String id;

  PlotNestedJson({
    String? id,
    this.cluster_id, // Use empty lists as defaults in case the adapters somehow get null values
    this.tree = const [],
    this.deadwood = const [],
    this.regeneration = const [],
    this.structure_lt4m = const [],
    this.edges = const [],
  }) : id = id ?? const Uuid().v4();

  // Get a tree by its ID
  Map<String, dynamic>? getTreeById(String treeId) {
    try {
      return tree.firstWhere((tree) => tree['id'] == treeId);
    } catch (e) {
      return null;
    }
  }

  // Helper method to check if there are any trees
  //bool get hasTrees => tree.isNotEmpty;

  // Helper method to check if there are any deadwoods
  //bool get hasDeadwoods => deadwood.isNotEmpty;
}
