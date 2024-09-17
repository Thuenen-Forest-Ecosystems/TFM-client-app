import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/providers/map-state.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/widgets/map-navigation.dart';

class VertialBar extends StatelessWidget {
  const VertialBar({super.key});

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
              builder: (BuildContext context) => AlertDialog(title: const Text('Thünen Institute'), content: const Text('AlertDialog description')),
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
