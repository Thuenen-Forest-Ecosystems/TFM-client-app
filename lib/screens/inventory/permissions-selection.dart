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
  String? _selectedOrganizationId;

  @override
  void initState() {
    super.initState();
    _loadSelectedOrganization();
  }

  Future<void> _loadSelectedOrganization() async {
    final selectedId = await _selectionService.getSelectedOrganizationId();
    if (mounted) {
      setState(() {
        _selectedOrganizationId = selectedId;
      });
    }
  }

  Future<void> _selectOrganizationAndRoute(String organizationId) async {
    await _selectionService.setSelectedOrganizationId(organizationId);
    if (mounted) {
      setState(() {
        _selectedOrganizationId = organizationId;
      });
      Beamer.of(context).beamToNamed('/records-selection/${widget.schemaId}');
    }
  }

  Future<void> _selectOrganization(String organizationId) async {
    await _selectionService.setSelectedOrganizationId(organizationId);
    if (mounted) {
      setState(() {
        _selectedOrganizationId = organizationId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PermissionModel>>(
      stream: _repository.watchPermissionsByUserId(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))));
        }

        if (snapshot.hasError) {
          return Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text('Fehler: ${snapshot.error}', style: TextStyle(color: Colors.red[700], fontSize: 12)));
        }

        final permissions = snapshot.data ?? [];

        if (permissions.isEmpty) {
          return const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('Keine Berechtigungen gefunden', style: TextStyle(color: Colors.grey, fontSize: 12)));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < permissions.length; i++) ...[
              Builder(
                builder: (context) {
                  final permission = permissions[i];
                  final orgName = permission.organizationName ?? 'Unbekannt';
                  final orgDescription = permission.organizationDescription;

                  return ListTile(
                    onTap: () {
                      _selectOrganizationAndRoute(permission.organizationId);
                    },
                    title: Text(orgName),
                    subtitle: orgDescription != null && orgDescription.isNotEmpty ? Text(orgDescription) : null,
                    //selected: isSelected,
                    trailing: Icon(Icons.arrow_forward_ios),
                  );
                },
              ),
              if (i < permissions.length - 1) const Divider(height: 1),
            ],
          ],
        );
      },
    );
  }
}
