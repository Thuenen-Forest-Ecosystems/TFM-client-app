import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/components/add-edit-organization-dialog.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class OwnOrganization extends StatefulWidget {
  final String organizationId;
  const OwnOrganization({super.key, required this.organizationId});

  @override
  State<OwnOrganization> createState() => _OwnOrganizationState();
}

class _OwnOrganizationState extends State<OwnOrganization> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: db.get('SELECT * FROM organizations WHERE id=?', [widget.organizationId]),
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('No data found'));
        }

        final organization = snapshot.data;
        return Column(
          children: [
            if (organization?['parent_organization_id'] != null)
              FutureBuilder(
                future: db.get('SELECT * FROM organizations WHERE id=?', [organization?['parent_organization_id']]),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: Text('No data found'));
                  }

                  final parentOrganization = snapshot.data;
                  return ListTile(title: Text(parentOrganization?['name'] ?? 'Unknown'));
                },
              ),
            ListTile(
              title: Text(organization?['name'] ?? 'Unknown'),
              subtitle: Text(organization?['description'] ?? organization?['id']),
              trailing: ElevatedButton(
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (context) {
                      return AddEditOrganizationDialog(parentOrganizationId: widget.organizationId);
                    },
                  );
                  setState(() {});
                },
                child: const Text('Mitarbeitende hinzufügen'),
              ),
            ),
          ],
        );
      },
    );
  }
}
