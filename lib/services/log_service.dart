import 'dart:async';
import 'package:flutter/foundation.dart';

/// Global log service to capture and display application logs
class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final List<LogEntry> _logs = [];
  final int _maxLogs = 1000; // Limit to prevent memory issues
  final _logController = StreamController<LogEntry>.broadcast();

  Stream<LogEntry> get logStream => _logController.stream;
  List<LogEntry> get logs => List.unmodifiable(_logs);

  void log(String message, {LogLevel level = LogLevel.info}) {
    final entry = LogEntry(message: message, timestamp: DateTime.now(), level: level);

    _logs.add(entry);

    // Remove old logs if we exceed the limit
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }

    _logController.add(entry);

    // Also print to console for DebugView compatibility
    if (kDebugMode) {
      print('[${entry.level.name.toUpperCase()}] ${entry.message}');
    }
  }

  void clear() {
    _logs.clear();
  }

  void dispose() {
    _logController.close();
  }
}

enum LogLevel { debug, info, warning, error }

class LogEntry {
  final String message;
  final DateTime timestamp;
  final LogLevel level;

  LogEntry({required this.message, required this.timestamp, required this.level});

  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }
}
