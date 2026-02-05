import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:terrestrial_forest_monitor/screens/inventory/schema-selection.dart';
import 'package:terrestrial_forest_monitor/widgets/sync-status-button.dart';
import 'package:beamer/beamer.dart';

class Schema extends StatefulWidget {
  const Schema({super.key});

  @override
  State<Schema> createState() => _SchemaState();
}

class _SchemaState extends State<Schema> {
  @override
  Widget build(BuildContext context) {
    // add Logo THUENEN_SCREEN_Black.svg
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: SvgPicture.asset('assets/logo/THUENEN_SCREEN_Black.svg', height: 50),
        actions: [
          const SyncStatusButton(),
          //SizedBox(width: 5),
          IconButton(
            onPressed: () => Beamer.of(context).beamToNamed('/profile'),
            icon: Icon(Icons.settings),
          ),
        ],
      ),
      body: const SafeArea(child: Center(child: SchemaSelection())),
    );
  }
}
