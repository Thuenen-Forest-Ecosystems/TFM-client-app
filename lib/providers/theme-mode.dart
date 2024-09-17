import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ThemeModeProvider with ChangeNotifier, DiagnosticableTreeMixin {
  ThemeMode _mode = ThemeMode.dark;

  ThemeModeProvider(this._mode);

  ThemeMode get mode => _mode;

  void setTheme(ThemeMode mode) {
    _mode = mode;
    notifyListeners();
  }

  /// Makes `Counter` readable inside the devtools by listing all of its properties
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('ThemeMode', _mode.toString()));
  }
}
