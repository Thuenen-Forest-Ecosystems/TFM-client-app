import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/widgets/dynamic-form.dart';

class DynamicTabBar extends StatefulWidget {
  final Map<dynamic, dynamic> schema;
  final Map<dynamic, dynamic> values;
  final String elementKey;

  const DynamicTabBar({super.key, required this.schema, required this.values, required this.elementKey});

  @override
  State<DynamicTabBar> createState() => _DynamicTabBarState();
}

class _DynamicTabBarState extends State<DynamicTabBar> with TickerProviderStateMixin {
  late Map<dynamic, dynamic> _schema;
  late Map<dynamic, dynamic> _values;
  late String _elementKey;

  late final TabController _tabController;

  @override
  initState() {
    super.initState();
    _schema = widget.schema;
    _values = widget.values;
    _elementKey = widget.elementKey;

    _tabController = TabController(length: _schema.entries.length, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TabBar(
            controller: _tabController,
            tabs: _schema.entries.map((entry) {
              return Tab(
                text: entry.key,
              );
            }).toList(),
          ),
          Expanded(
            child: Container(
              child: TabBarView(
                controller: _tabController,
                children: _schema.entries.map((entry) {
                  return DynamicForm(
                    schema: _schema[entry.key],
                    values: _values,
                    elementKey: entry.key,
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /*@override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: _schema.entries.map((entry) {
            return Tab(
              text: entry.key,
            );
          }).toList(),
        ),
        TabBarView(
          controller: _tabController,
          children: _schema.entries.map((entry) {
            return DynamicForm(
              schema: _schema,
              values: _values,
              elementKey: _elementKey,
            );
          }).toList(),
        ),
      ],
    );
  }*/
}
