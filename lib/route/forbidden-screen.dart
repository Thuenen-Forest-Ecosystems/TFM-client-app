import 'package:flutter/material.dart';

class ForbiddenScreen extends StatelessWidget {
  const ForbiddenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.warning,
            size: 100,
            color: Colors.red,
          ),
          Text(
            '403 Forbidden',
            style: TextStyle(fontSize: 30),
          ),
          Text(
            'You are not allowed to access this page.',
            style: TextStyle(fontSize: 20),
          ),
        ],
      ),
    );
  }
}
