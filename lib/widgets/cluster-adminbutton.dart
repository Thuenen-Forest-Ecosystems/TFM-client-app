import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/l10n/app_localizations.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClusterAdminButton extends StatefulWidget {
  const ClusterAdminButton({super.key});

  @override
  State<ClusterAdminButton> createState() => _ClusterAdminButtonState();
}

class _ClusterAdminButtonState extends State<ClusterAdminButton> {
  User? user;

  @override
  Widget build(BuildContext context) {
    print('Auth state changed:');
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
                return IconButton(
                  icon: const Icon(Icons.blur_circular),
                  onPressed: () {
                    Beamer.of(context).beamToNamed('/cluster/admin');
                  },
                );
              }
              return const SizedBox();
            },
          );
        }
        return const SizedBox();
      },
    );
  }
}
