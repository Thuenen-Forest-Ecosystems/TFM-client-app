import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class Language with ChangeNotifier, DiagnosticableTreeMixin {
  Locale _locale = const Locale('en');

  List<String> supportedLanguages = ['en', 'de', 'uk'];

  Language(this._locale);

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }

  void watchLanguageChange() async {
    db.watch('SELECT * FROM device_settings WHERE key = \'language\'').listen((event) {
      if (event.isNotEmpty) {
        String languageCountry = event.first['value'];
        Locale newLanguage = Locale('en');
        if (supportedLanguages.contains(languageCountry.split('_')[0])) {
          newLanguage = Locale(languageCountry);
        } else {
          newLanguage = const Locale('en');
        }
        if (_locale != newLanguage) {
          print('newLanguage: $newLanguage');
          _locale = newLanguage;
          notifyListeners();
        }
      }
    });
  }

  /// Makes `Counter` readable inside the devtools by listing all of its properties
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('locale', _locale.toString()));
  }
}
