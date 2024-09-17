import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/api.dart';
import 'package:terrestrial_forest_monitor/widgets/breadcrumb.dart';
import 'package:terrestrial_forest_monitor/widgets/table-from-json2.dart';

class Plots extends StatefulWidget {
  final String clusterId;
  const Plots({super.key, required this.clusterId});

  @override
  State<Plots> createState() => _PlotsState();
}

class _PlotsState extends State<Plots> {
  late String _clusterId;
  String _viewType = 'table';
  double _tuneHeight = 0;

  @override
  initState() {
    super.initState();
    _clusterId = widget.clusterId;
  }

  Future _refreshData() async {
    return await ApiService().getCluster(_clusterId);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BreadCrumb(),
        AppBar(
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
          title: SizedBox(
            height: 35,
            child: TextFormField(
              decoration: InputDecoration(
                hintText: 'Search... (ToDo: Fulltext search)',
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10.0),
                prefixIcon: Icon(Icons.search),
                // Hide borders
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(25),
                ),
                fillColor: Color.fromARGB(100, 27, 27, 27),
                filled: true,
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.tune),
              onPressed: () {
                setState(() {
                  _tuneHeight = _tuneHeight == 0 ? 100 : 0;
                });
              },
            ),
            if (_viewType == 'list')
              IconButton(
                icon: Icon(Icons.list),
                onPressed: () {
                  setState(() {
                    _viewType = 'table';
                  });
                },
              ),
            if (_viewType == 'table')
              IconButton(
                icon: Icon(Icons.apps),
                onPressed: () {
                  setState(() {
                    _viewType = 'list';
                  });
                },
              ),
          ],
        ),
        AnimatedContainer(
          duration: Duration(
            milliseconds: 200,
          ),
          width: double.infinity,
          height: _tuneHeight,
          padding: EdgeInsets.all(10),
          color: Color.fromARGB(100, 100, 100, 100),
          child: const Text('TODO: Filters & Sort'),
        ),
        Expanded(
          child: FutureBuilder(
            future: _refreshData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(),
                );
              } else if (snapshot.hasError) {
                return Center(
                  child: Text('Error: Cluster $_clusterId does not exist.'),
                );
              } else if (!snapshot.hasData || snapshot.data == null) {
                return Center(
                  child: Text('No data'),
                );
              }

              return Container(
                padding: EdgeInsets.all(10),
                child: TableFromJson2(
                  data: snapshot.data['plot'] ?? [],
                  parentPath: '/schema/private_ci2027_001/$_clusterId',
                ),
              );
            },
          ),
        )
      ],
    );
  }
}
