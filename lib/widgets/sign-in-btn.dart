import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/widgets/sign-in-dialog.dart';

class SignInBtn extends StatefulWidget {
  const SignInBtn({super.key});

  @override
  State<SignInBtn> createState() => _SignInBtnState();
}

class _SignInBtnState extends State<SignInBtn> {
  bool _loggingIn = true;
  User? user;

  @override
  void initState() {
    super.initState();

    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      _loggingIn = false;
      _getUser();
    });
    _getUser();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _getUser() async {
    user = getCurrentUser();
    setState(() {});
  }

  void _openSignInDialog() {
    showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Sign In'),
        content: SignInDialog(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loggingIn) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(),
      );
    } else if (user != null) {
      return const SizedBox();
    } else {
      return ElevatedButton(
        onPressed: _openSignInDialog,
        child: Text('Sign In'),
      );
    }
  }
}
