import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class AddEditOrganizationDialog extends StatefulWidget {
  /// Dialog to add or edit an organization.
  final String parentOrganizationId;
  final String? organizationId;
  final String? organizationName;
  final String? organizationApexDomain;
  const AddEditOrganizationDialog({super.key, required this.parentOrganizationId, this.organizationId, this.organizationName, this.organizationApexDomain});

  @override
  State<AddEditOrganizationDialog> createState() => _AddEditOrganizationDialogState();
}

class _AddEditOrganizationDialogState extends State<AddEditOrganizationDialog> {
  // Define any necessary variables or controllers here
  TextEditingController nameController = TextEditingController();
  TextEditingController apexDomainController = TextEditingController();

  @override
  void initState() {
    super.initState();
    nameController.text = widget.organizationName ?? '';
    apexDomainController.text = widget.organizationApexDomain ?? '';
    print(nameController.text);
    print(apexDomainController.text);
  }

  Future<void> _saveOrganization() async {
    if (apexDomainController.text.isEmpty) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all fields')));
      return;
    }
    // Implement save logic here
    String name = nameController.text;
    String email = apexDomainController.text;
    // Validate email format
    final RegExp emailRegex = RegExp(r'^@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid email format')));
      return;
    }
    String domain = email.split('@').last;

    String apexDomain = '@$domain';
    String? id = widget.organizationId;
    if (id != null) {
      // Update existing organization
      await db
          .execute('UPDATE organizations SET name = ?, apex_domain = ? WHERE id = ?', [name, apexDomain, id])
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
          .execute('INSERT INTO organizations (id, name, apex_domain, parent_organization_id) VALUES (uuid(), ?, ?, ?)', [name, apexDomain, widget.parentOrganizationId])
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
        .execute('DELETE FROM organizations WHERE id = ?', [id])
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
      title: const Text('Dienstleister Unternehmen hinzufügen'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 20),
            TextField(decoration: const InputDecoration(labelText: 'Name', helperText: 'Name des Dienstleistungsunternehmen'), controller: nameController, keyboardType: TextInputType.text),
            SizedBox(height: 20),
            TextField(decoration: const InputDecoration(labelText: 'E-Mail', helperText: 'E-Mail Adresse des Ansprechpartners'), controller: apexDomainController, keyboardType: TextInputType.emailAddress),
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
