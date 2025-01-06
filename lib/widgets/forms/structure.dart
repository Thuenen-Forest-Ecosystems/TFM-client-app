import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/widgets/form/datatable-from-sqlite-table.dart';

class TIStructure extends StatefulWidget {
  const TIStructure({super.key});

  @override
  State<TIStructure> createState() => _TIStructureState();
}

class _TIStructureState extends State<TIStructure> {
  @override
  Widget build(BuildContext context) {
    return DatatableFromSqliteTable(
      tableName: 'structure_lt4m',
    );
  }
}
