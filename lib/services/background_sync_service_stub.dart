// Stub for workmanager types on web platform
import 'package:flutter/foundation.dart';

class Workmanager {
  Future<void> initialize(Function callback, {bool isInDebugMode = false}) async {
    debugPrint('Workmanager stub: initialize called');
  }

  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    Duration? frequency,
    Constraints? constraints,
  }) async {
    debugPrint('Workmanager stub: registerPeriodicTask called');
  }

  Future<void> registerOneOffTask(
    String uniqueName,
    String taskName, {
    Duration? initialDelay,
    Constraints? constraints,
  }) async {
    debugPrint('Workmanager stub: registerOneOffTask called');
  }

  Future<void> cancelAll() async {
    debugPrint('Workmanager stub: cancelAll called');
  }

  Future<void> cancelByUniqueName(String uniqueName) async {
    debugPrint('Workmanager stub: cancelByUniqueName called');
  }

  void executeTask(Function callback) {
    debugPrint('Workmanager stub: executeTask called');
  }
}

class Constraints {
  final NetworkType? networkType;
  final bool? requiresBatteryNotLow;

  Constraints({this.networkType, this.requiresBatteryNotLow});
}

class NetworkType {
  static const connected = NetworkType._('connected');

  final String value;
  const NetworkType._(this.value);
}

Workmanager workmanagerStub() => Workmanager();
