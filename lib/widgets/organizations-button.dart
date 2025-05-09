import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:terrestrial_forest_monitor/services/powersync.dart';

class OrganizationsButton extends StatefulWidget {
  const OrganizationsButton({super.key});

  @override
  State<OrganizationsButton> createState() => _OrganizationsButtonState();
}

class _OrganizationsButtonState extends State<OrganizationsButton> {
  User? user;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          user = getCurrentUser();
          if (user == null) {
            return SizedBox();
          }

          return FutureBuilder(
            future: db.get('SELECT * FROM users_profile WHERE id = ? ', [user?.id]),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                final userProfile = snapshot.data;
                //bool isAdmin = (userProfile as Map<String, dynamic>)['is_admin'] == 1;
                //int? stateResponsible = (userProfile as Map<String, dynamic>)['state_responsible'] ?? null;
                String? rootOrganizationId = (userProfile as Map<String, dynamic>)['organization_id'];
                if (rootOrganizationId != null) {
                  return OutlinedButton.icon(
                    icon: Icon(Icons.people),
                    onPressed: () async {
                      context.beamToNamed('/organizations');
                    },
                    label: const Text('Access Management'),
                  );
                } else {
                  return SizedBox();
                }
              }
              return SizedBox();
            },
          );
        }
        return SizedBox();
      },
    );
  }
}
