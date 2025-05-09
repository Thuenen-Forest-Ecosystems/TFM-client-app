import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/providers/api-log.dart';
import 'package:terrestrial_forest_monitor/services/api.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';


class SignInDialog extends StatefulWidget {
  const SignInDialog({super.key});

  @override
  State<SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends State<SignInDialog> {
  bool _loggingIn = false;
  Map<String, dynamic>? _user;
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
    _user = await ApiService().getLoggedInUser();
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
    Future.delayed(Duration(seconds: 5), () {
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

    var response = await signUp(userName, password);

    //sqlite.ResultSet res = await db.getAll('SELECT * FROM lists');

    /*Error response = await apiService.login(userName, password);

    if (response.data['token'] != null) {
      Navigator.of(context).pop();
      Provider.of<ApiLog>(context, listen: false).changeToken(response.data['token']);
    } else {
      print('ERROR');
      setState(() {
        errors.clear();
        passwordController.text = '';
        errors.add(response.message);
        _resetErrors();
      });
    }*/

    setState(() {
      _loggingIn = false;
    });
  }

  _logoutRequest() async {
    try {
      await apiService.logout(_user?['email']);
      Provider.of<ApiLog>(context, listen: false).changeToken(null);
      //Beamer.of(context).beamToNamed('/');
      //Navigator.popUntil(context, ModalRoute.withName('/'));
    } catch (e) {
      print(e);
    }
    _getUser();
  }

  @override
  Widget build(BuildContext context) {
    if (_user != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('You are logged in as ${_user?['email']}'),
          SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [ElevatedButton(onPressed: _logoutRequest, child: Text('Logout'))]),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (errors.isNotEmpty) ...errors.map((error) => Text(error, style: TextStyle(color: Color.fromRGBO(255, 0, 0, 1), fontSize: 15))),
          SizedBox(height: 20),
          TextFormField(controller: userNameController, decoration: InputDecoration(border: OutlineInputBorder(), labelText: 'Username')),
          SizedBox(height: 20),
          TextField(controller: passwordController, obscureText: true, decoration: InputDecoration(border: OutlineInputBorder(), labelText: 'Password')),
          SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed:
                    _loggingIn
                        ? null
                        : () async {
                          _loginRequest(context);
                          //Navigator.of(context).pop();
                        },
                child: Row(children: [if (_loggingIn) SizedBox(width: 15, height: 15, child: CircularProgressIndicator()), if (_loggingIn) SizedBox(width: 10), Text('Login')]),
              ),
            ],
          ),
        ],
      );
    }
  }
}
