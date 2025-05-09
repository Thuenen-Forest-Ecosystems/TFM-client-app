import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/components/user-management/users-profile-list.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class TroopManagement extends StatefulWidget {
  final String organizationId;
  const TroopManagement({super.key, required this.organizationId});

  @override
  State<TroopManagement> createState() => _TroopManagementState();
}

class _TroopManagementState extends State<TroopManagement> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: db.getAll('SELECT * FROM troop WHERE organization_id = ?', [widget.organizationId]),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final troopData = snapshot.data as List<Map<String, dynamic>>;
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: troopData.length,
            itemBuilder: (context, index) {
              final troop = troopData[index];
              final List userIds = jsonDecode(troop['user_ids'] ?? '[]');

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(title: Text(troop['name'] ?? troop['id']), subtitle: Text(troop['id'] ?? ''), trailing: Row(mainAxisSize: MainAxisSize.min)),
                  const Divider(),
                  if (userIds.isNotEmpty)
                    FutureBuilder(
                      future: db.getAll('SELECT * FROM users_profile WHERE id = ?', userIds),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return UsersProfileList(usersProfileList: snapshot.data as List<Map<String, dynamic>>);
                        } else if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        } else if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        } else {
                          return const Center(child: Text('No users found'));
                        }
                      },
                    ),

                  /*FutureBuilder(
                    future: db.getAll('SELECT * FROM records WHERE troop_id = ? ', [troop['id']]),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final plotData = snapshot.data as List<Map<String, dynamic>>;
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: plotData.length,
                          itemBuilder: (context, index) {
                            final plot = plotData[index];
                            return ListTile(
                              title: Text(plot['plot_id'] ?? plot['id']),
                              subtitle: Text(plot['id'] ?? ''),
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
                                          return AddEditPlotDialog(troopId: troop['id'], plotId: plot['plot_id']);
                                        },
                                      );
                                      // Refresh the screen after dialog is closed
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }
                      return const Center(child: CircularProgressIndicator());
                    },
                  ),*/
                ],
              );
            },
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
