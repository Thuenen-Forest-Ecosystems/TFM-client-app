import 'package:flutter/material.dart';
//import 'package:terrestrial_forest_monitor/widgets/form/ediable-datatable-from-sqlite-table.dart';

class TIDeadwood extends StatefulWidget {
  final String plotId;
  final List<Map<dynamic, dynamic>> data;
  const TIDeadwood({super.key, required this.plotId, required this.data});

  @override
  State<TIDeadwood> createState() => _TIDeadwoodState();
}

class _TIDeadwoodState extends State<TIDeadwood> {
  @override
  Widget build(BuildContext context) {
    return Text('Deadwood');
  }
}
