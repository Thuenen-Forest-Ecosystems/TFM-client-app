import 'package:flutter/material.dart';

class TiPlot extends StatefulWidget {
  final String plotId;
  final Map<dynamic, dynamic> data;
  final Map<dynamic, dynamic> previousData;
  final Function? onUpdate;
  TiPlot({super.key, required this.plotId, required this.data, this.previousData = const {}, this.onUpdate});

  @override
  State<TiPlot> createState() => _TiPlotState();
}

class _TiPlotState extends State<TiPlot> {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              labelText: 'Plot Name',
            ),
            controller: TextEditingController(text: widget.data['plot_name']),
            readOnly: false,
            onChanged: (value) {
              widget.data['plot_name'] = value;
              if (widget.onUpdate != null) {
                widget.onUpdate!();
              }
            },
          )
        ],
      ),
    );
  }
}
