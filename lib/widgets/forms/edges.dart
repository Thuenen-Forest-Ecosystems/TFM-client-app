import 'package:flutter/material.dart';

class TIEdges extends StatefulWidget {
  final String plotId;
  final List<Map<dynamic, dynamic>> data;
  final List<Map<dynamic, dynamic>> previousData;
  const TIEdges({super.key, required this.plotId, required this.data, this.previousData = const []});

  @override
  State<TIEdges> createState() => _TIEdgesState();
}

class _TIEdgesState extends State<TIEdges> {
  @override
  Widget build(BuildContext context) {
    return Text('data: ${widget.data}');
  }
}
