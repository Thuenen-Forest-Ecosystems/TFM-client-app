import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class InviteUserDialog extends StatefulWidget {
  final String parentOrganizationId;
  const InviteUserDialog({super.key, required this.parentOrganizationId});

  @override
  State<InviteUserDialog> createState() => _InviteUserDialogState();
}

class _InviteUserDialogState extends State<InviteUserDialog> {
  TextEditingController emailController = TextEditingController();

  Future<void> _sendInvitation() async {
    if (emailController.text.isEmpty) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all fields')));
      return;
    }
    try {
      final FunctionResponse data = await Supabase.instance.client.functions.invoke(
        'invite-user',
        body: jsonEncode({
          'email': emailController.text,
          'metaData': {'organization_id': widget.parentOrganizationId},
        }),
      );
      if (data.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invitation sent successfully')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending invitation: ${data.data['error']}')));
      }
      print(data.data);
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite User'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(decoration: const InputDecoration(labelText: 'Name', helperText: 'Email '), controller: emailController, keyboardType: TextInputType.text)]),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            await _sendInvitation();
            Navigator.of(context).pop();
          },
          child: const Text('Send Invitation'),
        ),
      ],
    );
  }
}
