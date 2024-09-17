import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/providers/map-state.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/widgets/map-navigation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class VertialBar extends StatefulWidget {
  const VertialBar({super.key});

  @override
  State<VertialBar> createState() => _VertialBarState();
}

class _VertialBarState extends State<VertialBar> {
  PackageInfo? packageInfo;
  String version = '';
  String buildNumber = '';

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future _initPackageInfo() async {
    packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      version = packageInfo!.version;
      buildNumber = packageInfo!.buildNumber;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).primaryColor,
      width: 50,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
              margin: const EdgeInsets.all(5),
              padding: const EdgeInsets.only(
                top: 5,
                bottom: 5,
              ),
              decoration: BoxDecoration(
                color: context.watch<MapState>().mapOpen ? Colors.white : Colors.transparent,
                borderRadius: const BorderRadius.all(
                  Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  if (context.watch<MapState>().mapOpen) const MapNavigation(),
                  IconButton(
                    onPressed: () {
                      context.read<MapState>().toggleMap();
                    },
                    icon: const Icon(
                      Icons.map,
                      color: Color.fromARGB(255, 27, 27, 27),
                    ),
                  ),
                ],
              )),
          IconButton(
            onPressed: () => showDialog<String>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                title: const Text('Thünen Institute'),
                content: Text('Version: ${'$version+$buildNumber'}'),
              ),
            ),
            icon: const Icon(
              Icons.contact_support,
              color: Color.fromARGB(255, 27, 27, 27),
            ),
          ),
        ],
      ),
    );
  }
}
