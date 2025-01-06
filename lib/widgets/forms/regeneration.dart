import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/widgets/form/datatable-from-sqlite-table.dart';

class TIRegeneration extends StatefulWidget {
  const TIRegeneration({super.key});

  @override
  State<TIRegeneration> createState() => _TIRegenerationState();
}

class _TIRegenerationState extends State<TIRegeneration> {
  @override
  Widget build(BuildContext context) {
    return DatatableFromSqliteTable(
      tableName: 'regeneration',
    );
  }
}
