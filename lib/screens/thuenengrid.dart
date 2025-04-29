import 'dart:async';

import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/libraries/globals.dart' as globals;
import 'package:terrestrial_forest_monitor/services/api.dart';
import 'dart:math';

import 'package:terrestrial_forest_monitor/services/powersync.dart';

class ThuenenGrid extends StatefulWidget {
  const ThuenenGrid({super.key});

  @override
  State<ThuenenGrid> createState() => _ThuenenGridState();
}

class _ThuenenGridState extends State<ThuenenGrid> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildGrid(rawdata, width) {
    List data = rawdata.where((element) => element['is_visible'] == 1).toList();
    return GridView.builder(
      reverse: true,
      primary: false,
      padding: EdgeInsets.only(left: width > 800 ? 100 : 10),
      itemCount: data.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: width > 800 ? min(3, 2) : (width > 400 ? 2 : 1)),
      itemBuilder: (BuildContext context, int index) {
        return InkWell(
          child: Container(
            padding: const EdgeInsets.all(8),
            color: globals.thuenenColors[index % 5],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(data[index]['title'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                Text(data[index]['description'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.white), textAlign: TextAlign.center),
              ],
            ),
          ),
          onTap: () {
            Beamer.of(context).beamToNamed('/schema/${data[index]['id']}');
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.sizeOf(context).width;
    return StreamBuilder(
      stream: db.watch('SELECT * FROM schemas'),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          if (snapshot.data!.isEmpty) {
            return Center(child: Text('No SCHEMA available'));
          } else {
            return _buildGrid(snapshot.data, width);
          }
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
