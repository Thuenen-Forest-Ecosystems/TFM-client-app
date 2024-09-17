import 'package:flutter/material.dart';

class Error404 extends StatelessWidget {
  const Error404({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            '404 Forbidden',
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
