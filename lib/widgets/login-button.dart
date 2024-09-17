import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/widgets/login-dialog.dart';
import 'package:get_storage/get_storage.dart';
import 'package:terrestrial_forest_monitor/services/api.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class LoginButton extends StatefulWidget {
  const LoginButton({super.key});

  @override
  State<LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<LoginButton> {
  Function? disposeListen;

  Map<String, dynamic>? activeUser;

  @override
  void initState() {
    super.initState();

    GetStorage users = GetStorage('Users');
    disposeListen = users.listen(() async {
      _getCurrentUser();
    });
    _getCurrentUser();
  }

  _getCurrentUser() async {
    var user = await ApiService().getLoggedInUser();
    setState(() {
      activeUser = user;
    });
  }

  @override
  void dispose() {
    super.dispose();
    disposeListen!();
  }

  @override
  Widget build(BuildContext context) {
    if (activeUser == null) {
      return ElevatedButton.icon(
        onPressed: () => showDialog<String>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Login'),
            content: LoginDialog(),
          ),
        ),
        icon: Icon(Icons.account_circle),
        label: Text(AppLocalizations.of(context)!.authenticationLogin),
        iconAlignment: IconAlignment.start,
      );
    } else {
      return ElevatedButton.icon(
        onPressed: () => showDialog<String>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Login'),
            content: LoginDialog(),
          ),
        ),
        icon: Icon(Icons.account_circle),
        label: Text(activeUser?['email']),
        iconAlignment: IconAlignment.start,
      );
    }
  }
}
