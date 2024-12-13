import 'package:flutter/material.dart';
import 'package:sqlite3/src/result_set.dart' as sqlite;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terrestrial_forest_monitor/widgets/login-dialog.dart';
import 'package:get_storage/get_storage.dart';
import 'package:terrestrial_forest_monitor/services/api.dart';
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
    if (user == null) {
      return ElevatedButton.icon(
        /*onPressed: () async {
          // TEST ONLY
          sqlite.ResultSet res = await db.getAll('SELECT * FROM lists');
          print(res);
        },*/
        onPressed: () => {
          showDialog<String>(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              title: const Text('Login'),
              content: LoginDialog(),
            ),
          )
        },
        icon: Icon(Icons.account_circle),
        label: Text(AppLocalizations.of(context)!.authenticationLogin),
        iconAlignment: IconAlignment.start,
      );
    } else {
      return ElevatedButton.icon(
        onPressed: () => showDialog<String>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Logout'),
            content: LoginDialog(),
          ),
        ),
        icon: Icon(Icons.account_circle),
        label: Text(user?.email ?? ''),
        iconAlignment: IconAlignment.start,
      );
    }
  }
}
