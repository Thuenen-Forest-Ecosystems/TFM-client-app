import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:beamer/beamer.dart';
import 'package:terrestrial_forest_monitor/providers/auth.dart';

class ProfileIcon extends StatelessWidget {
  const ProfileIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isAuthenticated && authProvider.userEmail != null) {
          return GestureDetector(
            onTap: () => Beamer.of(context).beamToNamed('/profile'),
            child: CircleAvatar(backgroundColor: Colors.grey, radius: 20, child: CircleAvatar(backgroundColor: Theme.of(context).primaryColor, radius: 18, child: const Icon(Icons.person, color: Colors.white, size: 24))),
          );
        } else {
          return ElevatedButton(onPressed: () => Beamer.of(context).beamToNamed('/login'), child: const Text('Login'));
        }
      },
    );
  }
}
