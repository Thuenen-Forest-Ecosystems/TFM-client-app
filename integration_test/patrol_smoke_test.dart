import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

/// Minimal test that exercises Patrol's native automation WITHOUT booting the
/// real app. Run this FIRST after setup to confirm the whole Patrol toolchain
/// is wired up correctly: the Android `PatrolJUnitRunner`, the AndroidX Test
/// Orchestrator, `MainActivityTest.java`, and the Dart <-> native bridge.
///
/// If this passes, the framework is installed correctly, and any failure in
/// `app_test.dart` is about the app — not the test setup.
///
///   patrol test -t integration_test/patrol_smoke_test.dart
void main() {
  patrolTest('patrol native automation is wired up', ($) async {
    await $.pumpWidgetAndSettle(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('patrol-ok'))),
      ),
    );

    expect($('patrol-ok'), findsOneWidget);

    // Drive a native (OS-level) action — the thing plain integration_test
    // cannot do. Going to the home screen proves the native bridge works.
    if (!Platform.isMacOS) {
      await $.platform.mobile.pressHome();
    }
  });
}
