import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/components/add-edit-organization-dialog.dart';
import 'package:terrestrial_forest_monitor/components/add-edit-troop-dialog.dart';
import 'package:terrestrial_forest_monitor/components/invite-user-dialog.dart';
import 'package:terrestrial_forest_monitor/components/own-organization.dart';
import 'package:terrestrial_forest_monitor/components/users-profile-list.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrganizationsScreen extends StatefulWidget {
  const OrganizationsScreen({super.key});

  @override
  State<OrganizationsScreen> createState() => _OrganizationsScreenState();
}

class _OrganizationsScreenState extends State<OrganizationsScreen> {
  String rootOrganizationId = ''; // GET FROM users_profile

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  Future<String> _getText(String? text) async {
    if (text == null || text.isEmpty) {
      return 'N/A';
    }
    return 'Fügen Sie Dienstleister hinzu';
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 800, minWidth: 300),
        child: FutureBuilder(
          future: db.get('SELECT * FROM users_profile WHERE id = ?', [session?.user.id]),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              rootOrganizationId = (snapshot.data as Map<String, dynamic>)['organization_id'] ?? rootOrganizationId;
              bool isAdmin = (snapshot.data as Map<String, dynamic>)['is_admin'] == 1;
              int? stateResponsible = (snapshot.data as Map<String, dynamic>)['state_responsible'] ?? null;
              print(stateResponsible);
              print(isAdmin);
              if (stateResponsible != null || isAdmin) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OwnOrganization(organizationId: rootOrganizationId),
                    SizedBox(height: 10),
                    Divider(thickness: 2),
                    SizedBox(height: 10),
                    Center(
                      child: ElevatedButton(
                        onPressed: () async {
                          await showDialog(
                            context: context,
                            builder: (context) {
                              return AddEditOrganizationDialog(parentOrganizationId: rootOrganizationId);
                            },
                          );
                          setState(() {});
                        },
                        child: const Text('Organisation hinzufügen'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      // Wichtig: Wrapped in Expanded // WHERE parent_organization_id = $rootOrganizationId OR id = $rootOrganizationId
                      child: StreamBuilder(
                        stream: db.watch('SELECT * FROM organizations WHERE parent_organization_id = \'$rootOrganizationId\' ORDER BY created_at DESC'),
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
                                                    return AddEditOrganizationDialog(
                                                      parentOrganizationId: rootOrganizationId,
                                                      organizationId: organization['id'],
                                                      organizationName: organization['name'],
                                                      organizationApexDomain: organization['apex_domain'],
                                                    );
                                                  },
                                                );
                                                // Refresh the screen after dialog is closed
                                                setState(() {});
                                              },
                                            ),
                                            ElevatedButton(
                                              onPressed: () async {
                                                await showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return InviteUserDialog(parentOrganizationId: organization['id']);
                                                  },
                                                );
                                                setState(() {});
                                              },
                                              child: const Text('Mitarbeiter einladen'),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Divider(),
                                      FutureBuilder(
                                        future: db.getAll('SELECT * FROM users_profile WHERE organization_id = ?', [organization['id']]),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData) {
                                            return UsersProfileList(usersProfileList: snapshot.data as List<Map<String, dynamic>>);
                                          }
                                          return const Center(child: CircularProgressIndicator());
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          } else {
                            return const Center(child: CircularProgressIndicator());
                          }
                        },
                      ),
                    ),
                  ],
                );
              } else {
                return const Center(child: Text('Sie haben keine Berechtigung, Organisationen zu verwalten.'));
              }
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }
}
