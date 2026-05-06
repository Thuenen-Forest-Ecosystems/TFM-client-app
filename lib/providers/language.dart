import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

const _kLangPrefKey = 'app_language';

/// Supported explicit language codes plus the special 'system' sentinel.
const _kSupported = ['en', 'de'];

/// Resolves a raw code (including 'system') to an actual [Locale].
Locale _resolveLocale(String code) {
  if (code == 'system') {
    final systemCode = SchedulerBinding.instance.platformDispatcher.locale.languageCode;
    return Locale(_kSupported.contains(systemCode) ? systemCode : 'en');
  }
  return Locale(_kSupported.contains(code) ? code : 'en');
}

class Language with ChangeNotifier, DiagnosticableTreeMixin {
  /// The raw preference code: 'de', 'en', or 'system'.
  String _selectedCode;

  /// The effective [Locale] used by the app.
  Locale _locale;

  List<String> supportedLanguages = ['en', 'de', 'uk'];

  Language(Locale initialLocale)
    : _selectedCode = initialLocale.languageCode,
      _locale = initialLocale;

  Locale get locale => _locale;

  /// The raw stored code ('de', 'en', or 'system').
  String get selectedCode => _selectedCode;

  void setLocale(Locale locale) {
    final code = locale.languageCode; // 'de', 'en', or 'system'
    _selectedCode = code;
    _locale = _resolveLocale(code);
    notifyListeners();
    _savePreference(code);
  }

  Future<void> _savePreference(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLangPrefKey, code);
  }

  /// Load saved language from SharedPreferences.
  /// Falls back to [fallback] if nothing is saved.
  static Future<Locale> loadSavedLocale(String systemCode) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLangPrefKey);
    if (saved != null) {
      return _resolveLocale(saved);
    }
    // No saved preference: use system language if supported, else 'en'.
    return Locale(_kSupported.contains(systemCode) ? systemCode : 'en');
  }

  void watchLanguageChange() async {
    db.watch('SELECT * FROM device_settings WHERE key = \'language\'').listen((event) {
      // Only apply the DB-driven locale when the user has not explicitly
      // chosen a language via the settings UI (i.e. preference is 'system').
      if (_selectedCode != 'system') return;

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

  /// Makes `Language` readable inside the devtools by listing all of its properties
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('locale', _locale.toString()));
    properties.add(StringProperty('selectedCode', _selectedCode));
  }
}
