import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/libraries/globals.dart' as globals;
import 'package:get_storage/get_storage.dart';
import 'package:terrestrial_forest_monitor/services/api.dart';
import 'dart:math';

class ThuenenGrid extends StatefulWidget {
  const ThuenenGrid({super.key});

  @override
  State<ThuenenGrid> createState() => _ThuenenGridState();
}

class _ThuenenGridState extends State<ThuenenGrid> {
  Function? disposeListen;

  Map<String, dynamic>? activeUser;

  List schemata = [];
  List _filteredSchemata = [];

  @override
  void initState() {
    super.initState();

    GetStorage users = GetStorage('Users');
    disposeListen = users.listen(() async {
      _getSchemata();
    });
    _getSchemata();
  }

  @override
  void dispose() {
    super.dispose();
    disposeListen!();
  }

  void _filterSchemata() {}
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

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.sizeOf(context).width;

    return Container(
      margin: const EdgeInsets.only(top: 0, left: 20, right: 0),
      child: GridView.builder(
        reverse: true,
        primary: false,
        padding: EdgeInsets.only(left: width > 800 ? 100 : 10),
        itemCount: _filteredSchemata.length,
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
                    _filteredSchemata[index]['schema_name'] ?? '',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    _filteredSchemata[index]['description'] ?? '',
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
              //Navigator.pushNamed(context, '/monitor/dfgsdgfdfg', arguments: ThuenenArguments(schemata[index]['schema_name']));
              //Navigator.pushNamed(context, '/settings');
              Beamer.of(context).beamToNamed('/schema/${_filteredSchemata[index]['schema_name']}');

              // Navigator.pushNamed(context, '/monitor/${schemata[index]['schema_name']}');

              ///Navigator.pushNamed(context, '/thuenen/inventory2', arguments: ThuenenArguments(schemata[index]['schema_name']));
            },
          );
        },
      ),
    );
  }
}
