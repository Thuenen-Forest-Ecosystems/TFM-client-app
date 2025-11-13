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
  User? user; //getCurrentUser();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        context.beamToNamed('/admin');
      },
      icon: Icon(Icons.admin_panel_settings),
    );
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
                if (true) {
                  return IconButton(
                    onPressed: () {
                      context.beamToNamed('/admin');
                    },
                    icon: Icon(Icons.admin_panel_settings),
                  );
                } else {
                  return SizedBox();
                }
              } else {
                print('snapshot: ${snapshot.error} ${user.id}');
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
