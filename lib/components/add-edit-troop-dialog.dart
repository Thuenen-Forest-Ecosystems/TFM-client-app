import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class AddEditTroopDialog extends StatefulWidget {
  /// Dialog to add or edit an organization.
  final String parentOrganizationId;
  final String? organizationId;
  final String? organizationName;
  const AddEditTroopDialog({super.key, required this.parentOrganizationId, this.organizationId, this.organizationName});

  @override
  State<AddEditTroopDialog> createState() => _AddEditTroopDialogState();
}

class _AddEditTroopDialogState extends State<AddEditTroopDialog> {
  // Define any necessary variables or controllers here
  TextEditingController nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    nameController.text = widget.organizationName ?? '';
  }

  Future<void> _saveOrganization() async {
    if (nameController.text.isEmpty) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all fields')));
      return;
    }
    // Implement save logic here
    String name = nameController.text;

    String? id = widget.organizationId;
    if (id != null) {
      // Update existing organization
      await db
          .execute('UPDATE troop SET name = ?, organization_id = ? WHERE id = ?', [name, widget.parentOrganizationId, id])
          .then((value) {
            // Handle success
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Organization updated successfully')));
            Navigator.of(context).pop();
          })
          .catchError((error) {
            // Handle error
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating organization: $error')));
          });
    } else {
      // Add new organization
      await db
          .execute('INSERT INTO troop (id, name, organization_id) VALUES (uuid(), ?, ?)', [name, widget.parentOrganizationId])
          .then((value) {
            // Handle success
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Organization added successfully')));
            Navigator.of(context).pop();
          })
          .catchError((error) {
            // Handle error
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding organization: $error')));
          });
    }
  }

  Future<void> _deleteOrganization() async {
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
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Trupp hinzufügen'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 20),
            TextField(decoration: const InputDecoration(labelText: 'Name', helperText: 'Name des Trupps'), controller: nameController, keyboardType: TextInputType.text),
            SizedBox(height: 20),
            // Add more fields as needed
            SizedBox(height: 20),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _deleteOrganization, child: const Text('Löschen')),
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
