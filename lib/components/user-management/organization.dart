import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/components/add-edit-organization-dialog.dart';
import 'package:terrestrial_forest_monitor/components/user-management/troop.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class Organization extends StatefulWidget {
  final String organizationId;
  final int? stateResponsible;
  const Organization({super.key, required this.organizationId, this.stateResponsible});

  @override
  State<Organization> createState() => _OrganizationState();
}

class _OrganizationState extends State<Organization> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: db.watch('SELECT * FROM organizations WHERE parent_organization_id = \'${widget.organizationId}\' ORDER BY created_at DESC'),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final data = snapshot.data as List<Map<String, dynamic>>;
          return ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, index) {
              final organization = data[index];
              return Card.outlined(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: Text(organization['name'] ?? organization['id']),
                      subtitle: Text(organization['id'] ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () async {
                              // Show dialog to edit organization
                              await showDialog(
                                context: context,
                                builder: (context) {
                                  return AddEditOrganizationDialog(parentOrganizationId: widget.organizationId, organizationId: organization['id'], organizationName: organization['name'], organizationApexDomain: organization['apex_domain']);
                                },
                              );
                              // Refresh the screen after dialog is closed
                              setState(() {});
                            },
                          ),
                          /*ElevatedButton(
                                            onPressed: () async {
                                              await showDialog(
                                                context: context,
                                                builder: (context) {
                                                  return AddEditTroopDialog(parentOrganizationId: organization['id']);
                                                },
                                              );
                                              setState(() {});
                                            },
                                            child: const Text('Trupp hinzufügen'),
                                          ),*/
                          ElevatedButton(
                            onPressed: () async {
                              await showDialog(
                                context: context,
                                builder: (context) {
                                  return AddEditOrganizationDialog(parentOrganizationId: organization['id']);
                                },
                              );
                              setState(() {});
                            },
                            child: const Text('Dienstleiter hinzufügen'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    //Organization(organizationId: organization['id'], stateResponsible: organization['stateResponsible']),
                  ],
                ),
              );
            },
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
