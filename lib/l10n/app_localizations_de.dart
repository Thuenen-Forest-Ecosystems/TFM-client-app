// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get helloWorld => 'Hallo Welt!';

  @override
  String get language => 'Sprache';

  @override
  String get settings => 'Einstellungen';

  @override
  String get energySaving => 'Energiesparen';

  @override
  String get energySavingDescription =>
      'Reduziere die Helligkeit des Bildschirms';

  @override
  String get authenticationLogin => 'ANMELDEN';
}
