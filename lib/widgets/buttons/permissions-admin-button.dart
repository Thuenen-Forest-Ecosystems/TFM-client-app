import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beamer/beamer.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class PermissionsAdminButton extends StatefulWidget {
  const PermissionsAdminButton({super.key});

  @override
  State<PermissionsAdminButton> createState() => _PermissionsAdminButtonState();
}

class _PermissionsAdminButtonState extends State<PermissionsAdminButton> {
  User? user;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          User? user = getCurrentUser();

          if (user == null) {
            return SizedBox();
          }

          return FutureBuilder(
            future: db.get('SELECT * FROM users_profile WHERE id = ?', [user.id]),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final data = snapshot.data as Map<String, dynamic>;

                if (data['state_responsible'] == null || data.isEmpty) {
                  return SizedBox();
                }

                return IconButton(
                  onPressed: () {
                    context.beamToNamed('/admin-permissions');
                  },
                  icon: Icon(Icons.group),
                );
              }
              return SizedBox();
            },
          );
        } else {
          return SizedBox();
        }
      },
    );
  }
}
