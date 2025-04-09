// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get helloWorld => 'Hello World!';

  @override
  String get language => 'Language';

  @override
  String get settings => 'Settings';

  @override
  String get energySaving => 'Energy Saving';

  @override
  String get energySavingDescription => 'Reduce the brightness of the screen';

  @override
  String get authenticationLogin => 'LOGIN';
}
