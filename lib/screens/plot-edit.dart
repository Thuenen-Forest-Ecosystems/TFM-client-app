import 'package:flutter/material.dart';
import 'package:beamer/beamer.dart';
import 'package:terrestrial_forest_monitor/services/api.dart';
import 'package:terrestrial_forest_monitor/services/utils.dart';
import 'package:terrestrial_forest_monitor/widgets/forms/deadwood.dart';
import 'package:terrestrial_forest_monitor/widgets/forms/edges.dart';
import 'package:terrestrial_forest_monitor/widgets/forms/plot.dart';
import 'dart:convert';

import 'package:terrestrial_forest_monitor/widgets/forms/position.dart';
import 'package:terrestrial_forest_monitor/widgets/forms/regeneration.dart';
import 'package:terrestrial_forest_monitor/widgets/forms/structure.dart';
import 'package:terrestrial_forest_monitor/widgets/forms/wzp.dart';

class PlotEdit extends StatefulWidget {
  final String schemaId;
  final String plotId;
  final String clusterId;
  const PlotEdit({super.key, required this.schemaId, required this.plotId, required this.clusterId});

  @override
  State<PlotEdit> createState() => _PlotEditState();
}

class _PlotEditState extends State<PlotEdit> with TickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TabController _tabController;

  String? _plotId;
  String? _clusterId;
  String? _schemaId;

  Map values = {};

  List<Map> tabs = [];

  void _onUpdate() {
    print('VALIDATE: $values');
  }

  void _initTabs(Map plotJson) {
    tabs = [
      {'title': 'Position', 'icon': Icons.blur_circular, 'screen': TIPosition()},
      {'title': 'Plot', 'icon': Icons.blur_circular, 'screen': TiPlot(plotId: widget.plotId, data: plotJson, onUpdate: _onUpdate)},
      {'title': 'Ränder', 'icon': Icons.blur_circular, 'screen': TIEdges(plotId: widget.plotId, data: [], previousData: [])},
      {'title': 'Totholz', 'icon': Icons.blur_circular, 'screen': TIDeadwood(plotId: widget.plotId, data: plotJson['deadwood'])},
      {'title': 'Winkelzählprobe', 'icon': Icons.blur_circular, 'screen': TIWzp(plotId: widget.plotId, data: plotJson['tree'], onUpdate: _onUpdate)},
      {'title': 'Regeneration', 'icon': Icons.blur_circular, 'screen': TIRegeneration()},
      {'title': 'Struktur', 'icon': Icons.blur_circular, 'screen': TIStructure()},
    ];
    _tabController = TabController(length: tabs.length, vsync: this);
    setState(() {});
  }

  Future<void> _createPlotJson() async {
    values = await plotAsJson(_plotId!);
    _initTabs(values);

    print('-----plotJson------');
    print(values);
  }

  @override
  void initState() {
    super.initState();
    _plotId = widget.plotId;
    _clusterId = widget.clusterId;
    _schemaId = widget.schemaId;

    _createPlotJson();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<dynamic, dynamic>> _loadSampleSchema() async {
    String data = await DefaultAssetBundle.of(context).loadString("assets/sample/schema.json");
    final jsonResult = jsonDecode(data);
    return jsonResult;
  }

  Future<Map<dynamic, dynamic>> _loadSampleData() async {
    return await ApiService().getCluster(_clusterId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Beamer.of(context).beamToNamed('/plot/${widget.schemaId}/${widget.clusterId}/${widget.plotId}');
          },
          icon: Icon(Icons.close),
        ),
        title: ListTile(
          dense: true,
          contentPadding: EdgeInsets.all(0),
          leading: Icon(Icons.blur_circular, size: 40),
          title: Text('Ecke ${widget.plotId}', overflow: TextOverflow.ellipsis, maxLines: 1),
          subtitle: Text('Trakt: ${widget.clusterId}', overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          tabs:
              tabs.map((tab) {
                return Tab(text: tab['title']);
              }).toList(),
        ),
        actions: [
          OutlinedButton.icon(
            label: Text('FERTIG'),
            icon: Stack(children: [Icon(Icons.circle), Positioned(right: 0, left: 0, top: 0, bottom: 0, child: SizedBox(width: 20, height: 20, child: Text('static', style: TextStyle(fontSize: 10, color: Colors.white))))]),
            onPressed: () {},
          ),
          SizedBox(width: 10),
        ],
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          controller: _tabController,
          children:
              tabs.map<Widget>((tab) {
                return tab['screen'] as Widget;
              }).toList(),
        ),
      ),
    );
  }
}
