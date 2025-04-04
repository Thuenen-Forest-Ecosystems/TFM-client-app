import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terrestrial_forest_monitor/widgets/login-dialog.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:terrestrial_forest_monitor/services/powersync.dart';

class LoginButton extends StatefulWidget {
  const LoginButton({super.key});

  @override
  State<LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<LoginButton> {
  bool _loggingIn = true;
  User? user;

  // Small screen width threshold in logical pixels
  final double _smallScreenThreshold = 600;

  @override
  void initState() {
    super.initState();

    _loggingIn = true;

    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      _loggingIn = false;
      _getUser();
    });
    _getUser();
  }

  void _getUser() async {
    user = getCurrentUser();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Get current screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < _smallScreenThreshold;

    if (user == null) {
      // User not logged in
      return isSmallScreen
          // Small screen - icon only
          ? IconButton(
            onPressed: () => {showDialog<String>(context: context, builder: (BuildContext context) => AlertDialog(title: const Text('Login'), content: LoginDialog()))},
            icon: Icon(Icons.account_circle),
            tooltip: AppLocalizations.of(context)!.authenticationLogin,
          )
          // Normal screen - icon and text
          : ElevatedButton.icon(
            onPressed: () => {showDialog<String>(context: context, builder: (BuildContext context) => AlertDialog(title: const Text('Login'), content: LoginDialog()))},
            icon: Icon(Icons.account_circle),
            label: Text(AppLocalizations.of(context)!.authenticationLogin),
            iconAlignment: IconAlignment.start,
          );
    } else {
      // User logged in
      return isSmallScreen
          // Small screen - icon only
          ? IconButton(onPressed: () => showDialog<String>(context: context, builder: (BuildContext context) => AlertDialog(title: const Text('Logout'), content: LoginDialog())), icon: Icon(Icons.account_circle), tooltip: user?.email ?? '')
          // Normal screen - icon and text
          : ElevatedButton.icon(
            onPressed: () => showDialog<String>(context: context, builder: (BuildContext context) => AlertDialog(title: const Text('Logout'), content: LoginDialog())),
            icon: Icon(Icons.account_circle),
            label: Text(user?.email ?? ''),
            iconAlignment: IconAlignment.start,
          );
    }
  }
}
