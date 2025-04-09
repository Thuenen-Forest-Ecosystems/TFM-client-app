import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terrestrial_forest_monitor/l10n/app_localizations.dart';
import 'package:terrestrial_forest_monitor/widgets/login-dialog.dart';

import 'package:terrestrial_forest_monitor/services/powersync.dart';

class OrganizationsButton extends StatefulWidget {
  const OrganizationsButton({super.key});

  @override
  State<OrganizationsButton> createState() => _OrganizationsButtonState();
}

class _OrganizationsButtonState extends State<OrganizationsButton> {
  User? user;

  // Small screen width threshold in logical pixels
  final double _smallScreenThreshold = 600;

  @override
  Widget build(BuildContext context) {
    print('Auth state changed: Access Management');
    // Get current screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < _smallScreenThreshold;

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
