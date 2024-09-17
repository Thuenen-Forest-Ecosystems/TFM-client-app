import 'package:flutter/material.dart';

class GnssSerialSelection extends StatefulWidget {
  const GnssSerialSelection({super.key});

  @override
  State<GnssSerialSelection> createState() => _GnssSerialSelectionState();
}

class _GnssSerialSelectionState extends State<GnssSerialSelection> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10.0),
      child: Text('GNSS is only supported on Android and Windows!'),
    );
  }
}
