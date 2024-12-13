import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terrestrial_forest_monitor/providers/api-log.dart';
import 'package:terrestrial_forest_monitor/services/api.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

import 'package:sqlite3/src/result_set.dart' as sqlite;

class LoginDialog extends StatefulWidget {
  const LoginDialog({super.key});

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  bool _loggingIn = false;
  Map<String, dynamic>? _user;
  User? user;
  List<String> errors = [];

  final userNameController = TextEditingController();
  final passwordController = TextEditingController();

  var apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _getUser();
  }

  void _getUser() async {
    user = getCurrentUser();
    //_user = await ApiService().getLoggedInUser();
    setState(() {});
  }

  @override
  void dispose() {
    userNameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // reset Errors after 5 seconds timeout
  void _resetErrors() {
    Future.delayed(Duration(seconds: 15), () {
      setState(() {
        errors.clear();
      });
    });
  }

  _loginRequest(context) async {
    final userName = userNameController.text;
    final password = passwordController.text;

    if (userName.isEmpty || password.isEmpty) {
      setState(() {
        errors.clear();
        errors.add('Username and password are required');
        _resetErrors();
      });
      return;
    }
    setState(() {
      _loggingIn = true;
    });

    try {
      user = await login(userName, password);
      //await apiService.login(userName, password);
      Navigator.of(context).pop();
    } catch (e) {
      print('ERROR: $e');
      setState(() {
        errors.clear();
        passwordController.text = '';
        errors.add(e.toString());
        _resetErrors();
      });
    }

    setState(() {
      _loggingIn = false;
    });
  }

  _logoutRequest() async {
    try {
      await logout();
      //await apiService.logout(_user?['email']);
      //Provider.of<ApiLog>(context, listen: false).changeToken(null);
    } catch (e) {
      print(e);
    }
    _getUser();
  }

  @override
  Widget build(BuildContext context) {
    if (user != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('You are logged in as ${user?.email}'),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(onPressed: _logoutRequest, child: Text('Logout')),
            ],
          ),
        ],
      );
    } else {
      return SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (errors.isNotEmpty)
              ...errors.map(
                (error) => Text(
                  error,
                  style: TextStyle(
                    color: Color.fromRGBO(255, 0, 0, 1),
                    fontSize: 15,
                  ),
                ),
              ),
            SizedBox(height: 20),
            TextFormField(
              controller: userNameController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Username',
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Password',
              ),
            ),
            SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: _loggingIn
                      ? null
                      : () async {
                          _loginRequest(context);
                          //Navigator.of(context).pop();
                        },
                  child: Row(
                    children: [
                      if (_loggingIn)
                        SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(),
                        ),
                      if (_loggingIn) SizedBox(width: 10),
                      Text('ANMELDEN'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }
}
