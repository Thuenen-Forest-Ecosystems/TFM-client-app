import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/widgets/form/datatable-from-sqlite-table.dart';

class TIEdges extends StatefulWidget {
  const TIEdges({super.key});

  @override
  State<TIEdges> createState() => _TIEdgesState();
}

class _TIEdgesState extends State<TIEdges> {
  @override
  Widget build(BuildContext context) {
    return DatatableFromSqliteTable(
      tableName: 'edges',
    );
  }
}
