import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      final FunctionResponse response = await Supabase.instance.client.functions.invoke(
        'invite-user',
        body: jsonEncode({
          'email': emailController.text,
          'metaData': {'organization_id': widget.parentOrganizationId},
        }),
      );
      if (response.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invitation sent successfully')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending invitation1: ${response.data['error']}')));
      }
    } catch (e) {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending invitation: $e')));
    } finally {
      // Optionally clear the text field or perform other actions
      emailController.clear();
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
