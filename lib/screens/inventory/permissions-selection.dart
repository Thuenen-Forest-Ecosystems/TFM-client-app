import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/repositories/permissions_repository.dart';
import 'package:terrestrial_forest_monitor/services/organization_selection_service.dart';

/// Widget that displays a list of permissions (organizations) assigned to a user.
/// Shows organization names as selectable radio buttons.
class PermissionsSelection extends StatefulWidget {
  final String userId;
  final String schemaId;

  const PermissionsSelection({super.key, required this.userId, required this.schemaId});

  @override
  State<PermissionsSelection> createState() => _PermissionsSelectionState();
}

class _PermissionsSelectionState extends State<PermissionsSelection> {
  final PermissionsRepository _repository = PermissionsRepository();
  final OrganizationSelectionService _selectionService = OrganizationSelectionService();
  //String? _selectedOrganizationId;

  @override
  void initState() {
    super.initState();
    _loadSelectedOrganization();
  }

  Future<void> _loadSelectedOrganization() async {
    await _selectionService.getSelectedOrganizationId();
    //if (mounted) {
    //  setState(() {
    //    _selectedOrganizationId = selectedId;
    //  });
    //}
  }

  Future<void> _selectOrganizationAndRoute(String organizationId) async {
    await _selectionService.setSelectedOrganizationId(organizationId);
    if (mounted) {
      //setState(() {
      //  _selectedOrganizationId = organizationId;
      //});
      Beamer.of(context).beamToNamed('/records-selection/${widget.schemaId}');
    }
  }

  Future<void> _selectePermissionAndRoute(
    String permissionId,
    String organizationId, {
    bool isAdmin = false,
    String? troopId,
  }) async {
    await _selectionService.setSelectedPermissionId(permissionId);
    await _selectionService.setSelectedOrganizationId(organizationId);
    await _selectionService.setIsOrganizationAdmin(isAdmin);
    await _selectionService.setSelectedTroopId(troopId);

    print('Selected permission: $permissionId');
    print('Selected organization: $organizationId');
    print('Is admin: $isAdmin');
    print('Selected troop: $troopId');

    if (mounted) {
      //setState(() {
      //  _selectedOrganizationId = organizationId;
      //});
      Beamer.of(context).beamToNamed('/records-selection/${widget.schemaId}');
    }
  }

  /*Future<void> _selectOrganization(String organizationId) async {
    await _selectionService.setSelectedOrganizationId(organizationId);
    if (mounted) {
      setState(() {
        _selectedOrganizationId = organizationId;
      });
    }
  }*/

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TroopModel>>(
      stream: _repository.watchTroopsByUserId(widget.userId),
      builder: (context, troopSnapshot) {
        final userTroops = troopSnapshot.data ?? [];

        return StreamBuilder<List<PermissionModel>>(
          stream: _repository.watchPermissionsByUserId(widget.userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Center(
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Fehler: ${snapshot.error}',
                  style: TextStyle(color: Colors.red[700], fontSize: 12),
                ),
              );
            }

            final permissions = snapshot.data ?? [];

            if (permissions.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Keine Berechtigungen gefunden',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              );
            }

            // Group permissions by organization
            final Map<String, List<PermissionModel>> groupedPermissions = {};
            for (final permission in permissions) {
              final orgId = permission.organizationId;
              if (!groupedPermissions.containsKey(orgId)) {
                groupedPermissions[orgId] = [];
              }
              groupedPermissions[orgId]!.add(permission);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in groupedPermissions.entries) ...[
                  Builder(
                    builder: (context) {
                      final orgPermissions = entry.value;
                      final firstPermission = orgPermissions.first;
                      final orgName = firstPermission.organizationName ?? 'Unbekannt';
                      final orgDescription = firstPermission.organizationDescription;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Organization header
                          ListTile(
                            //onTap: () {
                            //  _selectOrganizationAndRoute(firstPermission.organizationId);
                            //},
                            title: Text(
                              orgName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: orgDescription != null && orgDescription.isNotEmpty
                                ? Text(orgDescription)
                                : null,
                            //trailing: const Icon(Icons.arrow_forward_ios),
                          ),
                          // Show all permissions for this organization
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0),
                            child: Column(
                              children: [
                                for (final permission in orgPermissions)
                                  ..._buildPermissionTile(permission, userTroops),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  List<Widget> _buildPermissionTile(PermissionModel permission, List<TroopModel> userTroops) {
    if (permission.isOrganizationAdmin) {
      // Show admin role
      return [
        ListTile(
          dense: true,
          leading: const Icon(Icons.shield, size: 20),
          title: const Text(
            'Administrator',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            'Berechtigung seit ${_formatDate(permission.createdAt)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          onTap: () {
            _selectePermissionAndRoute(permission.id, permission.organizationId, isAdmin: true);
          },
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        ),
      ];
    } else {
      // Show troop memberships
      final organizationTroops = userTroops
          .where((troop) => troop.organizationId == permission.organizationId)
          .toList();

      if (organizationTroops.isEmpty) {
        return [
          ListTile(
            dense: true,
            leading: const Icon(Icons.person, size: 20),
            title: const Text('Mitglied', style: TextStyle(fontSize: 14)),
            subtitle: Text(
              'Berechtigung seit ${_formatDate(permission.createdAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ];
      }

      return organizationTroops.map((troop) {
        return StreamBuilder<int>(
          stream: _repository.watchRecordCountForTroop(troop.id, troop.organizationId),
          builder: (context, countSnapshot) {
            final recordCount = countSnapshot.data ?? 0;

            return ListTile(
              dense: true,
              //leading: const Icon(Icons.group, size: 20),
              title: Text(
                troop.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Eckenanzahl: $recordCount',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              onTap: () {
                _selectePermissionAndRoute(
                  permission.id,
                  permission.organizationId,
                  isAdmin: false,
                  troopId: troop.id,
                );
              },
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            );
          },
        );
      }).toList();
    }
  }
}
