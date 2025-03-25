import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/components/add-edit-organization-dialog.dart';
import 'package:terrestrial_forest_monitor/components/add-edit-troop-dialog.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

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
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 800, minWidth: 300),
        child: FutureBuilder(
          future: db.get('SELECT * FROM users_profile'),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              rootOrganizationId = (snapshot.data as Map<String, dynamic>)['organization_id'] ?? rootOrganizationId;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Dienstleister'),
                    subtitle: const Text('Hier können Sie Ihre Organisationen verwalten'),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        await showDialog(
                          context: context,
                          builder: (context) {
                            return AddEditOrganizationDialog(parentOrganizationId: rootOrganizationId);
                          },
                        );
                        setState(() {});
                      },
                      child: const Text('Dienstleiter hinzufügen'),
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 10),
                  Expanded(
                    // Wichtig: Wrapped in Expanded // WHERE parent_organization_id = $rootOrganizationId OR id = $rootOrganizationId
                    child: StreamBuilder(
                      stream: db.watch('SELECT * FROM organizations WHERE parent_organization_id = \'$rootOrganizationId\' ORDER BY created_at DESC'),
                      builder: (context, snapshot) {
                        print('-----');
                        print(snapshot.data);
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
                                                  return AddEditTroopDialog(parentOrganizationId: rootOrganizationId);
                                                },
                                              );
                                              setState(() {});
                                            },
                                            child: const Text('Trupp hinzufügen'),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(),
                                    FutureBuilder(
                                      future: db.getAll('SELECT * FROM troop WHERE organization_id = ?', [organization['id']]),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          final troopData = snapshot.data as List<Map<String, dynamic>>;
                                          return ListView.builder(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            itemCount: troopData.length,
                                            itemBuilder: (context, index) {
                                              final troop = troopData[index];
                                              return ListTile(
                                                title: Text(troop['name'] ?? ''),
                                                subtitle: Text(troop['plot_ids'] ?? ''),
                                                trailing: IconButton(
                                                  icon: const Icon(Icons.edit),
                                                  onPressed: () {
                                                    // Handle edit action
                                                  },
                                                ),
                                              );
                                            },
                                          );
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
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }
}
