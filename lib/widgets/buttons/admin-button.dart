import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beamer/beamer.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class AdminButton extends StatefulWidget {
  const AdminButton({super.key});

  @override
  State<AdminButton> createState() => _AdminButtonState();
}

class _AdminButtonState extends State<AdminButton> {
  User? user = getCurrentUser();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: db.get('SELECT * FROM users_profile WHERE user_id = ?', [user?.id]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SizedBox(
              width: 24,
              height: 24,
              child: const CircularProgressIndicator(),
            );
          }
          if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          }
          if (snapshot.hasData) {
            final data = snapshot.data as Map<String, dynamic>;

            if (data['is_admin'] == null || data.isEmpty) {
              return SizedBox();
            }

            if (data['is_admin'] == 1) {
              return IconButton(
                onPressed: () {
                  context.beamToNamed('/admin');
                },
                icon: Icon(Icons.admin_panel_settings),
              );
            }
          }
          return SizedBox();
        });
  }
}
