import 'dart:async';

import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:powersync/sqlite3_common.dart';
import 'package:terrestrial_forest_monitor/libraries/globals.dart' as globals;
import 'package:get_storage/get_storage.dart';
import 'package:terrestrial_forest_monitor/services/api.dart';
import 'dart:math';

import 'package:terrestrial_forest_monitor/services/powersync.dart';

class ThuenenGrid extends StatefulWidget {
  const ThuenenGrid({super.key});

  @override
  State<ThuenenGrid> createState() => _ThuenenGridState();
}

class _ThuenenGridState extends State<ThuenenGrid> {
  StreamSubscription? dbSubscription;

  bool _loading = true;
  String? _errorText;

  Map<String, dynamic>? activeUser;

  List schemata = [];
  List _filteredSchemata = [];

  void _getTest() async {
    var testdata = await db.getAll('SELECT * FROM Test');
    print('TEST');
    print(testdata);
  }

  @override
  void initState() {
    super.initState();
    //GetStorage users = GetStorage('Users');
    dbSubscription = db.watch('SELECT * FROM schemas').listen((results) {
      print('schemadata');
      print(results);
      schemata = results;
      _loading = false;
    }, onError: (e) {
      print('Query failed: $e');
      _errorText = e.toString();
    });
    _getTest();
  }

  @override
  void dispose() {
    super.dispose();
    dbSubscription?.cancel();
  }

  void _getSchemata() async {
    var user = await ApiService().getLoggedInUser();
    setState(() {
      activeUser = user;
      if (activeUser != null && activeUser!.containsKey('schemata')) {
        schemata = activeUser!['schemata'];
        _filteredSchemata = schemata.where((schema) => schema['schema_name'].startsWith('private_')).toList();
      }
    });
  }

  Widget _buildGrid(rawdata, width) {
    // filter rawdata by is_visible attribute
    List data = rawdata.where((element) => element['is_visible'] == 1).toList();
    print(rawdata);
    return GridView.builder(
      reverse: true,
      primary: false,
      padding: EdgeInsets.only(left: width > 800 ? 100 : 10),
      itemCount: data.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: width > 800 ? min(3, 2) : (width > 400 ? 2 : 1),
      ),
      itemBuilder: (BuildContext context, int index) {
        return InkWell(
          child: Container(
            padding: const EdgeInsets.all(8),
            color: globals.thuenenColors[index % 5],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  data[index]['title'] ?? '',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  data[index]['description'] ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
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
        if (snapshot.hasData) {
          return _buildGrid(snapshot.data, width);
        } else if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        } else {
          return Center(
            child: CircularProgressIndicator(),
          );
        }
      },
    );
  }
}
