import 'package:flutter/material.dart';

class TreeOverview extends StatefulWidget {
  final Map plot;
  const TreeOverview({super.key, required this.plot});

  @override
  State<TreeOverview> createState() => _TreeOverviewState();
}

class _TreeOverviewState extends State<TreeOverview> {
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Winkelzählprobe'), Text('Tree: ${widget.plot['tree'] != null ? widget.plot['tree'].length : 'N/A'}')]));
  }
}
