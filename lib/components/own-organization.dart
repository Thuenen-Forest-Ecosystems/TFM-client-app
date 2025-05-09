import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/components/invite-user-dialog.dart';
import 'package:terrestrial_forest_monitor/components/user-management/users-profile-list.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class OwnOrganization extends StatefulWidget {
  final String organizationId;
  final bool isOrganisationAdmin;
  const OwnOrganization({super.key, required this.organizationId, this.isOrganisationAdmin = false});

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
          return Center(child: Text('Organization Error: ${snapshot.error}'));
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
                  return ListTile(title: Text('Berechtigungt durch:'), subtitle: Text(parentOrganization?['name'] ?? 'Unknown'));
                },
              ),

            ListTile(
              title: Text(organization?['name'] ?? 'Unknown'),
              //subtitle: Text(organization?['description'] ?? organization?['id']),
              trailing:
                  widget.isOrganisationAdmin
                      ? ElevatedButton(
                        onPressed: () async {
                          await showDialog(
                            context: context,
                            builder: (context) {
                              return InviteUserDialog(parentOrganizationId: widget.organizationId);
                              //return AddEditOrganizationDialog(parentOrganizationId: widget.organizationId);
                            },
                          );
                          setState(() {});
                        },
                        child: const Text('Mitarbeitende hinzufügen'),
                      )
                      : null,
            ),
            Card(
              child: FutureBuilder(
                future: db.getAll('SELECT * FROM users_profile WHERE organization_id = ?', [widget.organizationId]),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return UsersProfileList(usersProfileList: snapshot.data as List<Map<String, dynamic>>);
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
