import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

class TimestampToTimeago extends StatelessWidget {
  final String? timestamp;
  final TextStyle? style;
  TimestampToTimeago({super.key, required this.timestamp, this.style});

  bool agoStyle = false;

  @override
  Widget build(BuildContext context) {
    timeago.setLocaleMessages('de', timeago.DeMessages()); // Add german messages
    if (timestamp == null) {
      return Text('...', style: style);
    } else {
      // Timestamp to Flutter dateTime
      DateTime dataTime = DateTime.parse(timestamp!);
      return GestureDetector(
        child: agoStyle ? Text(timeago.format(dataTime, locale: 'de'), style: style) : Text(dataTime.toIso8601String(), style: style),
        onTap: () {
          print(!agoStyle);
          agoStyle = !agoStyle;
        },
      );
    }
  }
}
