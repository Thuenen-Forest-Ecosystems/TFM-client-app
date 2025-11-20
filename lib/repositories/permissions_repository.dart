import 'package:terrestrial_forest_monitor/services/powersync.dart';

class PermissionsRepository {
  // Watch permissions for a specific user
  Stream<List<PermissionModel>> watchPermissionsByUserId(String userId) {
    return db
        .watch(
          '''SELECT up.*, o.name as organization_name, o.description as organization_description 
         FROM users_permissions up
         LEFT JOIN organizations o ON up.organization_id = o.id
         WHERE up.user_id = ?
         ORDER BY up.created_at DESC''',
          parameters: [userId],
        )
        .map((results) => results.map((row) => PermissionModel.fromJson(row)).toList());
  }

  // Get all permissions for a user (one-time query)
  Future<List<PermissionModel>> getPermissionsByUserId(String userId) async {
    final results = await db.getAll(
      '''SELECT up.*, o.name as organization_name, o.description as organization_description 
         FROM users_permissions up
         LEFT JOIN organizations o ON up.organization_id = o.id
         WHERE up.user_id = ?
         ORDER BY up.created_at DESC''',
      [userId],
    );
    return results.map((row) => PermissionModel.fromJson(row)).toList();
  }

  // Get organization name by ID
  Future<String?> getOrganizationName(String organizationId) async {
    final results = await db.getAll('SELECT name FROM organizations WHERE id = ?', [organizationId]);
    return results.isEmpty ? null : results.first['name'] as String?;
  }

  // Watch all organizations
  Stream<List<OrganizationModel>> watchAllOrganizations() {
    return db.watch('SELECT * FROM organizations ORDER BY name ASC').map((results) => results.map((row) => OrganizationModel.fromJson(row)).toList());
  }

  // Get organization by ID
  Future<OrganizationModel?> getOrganizationById(String id) async {
    final results = await db.getAll('SELECT * FROM organizations WHERE id = ?', [id]);
    return results.isEmpty ? null : OrganizationModel.fromJson(results.first);
  }
}

// Permission Model
class PermissionModel {
  final String id;
  final DateTime createdAt;
  final String userId;
  final String organizationId;
  final bool isOrganizationAdmin;
  final String? organizationName; // Joined from organizations table
  final String? organizationDescription; // Joined from organizations table

  PermissionModel({required this.id, required this.createdAt, required this.userId, required this.organizationId, required this.isOrganizationAdmin, this.organizationName, this.organizationDescription});

  factory PermissionModel.fromJson(Map<String, dynamic> json) {
    return PermissionModel(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      userId: json['user_id'] as String,
      organizationId: json['organization_id'] as String,
      isOrganizationAdmin: (json['is_organization_admin'] as int?) == 1,
      organizationName: json['organization_name'] as String?,
      organizationDescription: json['organization_description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'user_id': userId,
      'organization_id': organizationId,
      'is_organization_admin': isOrganizationAdmin ? 1 : 0,
      'organization_name': organizationName,
      'organization_description': organizationDescription,
    };
  }
}

// Organization Model
class OrganizationModel {
  final String id;
  final String name;
  final String? apexDomain;
  final DateTime? createdAt;
  final String? createdBy;
  final int? stateResponsible;
  final String? parentOrganizationId;
  final bool? canAdminOrganization;
  final bool? canAdminTroop;

  OrganizationModel({required this.id, required this.name, this.apexDomain, this.createdAt, this.createdBy, this.stateResponsible, this.parentOrganizationId, this.canAdminOrganization, this.canAdminTroop});

  factory OrganizationModel.fromJson(Map<String, dynamic> json) {
    return OrganizationModel(
      id: json['id'] as String,
      name: json['name'] as String,
      apexDomain: json['apex_domain'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      createdBy: json['created_by'] as String?,
      stateResponsible: json['state_responsible'] as int?,
      parentOrganizationId: json['parent_organization_id'] as String?,
      canAdminOrganization: (json['can_admin_organization'] as int?) == 1,
      canAdminTroop: (json['can_admin_troop'] as int?) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'apex_domain': apexDomain,
      'created_at': createdAt?.toIso8601String(),
      'created_by': createdBy,
      'state_responsible': stateResponsible,
      'parent_organization_id': parentOrganizationId,
      'can_admin_organization': canAdminOrganization == true ? 1 : 0,
      'can_admin_troop': canAdminTroop == true ? 1 : 0,
    };
  }
}
