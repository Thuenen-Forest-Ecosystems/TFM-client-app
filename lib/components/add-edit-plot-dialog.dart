import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class AddEditPlotDialog extends StatefulWidget {
  /// Dialog to add or edit an organization.
  final String troopId;
  final String? plotId;
  final String? recordId;
  const AddEditPlotDialog({super.key, this.plotId, required this.troopId, this.recordId});

  @override
  State<AddEditPlotDialog> createState() => _AddEditPlotDialogState();
}

class _AddEditPlotDialogState extends State<AddEditPlotDialog> {
  // Define any necessary variables or controllers here
  TextEditingController plotIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    plotIdController.text = widget.plotId ?? '';
  }

  Future<void> _saveOrganization() async {
    if (plotIdController.text.isEmpty) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all fields')));
      return;
    }
    // Implement save logic here
    String plotId = plotIdController.text;

    String? id = widget.recordId;
    String schemaName = 'ci2027';
    // 0000201d-84d9-48a7-8134-47c7438f2bd3
    if (id != null) {
      // Update existing organization
      await db
          .execute('UPDATE records SET plot_id = ?, troop_id = ?, schema_name=? WHERE id = ?', [plotId, widget.troopId, schemaName, id])
          .then((value) {
            // Handle success
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record updated successfully')));
            Navigator.of(context).pop();
          })
          .catchError((error) {
            // Handle error
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating record: $error')));
          });
    } else {
      // Add new organization

      // timestamptz
      await db
          .execute('INSERT INTO records (id, troop_id, plot_id, schema_name) VALUES (uuid(), ?, ?, ?)', [widget.troopId, plotId, schemaName])
          .then((value) {
            // Handle success
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record added successfully')));
            Navigator.of(context).pop();
          })
          .catchError((error) {
            // Handle error
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding record: $error')));
          });
    }
  }

  /*Future<void> _deleteOrganization() async {
    if (widget.organizationId == null) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No organization selected')));
      return;
    }
    // Implement delete logic here
    String id = widget.organizationId!;
    await db
        .execute('DELETE FROM troop WHERE id = ?', [id])
        .then((value) {
          // Handle success
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Organization deleted successfully')));
          Navigator.of(context).pop();
        })
        .catchError((error) {
          // Handle error
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting organization: $error')));
        });
  }*/

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Plot hinzufügen'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 20),
            TextField(decoration: const InputDecoration(labelText: 'Plot Id', helperText: 'Id des Plots'), controller: plotIdController, keyboardType: TextInputType.text),
            SizedBox(height: 20),
            // Add more fields as needed
            SizedBox(height: 20),
          ],
        ),
      ),
      actions: [
        //TextButton(onPressed: _deleteOrganization, child: const Text('Löschen')),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(onPressed: _saveOrganization, child: const Text('Hinzufügen')),
      ],
    );
  }
}
