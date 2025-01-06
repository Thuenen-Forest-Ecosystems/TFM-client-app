import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/widgets/form/datatable-from-sqlite-table.dart';

class TIDeadwood extends StatefulWidget {
  const TIDeadwood({super.key});

  @override
  State<TIDeadwood> createState() => _TIDeadwoodState();
}

class _TIDeadwoodState extends State<TIDeadwood> {
  @override
  Widget build(BuildContext context) {
    return DatatableFromSqliteTable(
      tableName: 'deadwood',
    );
  }
}
