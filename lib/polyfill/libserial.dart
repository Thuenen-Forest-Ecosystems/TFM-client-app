import 'package:flutter/material.dart';

class SerialPort {
  final String name;
  static List<String> availablePorts = ['dummy'];
  static SerialPortError? lastError;
  SerialPort(this.name);

  bool openReadWrite() {
    return false;
  }
}

class SerialPortError {}

// add more properties and functions as needed

class LibSerial extends StatefulWidget {
  const LibSerial({super.key});

  @override
  State<LibSerial> createState() => _LibSerialState();
}

class _LibSerialState extends State<LibSerial> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
