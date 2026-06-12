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

  @override
  String get profileTitle => 'Einstellungen';

  @override
  String get profileMapManagement => 'Kartenverwaltung';

  @override
  String get profileLayoutSettings => 'Layout-Einstellungen';

  @override
  String get profileLanguageSettings => 'Spracheinstellungen';

  @override
  String get profileKeyboardSettings => 'Keyboard-Einstellungen';

  @override
  String get profileCompactMode => 'Kompakter Modus';

  @override
  String get profileNetwork => 'Netzwerk';

  @override
  String get profileProxySettings => 'Proxy-Einstellungen';

  @override
  String get profileProxySubtitle => 'Konfiguration für Landesdatennetze';

  @override
  String get profileResetSettings => 'Einstellungen zurücksetzen';

  @override
  String get profileResetTitle => 'Einstellungen zurücksetzen?';

  @override
  String get profileResetContent =>
      'Folgende lokale Einstellungen werden gelöscht:\n\n• Kompakter Modus\n• Tastatur-Einstellung\n• Spaltenbreiten in Tabellen\n• Filter-Zustände\n• Zuletzt genutzte Enum-Werte\n• Karteneinstellungen\n\nServer-, Organisations- und Proxy-Einstellungen bleiben erhalten.';

  @override
  String get profileResetCancel => 'Abbrechen';

  @override
  String get profileResetConfirm => 'Zurücksetzen';

  @override
  String get profileResetSnackbar => 'Einstellungen wurden zurückgesetzt.';

  @override
  String get profileLogoutTitle => 'Abmelden und Daten löschen?';

  @override
  String get profileLogoutContent =>
      'Alle lokalen Daten werden unwiderruflich gelöscht.\n\nNicht synchronisierte Einträge gehen verloren und können nicht wiederhergestellt werden.\n\nBitte stellen Sie sicher, dass alle Daten synchronisiert wurden, bevor Sie fortfahren.';

  @override
  String get profileLogoutCancel => 'Abbrechen';

  @override
  String get profileLogoutConfirm => 'Löschen und abmelden';

  @override
  String get profileLoggingIn => 'Abmelden…';

  @override
  String get profileLogoutOffline => 'Abmelden (offline nicht möglich)';

  @override
  String get profileLogout => 'Abmelden und Daten löschen';

  @override
  String get profileImprint => 'Impressum';

  @override
  String get profilePrivacy => 'Datenschutzbestimmungen';

  @override
  String profileAppVersion(String version, String build) {
    return 'App Version: $version ($build)';
  }

  @override
  String get profileShowRecords => 'Records anzeigen';

  @override
  String get profileShowSyncedTables => 'Synced Tables anzeigen';

  @override
  String get profileShowLogs => 'Protokolle anzeigen';

  @override
  String get langDe => 'Deutsch';

  @override
  String get langDeSubtitle => '';

  @override
  String get langEn => 'Englisch';

  @override
  String get langEnSubtitle => '(BETA) noch nicht vollständig übersetzt';

  @override
  String get langSystem => 'System';

  @override
  String get langSystemSubtitle => 'Systemsprache verwenden';

  @override
  String get enumDialogSearch => 'Suchen…';

  @override
  String get enumDialogRecentlyUsed => 'Zuletzt genutzt';

  @override
  String get enumDialogListView => 'Listenansicht';

  @override
  String get enumDialogChipsView => 'Chips-Ansicht';

  @override
  String get enumDialogClose => 'Schließen';

  @override
  String get enumDialogNoResults => 'Keine Ergebnisse gefunden';

  @override
  String get enumDialogClearField => 'Inhalt des Feldes löschen';

  @override
  String get gridRowOptions => 'Zeilenoptionen';

  @override
  String get gridRowEdit => 'Zeile bearbeiten';

  @override
  String get gridRowCopy => 'Zeile kopieren';

  @override
  String get gridRowDelete => 'Zeile löschen';

  @override
  String get gridBoolYes => 'Ja';

  @override
  String get gridBoolNo => 'Nein';

  @override
  String get gridNestedEmpty => 'Leer';

  @override
  String gridNestedEntries(int count) {
    return '$count Einträge';
  }

  @override
  String gridRowEntries(int count) {
    return '$count Einträge';
  }

  @override
  String get gridNestedEdit => 'Bearbeiten';

  @override
  String get gridAddRow => 'Zeile hinzufügen';

  @override
  String get gridAddRowForm => 'Eintrag hinzufügen';

  @override
  String get gridAddRowFormTooltip => 'Zeile über Formular hinzufügen';

  @override
  String get gridNoEntryRequired => 'Kein Eintrag erforderlich';

  @override
  String get gridRowEditTitle => 'Zeile bearbeiten';

  @override
  String get gridRowEditSave => 'Speichern';

  @override
  String get gridRowAddSave => 'Hinzufügen';

  @override
  String get gridRowAddTitle => 'Zeile hinzufügen';

  @override
  String get gridRowAddTitleDefault => 'Neue Zeile hinzufügen';

  @override
  String get gridSave => 'Speichern';

  @override
  String get gridCancel => 'Abbrechen';

  @override
  String get gridClose => 'Schließen';

  @override
  String get gridView => 'Anzeigen';

  @override
  String get gridValidationErrors => 'Validierungsfehler anzeigen';

  @override
  String get gridValidationWarnings => 'Validierungswarnungen anzeigen';

  @override
  String get gridNoValidationErrors => 'Keine Validierungsfehler';

  @override
  String get versionNewAvailable => 'Neue Version verfügbar';

  @override
  String get versionCurrent => 'Aktuelle Version';

  @override
  String versionNewDetail(String latest, String current) {
    return 'Version $latest ist verfügbar (Aktuell: $current)';
  }

  @override
  String versionCurrentDetail(String current) {
    return 'Version $current';
  }

  @override
  String get versionOpenRelease => 'Release der neuen Version öffnen';

  @override
  String get versionOpenAllReleases => 'Alle Releases öffnen';

  @override
  String get versionCheckForUpdates => 'Nach Updates suchen';

  @override
  String get messageAddTitle => 'Nachricht hinzufügen';

  @override
  String get messageHint => 'Nachricht eingeben…';

  @override
  String get messageCancel => 'Abbrechen';

  @override
  String get messageSend => 'Senden';

  @override
  String get messageEmpty => 'Keine Nachrichten';

  @override
  String get messageDeleteTitle => 'Nachricht löschen';

  @override
  String get messageDeleteConfirm =>
      'Möchten Sie diese Nachricht wirklich löschen?';

  @override
  String get messageDelete => 'Löschen';

  @override
  String messageSendError(String error) {
    return 'Fehler beim Senden der Nachricht: $error';
  }

  @override
  String messageDeleteError(String error) {
    return 'Fehler beim Löschen der Nachricht: $error';
  }
}
