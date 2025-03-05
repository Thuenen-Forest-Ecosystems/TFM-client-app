import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/providers/map-state.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/widgets/map-navigation.dart';
import 'package:terrestrial_forest_monitor/widgets/support-dialog.dart';

class VertialBar extends StatefulWidget {
  final bool isDrawer;
  VertialBar({super.key, this.isDrawer = false});

  @override
  State<VertialBar> createState() => _VertialBarState();
}

class _VertialBarState extends State<VertialBar> {
  @override
  void initState() {
    super.initState();
    if (widget.isDrawer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<MapState>().openMap();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).primaryColor,
      width: 50,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (context.watch<MapState>().mapOpen || widget.isDrawer)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Container(
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
                  child: IntrinsicHeight(
                    child: MapNavigation(
                      isDrawer: true,
                    ),
                  ),
                ),
              ),
            ),
          if (!context.watch<MapState>().mapOpen && !widget.isDrawer)
            IconButton(
              onPressed: () {
                if (!widget.isDrawer) {
                  context.read<MapState>().openMap();
                } else {
                  Scaffold.of(context).closeDrawer();
                }
              },
              icon: Icon(
                widget.isDrawer ? Icons.close : Icons.map,
                color: Color.fromARGB(255, 27, 27, 27),
              ),
            ),
          IconButton(
            onPressed: () => showDialog<String>(
              context: context,
              builder: (BuildContext context) => SupportDialog(),
            ),
            icon: const Icon(
              Icons.contact_support,
              color: Color.fromARGB(255, 27, 27, 27),
            ),
          ),
        ],
      ),
    );
    /*  child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            onPressed: () => showDialog<String>(
              context: context,
              builder: (BuildContext context) => SupportDialog(),
            ),
            icon: const Icon(
              Icons.contact_support,
              color: Color.fromARGB(255, 27, 27, 27),
            ),
          ),
        ],
      ),
    );*/
    return Container(
      color: Theme.of(context).primaryColor,
      width: 50,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (context.watch<MapState>().mapOpen || widget.isDrawer)
                      MapNavigation(
                        isDrawer: true,
                      ),
                    IconButton(
                      onPressed: () {
                        if (!widget.isDrawer) {
                          context.read<MapState>().toggleMap();
                        } else {
                          Scaffold.of(context).closeDrawer();
                        }
                      },
                      icon: Icon(
                        widget.isDrawer ? Icons.close : Icons.map,
                        color: Color.fromARGB(255, 27, 27, 27),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          /*SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Container(
                      height: 350,
                      width: 50,
                      color: Colors.red,
                    ),
                    Container(
                      height: 350,
                      width: 50,
                      color: Colors.green,
                    ),
                  ],
                ),
              )),
          IconButton(
            onPressed: () => showDialog<String>(
              context: context,
              builder: (BuildContext context) => SupportDialog(),
            ),
            icon: const Icon(
              Icons.contact_support,
              color: Color.fromARGB(255, 27, 27, 27),
            ),
          ),*/
        ],
      ),
    );
    return Container(
      color: Theme.of(context).primaryColor,
      width: 50,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: 250,
                  width: 50,
                  color: Colors.red,
                ),
                Container(
                  height: 250,
                  width: 50,
                  color: Colors.green,
                ),
              ],
            ),
          ),
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
            /*child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (context.watch<MapState>().mapOpen || widget.isDrawer)
                  MapNavigation(
                    isDrawer: true,
                  ),
                IconButton(
                  onPressed: () {
                    if (!widget.isDrawer)
                      context.read<MapState>().toggleMap();
                    else
                      Scaffold.of(context).closeDrawer();
                  },
                  icon: Icon(
                    widget.isDrawer ? Icons.close : Icons.map,
                    color: Color.fromARGB(255, 27, 27, 27),
                  ),
                ),
              ],
            ),*/
          ),
          IconButton(
            onPressed: () => showDialog<String>(
              context: context,
              builder: (BuildContext context) => SupportDialog(),
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
