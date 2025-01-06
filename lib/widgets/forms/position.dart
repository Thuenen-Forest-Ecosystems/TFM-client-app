import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/widgets/form/datatable-from-sqlite-table.dart';

class TIPosition extends StatefulWidget {
  const TIPosition({super.key});

  @override
  State<TIPosition> createState() => _TIPositionState();
}

class _TIPositionState extends State<TIPosition> {
  @override
  Widget build(BuildContext context) {
    return DatatableFromSqliteTable(
      tableName: 'position',
    );
  }
}
