import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kDensePrefKey = 'grid_dense_mode';

/// Manages the grid density preference (normal vs. dense row height).
///
/// Dense mode reduces [rowHeight] from 60 → 36 and cell vertical padding
/// from 8 → 2, making the grid more compact for pen/stylus use on tablets.
///
/// Usage:
/// ```dart
/// // Read current value
/// GridDensityService.isDense
///
/// // Listen for changes (e.g. in initState/dispose of a State)
/// GridDensityService.notifier.addListener(_onDensityChanged);
///
/// // Toggle from settings
/// await GridDensityService.setDense(true);
/// ```
class GridDensityService {
  GridDensityService._();

  static bool _isDense = false;

  /// Live notifier — widgets that need to react can add a listener.
  static final ValueNotifier<bool> notifier = ValueNotifier<bool>(_isDense);

  /// Current density preference.
  static bool get isDense => _isDense;

  /// Row height for the TrinaGrid.
  static double get rowHeight => _isDense ? 36.0 : 60.0;

  /// Column header height for the TrinaGrid.
  static double get columnHeight => _isDense ? 32.0 : 45.0;

  /// Vertical cell padding used in custom cell renderers.
  static double get cellVerticalPadding => _isDense ? 2.0 : 8.0;

  /// Load the saved preference from SharedPreferences.
  /// Call once at app startup (e.g. in main()).
  static Future<void> loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDense = prefs.getBool(_kDensePrefKey) ?? false;
    notifier.value = _isDense;
  }

  /// Persist and apply the density preference.
  static Future<void> setDense(bool value) async {
    _isDense = value;
    notifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDensePrefKey, value);
  }
}
