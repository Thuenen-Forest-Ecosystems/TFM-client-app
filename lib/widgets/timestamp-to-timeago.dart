import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

class TimestampToTimeago extends StatelessWidget {
  final String timestamp;
  const TimestampToTimeago({super.key, required this.timestamp});

  @override
  Widget build(BuildContext context) {
    timeago.setLocaleMessages('de', timeago.DeMessages()); // Add german messages

    // Timestamp to Flutter dateTime
    DateTime _dataTime = DateTime.parse(timestamp);
    return Text(timeago.format(_dataTime, locale: 'de'));
  }
}
