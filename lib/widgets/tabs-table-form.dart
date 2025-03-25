import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:terrestrial_forest_monitor/widgets/form/datagrid-form-inventory.dart';

class TabsTableForm extends StatefulWidget {
  final Map schema;
  const TabsTableForm({super.key, required this.schema});

  @override
  State<TabsTableForm> createState() => _TabsTableFormState();
}

class _TabsTableFormState extends State<TabsTableForm> with TickerProviderStateMixin {
  late Map<dynamic, dynamic> _schema;
  Map<dynamic, dynamic> _forms = {};
  late final TabController _tabController;

  Map _removeTypeObjectFromProperties(Map srcSchema) {
    // copy schema
    Map schema = Map.from(srcSchema);
    List<dynamic> keysToRemove = [];
    for (var key in schema.keys) {
      if (schema[key] is Map) {
        if (schema[key].containsKey('type') && (schema[key]['type'] == 'object')) {
          // IF ARRAY
          keysToRemove.add(key);
        }
      }
    }
    print(keysToRemove);
    for (var key in keysToRemove) {
      schema.remove(key);
    }
    return schema;
  }

  @override
  initState() {
    super.initState();
    _schema = Map.from(widget.schema['properties']['plot']);

    Map tree = Map.from(_schema['items']['properties']['tree']);
    tree['items']['properties'] = _removeTypeObjectFromProperties(tree['items']['properties']);

    Map deadwood = Map.from(_schema['items']['properties']['deadwood']);
    deadwood['items']['properties'] = _removeTypeObjectFromProperties(deadwood['items']['properties']);

    /*print('plot_landmark');
    print(widget.schema['properties']['plot']['items']['properties']['plot_landmark']);
    Map plot_landmark = Map.from(_schema['items']['properties']['plot_landmark']);
    plot_landmark['properties'] = _removeTypeObjectFromProperties(plot_landmark['properties']);*/

    // copy schema
    Map plot = Map.from(_schema);
    plot['items']['properties'] = _removeTypeObjectFromProperties(plot['items']['properties']);
    plot['items']['properties'].remove('tree');
    plot['items']['properties'].remove('deadwood');
    plot['items']['properties'].remove('position');
    plot['items']['properties'].remove('edges');
    plot['items']['properties'].remove('subplots_relative_position');
    plot['items']['properties'].remove('regeneration');
    plot['items']['properties'].remove('structure_gt4m');
    plot['items']['properties'].remove('structure_lt4m');

    _forms = {
      'plot': {"schema": plot, "values": List<Map<String, dynamic>>.from([])},
      "tree": {"schema": tree, "values": List<Map<String, dynamic>>.from([])},
      "deadwood": {"schema": deadwood, "values": List<Map<String, dynamic>>.from([])},
    };

    _tabController = TabController(length: _forms.entries.length, vsync: this);
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
            tabs:
                _forms.values.map((entry) {
                  return Tab(text: entry['schema']['title']);
                }).toList(),
          ),
          Expanded(
            child: Container(
              child: TabBarView(
                controller: _tabController,
                children:
                    _forms.entries.map((entry) {
                      // Create a new Map<String, dynamic>
                      Map<String, dynamic> properties = {};
                      if (entry.value['schema']['items']['properties'] != null) {
                        (entry.value['schema']['items']['properties'] as Map).forEach((key, value) {
                          properties[key.toString()] = value;
                        });
                      }
                      return DataGridFormInventory(
                        rows: entry.value['values'],
                        columns: properties,
                        onChanged: (rows) {
                          Future.delayed(Duration.zero, () {
                            setState(() {
                              entry.value['values'] = rows;
                            });
                          });
                        },
                      );
                    }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
