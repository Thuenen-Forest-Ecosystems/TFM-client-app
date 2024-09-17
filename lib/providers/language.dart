import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class Language with ChangeNotifier, DiagnosticableTreeMixin {
  Locale _locale = const Locale('en');

  Language(this._locale);

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }

  /// Makes `Counter` readable inside the devtools by listing all of its properties
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('locale', _locale.toString()));
  }
}
