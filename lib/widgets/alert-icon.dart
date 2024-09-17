import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import the provider package

import 'package:terrestrial_forest_monitor/providers/api-log.dart';

class SystemMessageIcon extends StatefulWidget {
  const SystemMessageIcon({super.key});

  @override
  State<SystemMessageIcon> createState() => _SystemMessageIconState();
}

class _SystemMessageIconState extends State<SystemMessageIcon> {
  @override
  Widget build(BuildContext context) {
    //List<dynamic> log = Provider.of<ApiLog>(context).errorLog; // Use Provider.of instead of context.watch
    List<dynamic> log = context.watch<ApiLog>().errorLog;

    return IconButton(
      onPressed: () {},
      icon: Badge.count(
        isLabelVisible: log.isNotEmpty,
        count: log.length,
        child: const Icon(Icons.message),
      ),
    );
  }
}
