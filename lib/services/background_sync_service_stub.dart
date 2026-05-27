// Stub for workmanager types on web platform
import 'package:flutter/foundation.dart';

class Workmanager {
  Future<void> initialize(Function callback, {bool isInDebugMode = false}) async {
  }

  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    Duration? frequency,
    Constraints? constraints,
  }) async {
  }

  Future<void> registerOneOffTask(
    String uniqueName,
    String taskName, {
    Duration? initialDelay,
    Constraints? constraints,
  }) async {
  }

  Future<void> cancelAll() async {
  }

  Future<void> cancelByUniqueName(String uniqueName) async {
  }

  void executeTask(Function callback) {
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
