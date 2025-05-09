import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/components/add-edit-organization-dialog.dart';
import 'package:terrestrial_forest_monitor/components/add-edit-troop-dialog.dart';
import 'package:terrestrial_forest_monitor/components/own-organization.dart';
import 'package:terrestrial_forest_monitor/components/user-management/troop.dart';
import 'package:terrestrial_forest_monitor/components/user-management/users-profile-list.dart';
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
              int? stateResponsible = (snapshot.data as Map<String, dynamic>)['state_responsible'];
              String? organizationId = (snapshot.data as Map<String, dynamic>)['organization_id'] ?? '';
              bool? isOrganizationAdmin = (snapshot.data as Map<String, dynamic>)['is_organization_admin'] == 1;
              //bool canAdminTroop = (snapshot.data as Map<String, dynamic>)['can_admin_troop'] == 1;

              if (organizationId != null) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OwnOrganization(organizationId: rootOrganizationId, isOrganisationAdmin: isOrganizationAdmin),
                    SizedBox(height: 10),
                    if (isOrganizationAdmin) Divider(thickness: 1),
                    SizedBox(height: 10),
                    if (isOrganizationAdmin)
                      FutureBuilder(
                        future: db.get('SELECT * FROM organizations WHERE id = ?', [rootOrganizationId]),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            final int? stateResponsible = (snapshot.data as Map<String, dynamic>)['state_responsible'];
                            final bool isServiceProvider = (snapshot.data as Map<String, dynamic>)['is_service_provider'] == 1;
                            final bool canAdminTroop = (snapshot.data as Map<String, dynamic>)['can_admin_troop'] == 1;
                            final bool canAdminOrganization = (snapshot.data as Map<String, dynamic>)['can_admin_organization'] == 1;

                            List<Widget> additionalButtons = [];

                            if (canAdminTroop) {
                              additionalButtons.add(
                                ListTile(
                                  title: const Text('Truppe'),
                                  subtitle: const Text('Fügen Sie Dienstleister hinzu'),
                                  trailing: IconButton(
                                    onPressed: () async {
                                      await showDialog(
                                        context: context,
                                        builder: (context) {
                                          return AddEditTroopDialog(parentOrganizationId: rootOrganizationId);
                                        },
                                      );
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.add),
                                  ),
                                ),
                              );
                              additionalButtons.add(Card(child: TroopManagement(organizationId: organizationId)));
                            }
                            if (!isServiceProvider) {
                              additionalButtons.add(
                                ListTile(
                                  title: const Text('Dienstleister'),
                                  subtitle: const Text('Fügen Sie Dienstleister hinzu'),
                                  trailing: IconButton(
                                    onPressed: () async {
                                      await showDialog(
                                        context: context,
                                        builder: (context) {
                                          return AddEditOrganizationDialog(parentOrganizationId: rootOrganizationId);
                                        },
                                      );
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.add),
                                  ),
                                ),
                              );
                            }

                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ...additionalButtons, // Injecting additionalButtons here
                              ],
                            );
                          }
                          return const Center(child: CircularProgressIndicator());
                        },
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
                                          ],
                                        ),
                                      ),
                                      const Divider(),
                                      FutureBuilder(
                                        future: db.getAll('SELECT * FROM users_profile WHERE organization_id = ?', [organization['id']]),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState == ConnectionState.waiting) {
                                            return const Center(child: CircularProgressIndicator());
                                          } else if (snapshot.hasData) {
                                            return UsersProfileList(usersProfileList: snapshot.data as List<Map<String, dynamic>>);
                                          } else if (snapshot.hasData && (snapshot.data as List<Map<String, dynamic>>).isEmpty) {
                                            return const Center(child: Text('Keine Mitarbeitende gefunden.'));
                                          } else if (snapshot.hasError) {
                                            return Center(child: Text('Error: ${snapshot.error}'));
                                          } else {
                                            // Handle the case when data is null or empty
                                            return const Center(child: Text('Keine Daten gefunden.'));
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          } else if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}'));
                          } else if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          } else if (snapshot.hasData && (snapshot.data as List<Map<String, dynamic>>).isEmpty) {
                            return const Center(child: Text('Keine Organisationen gefunden.'));
                          } else {
                            return const Center(child: Text('Unbekannter Fehler.'));
                          }
                        },
                      ),
                    ),
                  ],
                );
              } else {
                return const Center(child: Text('Sie haben keine Berechtigung, eine Organisation zu verwalten.'));
              }
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else {
              return const Center(child: Text('Unbekannter Fehler.'));
            }
          },
        ),
      ),
    );
  }
}
