import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/screens/verticalbar.dart';
import 'package:terrestrial_forest_monitor/widgets/map.dart';

class TfmDrawer extends StatelessWidget {
  const TfmDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const VertialBar(),
        Container(
          color: Color.fromRGBO(150, 150, 150, 1),
          width: 250,
          child: const TFMMap(),
        )
      ],
    );
  }
}
