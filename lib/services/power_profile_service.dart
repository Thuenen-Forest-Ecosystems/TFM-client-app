import 'dart:async';

import 'package:battery_plus/battery_plus.dart';

/// Tracks whether the device is currently running on battery, so power-sensitive
/// subsystems can back off to save energy (e.g. the GPS UI throttle widens from
/// ~1 Hz to ~0.5 Hz, halving map rebuilds while unplugged in the field).
///
/// Defaults to the normal (non-saving) profile and degrades gracefully: devices
/// with no battery (most desktops / CI) or where the plugin is unavailable
/// simply never enter power-save mode, so behaviour is unchanged there.
class PowerProfileService {
  PowerProfileService._();
  static final PowerProfileService instance = PowerProfileService._();

  final Battery _battery = Battery();
  StreamSubscription<BatteryState>? _sub;
  bool _onBattery = false;
  bool _initialized = false;

  /// True when running on battery power (discharging). Callers should reduce
  /// work when this is set.
  bool get powerSaveActive => _onBattery;

  /// Idempotent. Seeds the current state and subscribes to battery changes.
  /// Safe to call early in `main()`; failures (no battery / no plugin) leave
  /// the service on the normal profile.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _apply(await _battery.batteryState);
      _sub = _battery.onBatteryStateChanged.listen(_apply);
    } catch (_) {
      // No battery hardware or plugin unavailable — stay on the normal profile.
      _onBattery = false;
    }
  }

  void _apply(BatteryState state) {
    _onBattery = state == BatteryState.discharging;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _initialized = false;
  }
}
