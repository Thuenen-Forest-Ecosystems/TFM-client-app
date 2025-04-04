import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/components/add-edit-plot-dialog.dart';
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
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(troop['name'] ?? troop['id']),
                    subtitle: Text(troop['id'] ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          child: const Text('User hinzufügen'),
                          onPressed: () async {
                            // Show dialog to edit organization
                            await showDialog(
                              context: context,
                              builder: (context) {
                                return AddEditPlotDialog(troopId: troop['id']);
                              },
                            );
                            // Refresh the screen after dialog is closed
                            setState(() {});
                          },
                        ),
                        ElevatedButton(
                          child: const Text('Plot hinzufügen'),
                          onPressed: () async {
                            // Show dialog to edit organization
                            await showDialog(
                              context: context,
                              builder: (context) {
                                return AddEditPlotDialog(troopId: troop['id']);
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
                  ),
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
