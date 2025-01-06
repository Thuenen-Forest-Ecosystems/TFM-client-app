import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/widgets/form/datatable-from-sqlite-table.dart';

class TIWzp extends StatefulWidget {
  const TIWzp({super.key});

  @override
  State<TIWzp> createState() => _TIWzpState();
}

class _TIWzpState extends State<TIWzp> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: DatatableFromSqliteTable(
        tableName: 'tree',
      ),
    );
  }
}
