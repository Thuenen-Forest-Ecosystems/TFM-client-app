import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class LookupOutput extends StatefulWidget {
  final String value;
  final String lookupTable;
  final String? comment;
  const LookupOutput({super.key, required this.value, required this.lookupTable, this.comment});

  @override
  State<LookupOutput> createState() => _LookupOutputState();
}

class _LookupOutputState extends State<LookupOutput> {
  List<String> _pgValue = [];

  @override
  Widget build(BuildContext context) {
    // convert postgres arrays to dart lists
    if (widget.value.startsWith('{')) {
      _pgValue = widget.value.substring(1, widget.value.length - 1).split(',');
    } else {
      _pgValue = [widget.value];
    }

    return Container(
      margin: EdgeInsets.all(10),
      child: FutureBuilder(
        future: db.getAll('SELECT * FROM ${widget.lookupTable} WHERE abbreviation IN (${_pgValue.map((e) => '?').join(',')})', _pgValue),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasData) {
              List<Map> data = snapshot.data;
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (var item in data) Text(item['name_de']), Divider(thickness: 2, height: 2), Text(widget.comment ?? '', style: TextStyle(fontSize: 13))]);
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else {
              return Text('No data');
            }
          } else {
            return Text('Loading...');
          }
        },
      ),
    );
  }
}
