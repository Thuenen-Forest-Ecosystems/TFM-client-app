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
  String get gridRowUnlock => 'Zeile entsperren';

  @override
  String get gridRowLock => 'Zeile sperren';

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

  @override
  String get recordingReadOnlyPlayground =>
      'Playground-Modus: Daten werden nicht gespeichert.';

  @override
  String get recordingReadOnlyAdmin =>
      'Admin-Ansicht: Daten werden nicht gespeichert.';

  @override
  String get recordingReadOnlyGroup =>
      'Nur Leserechte: Daten werden nicht gespeichert.';

  @override
  String get mapSettingsTreeDisplay => 'Baumdarstellung';

  @override
  String mapSettingsDiameterMultiplier(String value) {
    return 'Durchmesser-Multiplikator: ${value}x';
  }

  @override
  String get mapSettingsShowLabels => 'Beschriftungen anzeigen';

  @override
  String get mapSettingsTreeNumber => 'Baumnummer';

  @override
  String get mapSettingsDbh => 'BHD';

  @override
  String get mapSettingsSpeciesCode => 'Baumart (Code)';

  @override
  String get mapSettingsSpeciesName => 'Baumart (Name)';

  @override
  String get mapSettingsAzimuth => 'Azimut';

  @override
  String get mapSettingsDistance => 'Distanz';

  @override
  String get mapSettingsLayers => 'Ebenen';

  @override
  String get mapSettingsEdges => 'Ränder';

  @override
  String get mapSettingsBoundaryCircles => 'Grenzkreise';

  @override
  String get mapSettingsBoundaryCirclesSubtitle => 'basierend auf BHD';

  @override
  String get mapSettingsCluster => 'Trakt';

  @override
  String get mapSettingsClusterSubtitle => 'Umrisse der Trakte';

  @override
  String get mapSettingsSampleCircles => 'Probekreise';

  @override
  String get mapSettingsSampleCirclesSubtitle =>
      '5 m · 10 m · 25 m Referenzkreise';

  @override
  String get mapSettingsRegenerationCircle => 'Verjüngungskreis';

  @override
  String get mapSettingsRegenerationCircleSubtitle =>
      'Aufnahmekreis der Verjüngung';

  @override
  String get mapSettingsRescuePoints => 'Rettungspunkte';

  @override
  String get mapSettingsRescuePointsSubtitle =>
      'Nur in hohen Zoom-Stufen sichtbar';

  @override
  String get mapSettingsBasemaps => 'Basiskarten';

  @override
  String get mapSettingsDtk25Subtitle => 'Topographische Karte des BKG';

  @override
  String get mapSettingsOpenCycleMapSubtitle =>
      'Online; offline nur bereits angesehene Gebiete';

  @override
  String get mapSettingsAerialImagery => 'Luftbilder (offline)';

  @override
  String get mapSettingsAerialImagerySubtitle => 'nur höchste Zoomstufen';

  @override
  String get mapAdminDeleteCache => 'Cache löschen';

  @override
  String mapAdminDeleteConfirm(String storeName) {
    return 'Möchten Sie alle Kacheln für \"$storeName\" löschen?';
  }

  @override
  String get mapAdminCancel => 'Abbrechen';

  @override
  String get mapAdminDelete => 'Löschen';

  @override
  String mapAdminCacheDeleted(String storeName) {
    return 'Cache für \"$storeName\" gelöscht';
  }

  @override
  String mapAdminDeleteError(String error) {
    return 'Fehler beim Löschen: $error';
  }

  @override
  String get mapAdminStoreAerial => 'Luftbilder (DOP)';

  @override
  String mapAdminTileCount(int count, String size) {
    return '$count Kacheln (~$size)';
  }

  @override
  String get mapAdminNoCache => 'Kein Cache vorhanden';

  @override
  String get mapTilesDownloadNoRecords =>
      'Keine Aufnahmepunkte gefunden. Bitte laden Sie zuerst Daten.';

  @override
  String mapTilesDownloadTileProgress(String done, String total) {
    return '$done / $total Kacheln';
  }

  @override
  String get mapTilesDownloadCancel => 'Abbrechen';

  @override
  String get mapTilesDownloadChecking => 'Prüfe Daten...';

  @override
  String get mapTilesDownloadLoadError => 'Fehler beim Laden';

  @override
  String get mapTilesDownloadRetry => 'Erneut versuchen';

  @override
  String get mapTilesDownloadNoPoints =>
      'Keine Aufnahmepunkte vorhanden.\nBitte zuerst Daten synchronisieren.';

  @override
  String get mapTilesDownloadRecheck => 'Erneut prüfen';

  @override
  String get mapTilesDownloadComplete => 'Vollständig';

  @override
  String get mapTilesDownloadResume => 'Fortsetzen';

  @override
  String get mainExitConfirmTitle => 'Bestätigung erforderlich';

  @override
  String get mainExitConfirmContent =>
      'Möchten Sie die Anwendung wirklich beenden?';

  @override
  String get mainExitConfirmNo => 'Nein';

  @override
  String get mainExitConfirmYes => 'Ja';

  @override
  String get startConfirmGoBack => 'Zurückgehen bestätigen';

  @override
  String get startLeaveRecording => 'Aufnahme verlassen';

  @override
  String get startChangesSaved =>
      'Mögliche Änderungen wurden automatisch gespeichert.';

  @override
  String get startCancel => 'abbrechen';

  @override
  String get startToOverview => 'Zur Übersicht';

  @override
  String get loginSessionExpired =>
      'Ihre Sitzung ist abgelaufen. Bitte melden Sie sich erneut an.';

  @override
  String get loginFailed => 'Login fehlgeschlagen';

  @override
  String get loginInvalidCredentials =>
      'Ungültige Anmeldedaten. Bitte überprüfen Sie E-Mail und Passwort.';

  @override
  String get loginEmailNotConfirmed =>
      'E-Mail-Adresse wurde noch nicht bestätigt. Bitte überprüfen Sie Ihr Postfach.';

  @override
  String loginAuthError(String message) {
    return 'Anmeldefehler: $message';
  }

  @override
  String get loginProxyError =>
      'Proxy-Verbindungsfehler: Der konfigurierte Proxy-Server ist nicht erreichbar.\n\nBitte überprüfen Sie:\n• Ihre Proxy-Einstellungen über \"Netzwerk-Einstellungen (Proxy)\" unten\n• Ob der Proxy-Server erreichbar ist\n• Ihre Windows System-Proxy-Einstellungen\n\nTipp: Wenn Sie keinen Proxy benötigen, deaktivieren Sie die Proxy-Funktion in den Netzwerk-Einstellungen.';

  @override
  String get loginTimeoutError =>
      'Verbindungszeitüberschreitung: Der Server konnte nicht rechtzeitig erreicht werden.\n\nBitte versuchen Sie:\n• Eine andere Internetverbindung (z.B. WLAN statt mobile Daten)\n• Es später erneut\n• Kontaktieren Sie Ihren Netzwerkadministrator, falls Sie in einem Firmen-/Institutionsnetzwerk sind';

  @override
  String get loginCertificateError =>
      'Verbindungsfehler: Bitte überprüfen Sie Ihre Internetverbindung und stellen Sie sicher, dass Datum und Uhrzeit korrekt eingestellt sind.\n\nFalls das Problem weiterhin besteht, kontaktieren Sie bwi-support@thuenen.de.';

  @override
  String loginUnexpectedError(String error) {
    return 'Ein unerwarteter Fehler ist aufgetreten: $error';
  }

  @override
  String get loginOfflineFailed => 'Offline-Anmeldung fehlgeschlagen';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginEmailRequired => 'Bitte geben Sie Ihre E-Mail-Adresse ein';

  @override
  String get loginEmailInvalid =>
      'Bitte geben Sie eine gültige E-Mail-Adresse ein';

  @override
  String get loginPassword => 'Passwort';

  @override
  String get loginPasswordRequired => 'Bitte geben Sie Ihr Passwort ein';

  @override
  String get loginPasswordTooShort =>
      'Das Passwort muss mindestens 6 Zeichen lang sein';

  @override
  String get loginSubmit => 'Anmelden';

  @override
  String get loginOfflineMode => 'Offline-Modus: Keine Internetverbindung';

  @override
  String get loginNoInternet => 'Keine Internetverbindung';

  @override
  String get loginNoInternetFirstLogin =>
      'Bitte stellen Sie eine Internetverbindung her, um sich zum ersten Mal anzumelden.';

  @override
  String get loginForgotPassword => 'Passwort vergessen?';

  @override
  String get loginNetworkSettings => 'Netzwerk-Einstellungen (Proxy)';

  @override
  String get schemaLogout => 'Abmelden';

  @override
  String get orderClusterByDistance => 'Distanz (gps required)';

  @override
  String get orderClusterByUpdatedAt => 'Geändert am';

  @override
  String get orderClusterByClusterName => 'Trakt-Nummer';

  @override
  String get clusterInfoNoRecord => 'Kein Datensatz verfügbar';

  @override
  String get clusterInfoNoClusterInfo =>
      'Keine Cluster-Informationen verfügbar';

  @override
  String get clusterInfoShowTooltip => 'Cluster-Informationen anzeigen';

  @override
  String get clusterInfoTitle => 'Informationen';

  @override
  String clusterInfoClusterPlot(String clusterName, String plotName) {
    return 'Trakt: $clusterName / Ecke: $plotName';
  }

  @override
  String get clusterInfoClose => 'Schließen';

  @override
  String get clusterInfoUpdatedAt => 'Aktualisiert am';

  @override
  String get clusterInfoUpdatedBy => 'Aktualisiert von';

  @override
  String get clusterInfoTroop => 'Trupp';

  @override
  String get clusterInfoYes => 'Ja';

  @override
  String get clusterInfoNo => 'Nein';

  @override
  String clusterInfoListEntries(int count) {
    return 'Liste ($count Einträge)';
  }

  @override
  String clusterInfoObjectFields(int count) {
    return 'Objekt ($count Felder)';
  }

  @override
  String get recordsSelectionSearchCluster => 'Suche Traktnummer...';

  @override
  String get recordsSelectionTitle => 'Ecken';

  @override
  String get recordsSelectionNoneAssigned =>
      'Dir wurde bisher noch keine Ecke zugewiesen.';

  @override
  String schemaSelectionError(String error) {
    return 'Fehler: $error';
  }

  @override
  String get schemaSelectionLoading1 => 'Bitte warten...';

  @override
  String get schemaSelectionLoading2 => 'Es kann einen Moment dauern...';

  @override
  String get schemaSelectionLoading3 => '... es dauert nicht mehr lange...';

  @override
  String get schemaSelectionLoading4 => 'Fast geschafft...';

  @override
  String get schemaSelectionLoading5 => 'Noch ein bisschen Geduld...';

  @override
  String get schemaSelectionLoading6 => 'Daten werden synchronisiert...';

  @override
  String get schemaSelectionLoading7 => 'Fast fertig...';

  @override
  String get schemaSelectionNoSchemas => 'Keine Schemas verfügbar';

  @override
  String get schemaSelectionPleaseSync => 'Bitte synchronisieren Sie die Daten';

  @override
  String get loggerTitle => 'Anwendungsprotokolle';

  @override
  String get loggerAddTestLog => 'Test-Log hinzufügen';

  @override
  String get loggerFilter => 'Filter';

  @override
  String get loggerFilterAll => 'Alle Logs';

  @override
  String get loggerFilterInfo => 'Info & höher';

  @override
  String get loggerFilterWarning => 'Warnung & Fehler';

  @override
  String get loggerFilterError => 'Nur Fehler';

  @override
  String get loggerAutoScrollOn => 'Auto-Scroll ein';

  @override
  String get loggerAutoScrollOff => 'Auto-Scroll aus';

  @override
  String get loggerCopyAll => 'Alle Logs kopieren';

  @override
  String get loggerCopiedAll => 'Logs in Zwischenablage kopiert';

  @override
  String get loggerClear => 'Logs löschen';

  @override
  String get loggerClearTitle => 'Logs löschen?';

  @override
  String get loggerClearConfirm => 'Möchten Sie alle Logs wirklich löschen?';

  @override
  String get loggerCancel => 'Abbrechen';

  @override
  String get loggerDelete => 'Löschen';

  @override
  String loggerEntryCount(int count) {
    return '$count Einträge';
  }

  @override
  String loggerFilterLabel(String level) {
    return 'Filter: $level';
  }

  @override
  String get loggerEmpty => 'Keine Logs vorhanden';

  @override
  String get loggerCopiedEntry => 'Log-Eintrag kopiert';

  @override
  String get recordsRawColCluster => 'Trakt';

  @override
  String get recordsRawColPlot => 'Ecke';

  @override
  String get recordsRawColValidatedBy => 'Validiert mit Schema';

  @override
  String get recordsRawColValid => 'Gültig';

  @override
  String get recordsRawColPlotId => 'Ecke ID';

  @override
  String get recordsRawColClusterId => 'Trakt ID';

  @override
  String get recordsRawColAdministration => 'Verwaltung';

  @override
  String get recordsRawColProvider => 'Anbieter';

  @override
  String get recordsRawColState => 'Bundesland';

  @override
  String get recordsRawColTroop => 'Trupp';

  @override
  String get recordsRawColUpdatedAt => 'Aktualisiert';

  @override
  String get recordsRawColLocalUpdatedAt => 'Lokal aktualisiert';

  @override
  String get recordsRawColCompletedState => 'Abgeschlossen (Bundesland)';

  @override
  String get recordsRawColCompletedTroop => 'Abgeschlossen (Trupp)';

  @override
  String get recordsRawColCompletedAdministration =>
      'Abgeschlossen (Verwaltung)';

  @override
  String get recordsRawColToBeRecorded => 'Aufzuzeichnen';

  @override
  String get recordsRawColNote => 'Notiz';

  @override
  String get recordsRawColProperties => 'Eigenschaften (JSON)';

  @override
  String get recordsRawColPreviousProperties =>
      'Vorherige Eigenschaften (JSON)';

  @override
  String get recordsRawColPreviousPosition => 'Vorherige Position (JSON)';

  @override
  String get recordsRawTitle => 'Rohdaten - Datensätze';

  @override
  String get recordsRawRefresh => 'Aktualisieren';

  @override
  String recordsRawTotal(int count) {
    return 'Gesamt: $count Datensätze';
  }

  @override
  String recordsRawPageOf(int page, int total) {
    return 'Seite $page von $total';
  }

  @override
  String recordsRawLoadError(String error) {
    return 'Fehler beim Laden der Datensätze: $error';
  }

  @override
  String get recordsRawRetry => 'Erneut versuchen';

  @override
  String get recordsRawEmpty => 'Keine Datensätze gefunden';

  @override
  String get recordsRawFirstPage => 'Erste Seite';

  @override
  String get recordsRawPreviousPage => 'Vorherige Seite';

  @override
  String get recordsRawNextPage => 'Nächste Seite';

  @override
  String get recordsRawLastPage => 'Letzte Seite';

  @override
  String get syncedTablesReload => 'Neu laden';

  @override
  String syncedTablesError(String error) {
    return 'Fehler: $error';
  }

  @override
  String get syncedTablesRetry => 'Wiederholen';

  @override
  String get syncedTablesEmpty => 'Keine Tabellen gefunden.';

  @override
  String get uploadFailuresRestoreTitle => 'Upload wiederherstellen?';

  @override
  String uploadFailuresRestoreContent(String title) {
    return 'Der gesicherte Stand von $title wird lokal übernommen (überschreibt den aktuellen lokalen Stand dieses Datensatzes) und beim nächsten Sync erneut hochgeladen.\n\nSchlägt der Upload wieder fehl, erscheint der Eintrag erneut in dieser Liste.';
  }

  @override
  String get uploadFailuresCancel => 'Abbrechen';

  @override
  String get uploadFailuresRestore => 'Wiederherstellen';

  @override
  String get uploadFailuresRestoredSnack =>
      'Wiederhergestellt — wird beim nächsten Sync erneut hochgeladen.';

  @override
  String uploadFailuresRestoreFailed(String error) {
    return 'Wiederherstellen fehlgeschlagen: $error';
  }

  @override
  String uploadFailuresRestoreAllTitle(int count) {
    return 'Alle $count Einträge wiederherstellen?';
  }

  @override
  String get uploadFailuresRestoreAllContent =>
      'Alle gesicherten Stände werden lokal übernommen (älteste zuerst) und beim nächsten Sync erneut hochgeladen. Aktuelle lokale Stände der betroffenen Datensätze werden überschrieben.';

  @override
  String get uploadFailuresRestoreAll => 'Alle wiederherstellen';

  @override
  String get uploadFailuresRestoreAllSuccess =>
      'Alle Einträge wiederhergestellt — Upload folgt beim nächsten Sync.';

  @override
  String uploadFailuresRestoreAllErrors(int count, String errors) {
    return '$count Einträge konnten nicht übernommen werden:\n$errors';
  }

  @override
  String get uploadFailuresDiscardTitle => 'Eintrag endgültig verwerfen?';

  @override
  String uploadFailuresDiscardContent(String title) {
    return 'Die gesicherten Daten von $title werden gelöscht und können danach nicht mehr wiederhergestellt werden.';
  }

  @override
  String get uploadFailuresDiscard => 'Verwerfen';

  @override
  String uploadFailuresDeleteFailed(String error) {
    return 'Löschen fehlgeschlagen: $error';
  }

  @override
  String uploadFailuresTractTitle(String cluster, String plot) {
    return 'Trakt $cluster / $plot';
  }

  @override
  String get uploadFailuresReasonIgnored =>
      'Vom Server ignoriert (keine Schreibberechtigung für diesen Datensatz)';

  @override
  String get uploadFailuresReasonRejected => 'Vom Server abgelehnt';

  @override
  String get uploadFailuresReasonUnattempted =>
      'Nicht versucht (vorheriger Upload derselben Übertragung wurde abgelehnt)';

  @override
  String get uploadFailuresReasonUnknown => 'Unbekannt';

  @override
  String get uploadFailuresTitle => 'Sicherungen';

  @override
  String get uploadFailuresActiveDbTab => 'Aktive DB';

  @override
  String uploadFailuresActiveDbTabCount(int count) {
    return 'Aktive DB ($count)';
  }

  @override
  String get uploadFailuresActiveDatabase => 'Aktive Datenbank';

  @override
  String uploadFailuresNotAppliedSuffix(int count) {
    return ' · $count nicht übernommen';
  }

  @override
  String get uploadFailuresQuarantineExplanation =>
      'Diese Änderungen hat der Server nicht übernommen. Die Daten sind lokal gesichert und können erneut übertragen werden.';

  @override
  String get uploadFailuresAllAccepted =>
      'Alle Uploads dieser Datenbank wurden vom Server übernommen.';

  @override
  String uploadFailuresRestoreAllCount(int count) {
    return 'Alle $count wiederherstellen';
  }

  @override
  String get uploadFailuresEmpty =>
      'Keine Einträge — alle Uploads wurden übernommen.';

  @override
  String get uploadFailuresRecoverTitle => 'Datensatz wiederherstellen?';

  @override
  String uploadFailuresRecoverContent(String title, String fileName) {
    return 'Der Stand von $title aus „$fileName“ wird in die aktive Datenbank übernommen (überschreibt den dortigen Stand) und beim nächsten Sync hochgeladen.\n\nLehnt der Server den Upload ab, erscheint er im Tab „Aktive DB“. Die Quelldatei bleibt unverändert.';
  }

  @override
  String get uploadFailuresRecoveredSnack =>
      'In aktive Datenbank übernommen — Upload folgt beim nächsten Sync.';

  @override
  String uploadFailuresRecordNotFound(String fileName) {
    return 'Datensatz nicht mehr in „$fileName“ gefunden.';
  }

  @override
  String uploadFailuresRecoverAllTitle(int count) {
    return '$count nicht hochgeladene Datensätze wiederherstellen?';
  }

  @override
  String get uploadFailuresRecoverAllContent =>
      'Alle Datensätze mit nie hochgeladenen Änderungen werden in die aktive Datenbank übernommen (überschreiben den dortigen Stand) und beim nächsten Sync hochgeladen.';

  @override
  String uploadFailuresRecoverAllSuccess(int count) {
    return '$count Datensätze übernommen — Upload folgt beim nächsten Sync.';
  }

  @override
  String uploadFailuresRecoverAllPartial(
    int recovered,
    int failed,
    String errors,
  ) {
    return '$recovered übernommen, $failed fehlgeschlagen:\n$errors';
  }

  @override
  String uploadFailuresTractLabel(String title) {
    return 'Trakt $title';
  }

  @override
  String uploadFailuresReadError(String fileName, String error) {
    return 'Fehler beim Lesen von „$fileName“: $error';
  }

  @override
  String uploadFailuresFileSummary(String fileName, int count) {
    return '$fileName · $count Datensätze';
  }

  @override
  String uploadFailuresNeverUploadedSuffix(int count) {
    return ' · $count nie hochgeladen';
  }

  @override
  String get uploadFailuresPendingExplanation =>
      'Datensätze mit „Nicht hochgeladen“ existieren NUR in dieser Datei — der Server hat sie nie erhalten.';

  @override
  String get uploadFailuresAllUploadedExplanation =>
      'Alle Datensätze dieser Datei wurden auch auf den Server hochgeladen oder stammen von dort.';

  @override
  String get uploadFailuresReload => 'Neu laden';

  @override
  String get uploadFailuresNoRecords => 'Keine Datensätze in dieser Datei.';

  @override
  String get uploadFailuresNotUploaded => 'Nicht hochgeladen';

  @override
  String get diagnosticExportDialogTitle => 'Diagnosedaten speichern';

  @override
  String diagnosticExportSaved(String path) {
    return 'Gespeichert: $path';
  }

  @override
  String diagnosticExportError(String error) {
    return 'Fehler beim Speichern: $error';
  }

  @override
  String get diagnosticExportTooltip => 'Diagnosedaten als JSON speichern';

  @override
  String get playgroundModeButtonExit => 'Playground-Modus beenden';

  @override
  String get playgroundModeButtonLabel => 'Playground';

  @override
  String get playgroundModeButtonActivate =>
      'Playground-Modus aktivieren (kein Speichern möglich)';

  @override
  String get recordsExportDialogTitle => 'Datensätze speichern';

  @override
  String recordsExportSaved(int count, String path) {
    return '$count Datensätze gespeichert:\n$path';
  }

  @override
  String recordsExportError(String error) {
    return 'Fehler beim Exportieren: $error';
  }

  @override
  String get recordsExportTooltip => 'Alle Datensätze als JSON exportieren';

  @override
  String get recordCardNotAccessible => 'Nicht zugänglich';

  @override
  String get recordCardNever => 'Nie';

  @override
  String recordCardTitle(String cluster, String plot) {
    return 'Trakt: $cluster | Ecke: $plot';
  }

  @override
  String get submissionSuccessDialogDeliveredTitle =>
      'Übermittelt und vom Server bestätigt';

  @override
  String get submissionSuccessDialogUploadingTitle =>
      'Gespeichert — wird übertragen …';

  @override
  String get submissionSuccessDialogPendingOfflineTitle =>
      'Auf dem Gerät gespeichert';

  @override
  String get submissionSuccessDialogRejectedTitle =>
      'Übertragung nicht übernommen';

  @override
  String get submissionSuccessDialogDeliveredSubtitle =>
      'Die Aufnahme ist auf dem Server angekommen.';

  @override
  String submissionSuccessDialogUploadingQueue(int count) {
    return 'Noch $count Änderungen in der Warteschlange.';
  }

  @override
  String get submissionSuccessDialogUploadingSubtitle =>
      'Die Übertragung läuft.';

  @override
  String get submissionSuccessDialogPendingOfflineSubtitle =>
      'Noch nicht übertragen — das geschieht automatisch, sobald wieder eine Verbindung besteht. Bitte vor dem Abschluss des Feldtags online gehen und den Sync-Status prüfen.';

  @override
  String get submissionSuccessDialogRejectedSubtitle =>
      'Der Server hat diese Änderung nicht übernommen. Die Daten sind lokal gesichert und stehen unter „Sicherungen\" im Profil zur Wiederherstellung bereit.';

  @override
  String submissionSuccessDialogTractCorner(String cluster, String plot) {
    return 'Trakt $cluster · Ecke $plot';
  }

  @override
  String submissionSuccessDialogOtherCorners(String cluster) {
    return 'Weitere Ecken in Trakt $cluster:';
  }

  @override
  String submissionSuccessDialogCorner(String plot) {
    return 'Ecke $plot';
  }

  @override
  String submissionSuccessDialogCompletedAt(String date) {
    return 'Abgeschlossen: $date';
  }

  @override
  String submissionSuccessDialogEditedAt(String date) {
    return 'Bearbeitet: $date';
  }

  @override
  String get submissionSuccessDialogNotEdited => 'Nicht bearbeitet';

  @override
  String get submissionSuccessDialogNoOtherCorners =>
      'Keine weiteren Ecken in diesem Trakt.';

  @override
  String get submissionSuccessDialogBackToOverview => 'Zur Übersicht';

  @override
  String get syncStatusButtonLastSync => 'Letzte Synchronisierung';

  @override
  String get syncStatusButtonNever => 'Nie';

  @override
  String get syncStatusButtonCertificateHint =>
      'Haben Sie bereits die Anwendung \"Install SSL Certificates\" ausgeführt? Wenn nicht, bitte suchen Sie die Anwendung und führen Diese aus.';

  @override
  String get syncStatusButtonQueue => 'Warteschlange';

  @override
  String syncStatusButtonPending(int count) {
    return '$count ausstehend';
  }

  @override
  String syncStatusButtonUploadFailures(int count) {
    return '⚠ $count Upload(s) vom Server nicht übernommen';
  }

  @override
  String get syncStatusButtonUploadFailuresHint =>
      'Die Daten sind lokal gesichert (upload_failures). Bitte Diagnose-Export erstellen und an den Support senden.';

  @override
  String syncStatusButtonAndMore(int count) {
    return '… und $count weitere';
  }

  @override
  String get syncStatusButtonNotSynced => 'Nicht synchronisiert';

  @override
  String syncStatusButtonRecordCount(int count) {
    return '$count Datensätze';
  }

  @override
  String get syncStatusButtonServerSql => 'Server-Diagnose SQL:';

  @override
  String get syncStatusButtonCopySql => 'SQL kopieren';

  @override
  String get syncStatusButtonSqlCopied => 'SQL in die Zwischenablage kopiert';

  @override
  String syncStatusButtonRecordRow(
    String cluster,
    String plot,
    String localTs,
    String serverTs,
  ) {
    return '$cluster / $plot\nLokal: $localTs  •  Server: $serverTs';
  }

  @override
  String get densitySettingsCompactTable => 'Kompakter Tabellenmodus';

  @override
  String get densitySettingsReducedRowHeight =>
      'Reduzierte Zeilenhöhe (für Stift/Tablet)';

  @override
  String get densitySettingsStandardRowHeight => 'Standard-Zeilenhöhe';

  @override
  String get keyboardSettingsFloatingNumpad => 'Schwimmendes Nummernfeld';

  @override
  String get keyboardSettingsNotAvailable =>
      'Nicht verfügbar auf dieser Plattform.';

  @override
  String get keyboardSettingsNumpadForNumbers =>
      'Zahlentastatur bei Zahlenfeldern';

  @override
  String get keyboardSettingsSystemKeyboardForNumbers =>
      'System-Tastatur bei Zahlenfeldern';

  @override
  String get profileLogoutUnsyncedWarning =>
      'Auf diesem Gerät sind noch nicht übertragene Daten!';

  @override
  String profileLogoutPendingUploads(int count) {
    return '• $count Änderung(en) warten auf die Übertragung';
  }

  @override
  String profileLogoutQuarantined(int count) {
    return '• $count gesicherte(r) Eintrag/Einträge unter „Sicherungen\"';
  }

  @override
  String get profileLogoutDataLostHint =>
      'Diese Daten sind danach unwiederbringlich verloren. Bitte zuerst synchronisieren — oder ein Backup erstellen.';

  @override
  String profileBackupsWithCount(int count) {
    return 'Sicherungen ($count)';
  }

  @override
  String get profileBackups => 'Sicherungen';

  @override
  String get profileBackupsSubtitle =>
      'Nicht übertragene Daten wiederherstellen';

  @override
  String propertiesEditNoSchemaFound(String intervalName) {
    return 'Kein Schema gefunden für: $intervalName';
  }

  @override
  String get propertiesEditControlTroopStyleMissing =>
      'Kontroll-Trupp benötigt style_control Schema, aber es ist nicht verfügbar';

  @override
  String propertiesEditSchemaLoadError(String error) {
    return 'Fehler beim Laden des Schemas: $error';
  }

  @override
  String get propertiesEditNewRecordNotAllowed =>
      'Neue Aufnahmen können hier nicht erstellt werden.';

  @override
  String get propertiesEditPlaygroundNoSave =>
      '🧪 Playground-Modus aktiv – Speichern nicht möglich.';

  @override
  String get propertiesEditAdminViewNoSave =>
      'Admin-Ansicht – Speichern nicht möglich.';

  @override
  String propertiesEditSaveError(String error) {
    return 'Fehler beim Speichern: $error';
  }

  @override
  String get propertiesEditInformation => 'Informationen';

  @override
  String propertiesEditCluster(String cluster) {
    return 'Trakt: $cluster';
  }

  @override
  String propertiesEditPlot(String plot) {
    return 'Ecke: $plot';
  }

  @override
  String get propertiesEditDone => 'FERTIG';

  @override
  String get proxyServiceTimeoutAfter10s =>
      'Verbindung nach 10 Sekunden abgebrochen';

  @override
  String get proxyServiceWebSocketTimeout => 'WebSocket-Verbindung Timeout';

  @override
  String get proxyServiceWebSocketWorks => 'WebSocket funktioniert';

  @override
  String proxyServiceHttpSuccess(int statusCode) {
    return 'HTTP-Verbindung erfolgreich ($statusCode)';
  }

  @override
  String proxyServiceServerStatus(int statusCode) {
    return 'Server antwortet mit Status $statusCode';
  }

  @override
  String proxyServiceConnectionRefused(String address, int port) {
    return 'Verbindung abgelehnt. Prüfen Sie:\n• Läuft der Proxy auf $address:$port?\n• Ist die Proxy-Adresse korrekt?\n• Firewall-Einstellungen?';
  }

  @override
  String proxyServiceHostUnreachable(String address) {
    return 'Host nicht erreichbar: $address';
  }

  @override
  String proxyServiceNetworkError(String error) {
    return 'Netzwerkfehler: $error';
  }

  @override
  String proxyServiceTimeout(String message) {
    return 'Zeitüberschreitung: $message';
  }

  @override
  String get proxyServiceNoResponse10s => 'Keine Antwort nach 10 Sekunden';

  @override
  String proxyServiceUnexpectedError(String error) {
    return 'Unerwarteter Fehler: $error';
  }

  @override
  String proxySettingsLoadError(String error) {
    return 'Fehler beim Laden der Einstellungen: $error';
  }

  @override
  String get proxySettingsSaved => 'Proxy-Einstellungen gespeichert';

  @override
  String proxySettingsSaveError(String error) {
    return 'Fehler beim Speichern: $error';
  }

  @override
  String get proxySettingsProxyDisabled => 'Proxy ist deaktiviert';

  @override
  String proxySettingsTestFailed(String error) {
    return 'Test fehlgeschlagen: $error';
  }

  @override
  String get proxySettingsRestartTitle => 'Neustart erforderlich';

  @override
  String get proxySettingsRestartContent =>
      'Die Proxy-Einstellungen werden beim nächsten Start der Anwendung wirksam.\n\nMöchten Sie die Anwendung jetzt beenden?';

  @override
  String get proxySettingsRestartLater => 'Später';

  @override
  String get proxySettingsCloseApp => 'Anwendung schließen';

  @override
  String get proxySettingsEnable => 'Proxy aktivieren';

  @override
  String get proxySettingsEnableSubtitle =>
      'Verbindung über Proxy-Server herstellen';

  @override
  String get proxySettingsUseSystemProxy => 'System-Proxy verwenden';

  @override
  String get proxySettingsUseSystemProxySubtitle =>
      'Nutzt die Windows-Proxy-Einstellungen (EMPFOHLEN - unterstützt WebSocket)';

  @override
  String get proxySettingsManualConfig => 'Manuelle Konfiguration';

  @override
  String get proxySettingsManualConfigDeprecated =>
      'Veraltet: sollte nicht mehr genutzt werden.';

  @override
  String get proxySettingsProxyServer => 'Proxy-Server';

  @override
  String get proxySettingsHostLabel => 'Host/IP-Adresse';

  @override
  String get proxySettingsHostHint => 'z.B. proxy.example.com oder 192.168.1.1';

  @override
  String get proxySettingsHostRequired => 'Bitte Host-Adresse eingeben';

  @override
  String get proxySettingsPortLabel => 'Port';

  @override
  String get proxySettingsPortHint => 'z.B. 8080, 3128';

  @override
  String get proxySettingsPortRequired => 'Bitte Port eingeben';

  @override
  String get proxySettingsPortInvalid => 'Ungültiger Port (1-65535)';

  @override
  String get proxySettingsAuthTitle => 'Authentifizierung (optional)';

  @override
  String get proxySettingsAuthHint =>
      'Nur erforderlich, wenn der Proxy-Server Benutzername und Passwort verlangt.';

  @override
  String get proxySettingsUsername => 'Benutzername';

  @override
  String get proxySettingsPassword => 'Passwort';

  @override
  String get proxySettingsTesting => 'Teste Verbindung...';

  @override
  String get proxySettingsTestConnection => 'Verbindung testen';

  @override
  String get proxySettingsNotes => 'Hinweise';

  @override
  String get proxySettingsNotesBody =>
      '• Für Landesdatennetze: \"System-Proxy verwenden\" aktivieren\n• Die Windows-Proxy-Einstellungen werden automatisch erkannt\n• Umgebungsvariablen (HTTP_PROXY, HTTPS_PROXY) werden unterstützt';

  @override
  String get proxySettingsNotesRestart =>
      '• Nach dem Speichern ist ein Neustart der Anwendung erforderlich';

  @override
  String get proxySettingsSave => 'Einstellungen speichern';

  @override
  String get themeSettingsLight => 'Hell';

  @override
  String get themeSettingsDark => 'Dunkel';

  @override
  String get themeSettingsSystem => 'System';

  @override
  String get themeSettingsLightSubtitle => 'Hoher Kontrast an hellen Tagen';

  @override
  String get themeSettingsDarkSubtitle =>
      'Energiesparmodus für schattige Umgebungen';

  @override
  String get themeSettingsSystemSubtitle => 'Systemeinstellung folgen';

  @override
  String validationErrorsDialogAllErrorsNeedNote(int count) {
    return 'Alle Fehler müssen mit einer Notiz bestätigt werden ($count verbleibend)';
  }

  @override
  String get validationErrorsDialogGroupCorner => 'Ecke';

  @override
  String get validationErrorsDialogGroupPosition => 'Position';

  @override
  String get validationErrorsDialogGroupEdges => 'Ränder';

  @override
  String get validationErrorsDialogGroupStructureLt4m => 'Struktur < 4m';

  @override
  String get validationErrorsDialogGroupStructureGt4m => 'Struktur > 4m';

  @override
  String get validationErrorsDialogGroupStocking => 'Bestockung';

  @override
  String get validationErrorsDialogGroupRegeneration => 'Verjüngung';

  @override
  String get validationErrorsDialogGroupDeadwood => 'Totholz';

  @override
  String get validationErrorsDialogPlausibilityUnavailable =>
      'Die Plausibilitätsprüfung konnte nicht ausgeführt werden (vorübergehendes technisches Problem). Die Ecke kann trotzdem abgeschlossen und übermittelt werden.';

  @override
  String get validationErrorsDialogTitle => 'Ergebnis der Prüfung';

  @override
  String get validationErrorsDialogNoIssues =>
      'Keine Fehler oder Warnungen gefunden.';

  @override
  String validationErrorsDialogErrorCount(int count) {
    return '$count Fehler';
  }

  @override
  String validationErrorsDialogWarningCount(int count) {
    return '$count Warnungen';
  }

  @override
  String validationErrorsDialogNote(String note) {
    return 'Hinweis: $note';
  }

  @override
  String validationErrorsDialogObject(String object) {
    return 'Objekt: $object';
  }

  @override
  String validationErrorsDialogPath(String path) {
    return 'Pfad: $path';
  }

  @override
  String get validationErrorsDialogAddNoteRequired =>
      'Notiz hinzufügen (erforderlich für Fehler)*';

  @override
  String get validationErrorsDialogAddNoteOptional =>
      'Notiz hinzufügen (optional)';

  @override
  String get validationErrorsDialogNoteLabel => 'Notiz';

  @override
  String get validationErrorsDialogNoteRequired => 'Notiz erforderlich';

  @override
  String get validationErrorsDialogSubmit =>
      'AN LANDESINVENTURLEITUNG ÜBERMITTELN';

  @override
  String validationErrorsDialogFixOrComment(int count) {
    return '$count Fehler beheben oder kommentieren';
  }

  @override
  String get serialPortGpsCancel => 'Abbrechen';

  @override
  String bluetoothIconClassicScanFailed(String error) {
    return 'Suche nach Bluetooth-Classic-Geräten fehlgeschlagen: $error';
  }

  @override
  String get bluetoothIconPairingFailedTitle => 'Kopplung fehlgeschlagen';

  @override
  String bluetoothIconPairingFailedHint(String label) {
    return 'Gerät \"$label\" konnte nicht gekoppelt werden.\n\nBitte prüfen, ob das Gerät eingeschaltet und sichtbar ist, und die Kopplungsanfrage auf beiden Geräten bestätigen.';
  }

  @override
  String bluetoothIconPairingFailedError(String label, String error) {
    return 'Gerät \"$label\" konnte nicht gekoppelt werden.\n\n$error';
  }

  @override
  String get bluetoothIconAvailableDevices => 'erreichbare GNSS Geräte';

  @override
  String get bluetoothIconNotPairedTooltip =>
      'Noch nicht gekoppelt – Kopplung startet beim Antippen';

  @override
  String get bluetoothIconPaired => 'gekoppelt';

  @override
  String get positionSelectorNavigateByCar => 'Mit Auto navigieren';

  @override
  String get positionSelectorNavigateOnFoot => 'Zu Fuß navigieren';

  @override
  String get positionSelectorShowOnMap => 'Auf Karte anzeigen';

  @override
  String get positionSelectorMapPosition => 'Karte Position';

  @override
  String get positionSelectorCurrentGpsPosition => 'Aktuelle GPS Position';

  @override
  String get positionSelectorSaved => 'Gespeichert';

  @override
  String get positionSelectorGpsPosition => 'GPS Position';

  @override
  String get positionSelectorNoGpsData => 'Keine GPS-Daten verfügbar';

  @override
  String get positionSelectorSetPosition => 'Position festlegen';

  @override
  String get positionSelectorSavedLower => 'gespeichert';

  @override
  String get positionSelectorEnableLiveTracking => 'Live-Tracking aktivieren';

  @override
  String get positionSelectorPickOnMap => 'Position auf Karte wählen';

  @override
  String get positionSelectorTapOnMap => 'Tippe auf die Karte';

  @override
  String get positionSelectorDelete => 'Löschen';

  @override
  String get positionSelectorCornerMeasurements => 'Messungen Ecken';

  @override
  String get positionSelectorCenter => 'Zentrum';

  @override
  String get positionSelectorSupportPoints => 'Hilfspunkte';

  @override
  String get positionSelectorSetAsCenter => 'Als Zentrum gesetzt';

  @override
  String get manuellRelativePositionInvalidValues =>
      'Bitte gültige Werte für Azimut und Entfernung eingeben';

  @override
  String get manuellRelativePositionAzimuthRange =>
      'Azimut muss zwischen 0 und 400 Gon liegen';

  @override
  String manuellRelativePositionNothingToFocus(String label) {
    return 'Keine $label zum Fokussieren verfügbar';
  }

  @override
  String get manuellRelativePositionSelectedPosition => 'Gewählte Position';

  @override
  String get manuellRelativePositionGpsPosition => 'GPS Position';

  @override
  String manuellRelativePositionStartPosition(String label) {
    return 'Startposition: $label';
  }

  @override
  String get manuellRelativePositionNoData => 'Keine Daten';

  @override
  String get manuellRelativePositionPosition => 'Position';

  @override
  String get manuellRelativePositionDestination => 'Zielposition';

  @override
  String get manuellRelativePositionSetDestination => 'Ziel festlegen';

  @override
  String get manuellRelativePositionAzimuth => 'Azimut';

  @override
  String get manuellRelativePositionDistance => 'Entfernung';

  @override
  String get manuellRelativePositionAzimuthGon => 'Azimut (gon)';

  @override
  String get manuellRelativePositionDistanceMeters => 'Entfernung (m)';

  @override
  String get manuellRelativePositionMetersHint => 'Meter';

  @override
  String manuellRelativePositionAfterStep(int step) {
    return 'Position nach Schritt $step';
  }

  @override
  String get recordPositionQualityGood => 'gut';

  @override
  String get recordPositionQualityOk => 'geeignet';

  @override
  String get recordPositionQualityNotAcceptable => 'nicht geeignet';

  @override
  String get recordPositionLastGpsInfo => 'Zuletzt gemessene GPS-Information';

  @override
  String get recordPositionConnection => 'Verbindung';

  @override
  String get recordPositionUnknown => 'Unbekannt';

  @override
  String recordPositionSerial(String port) {
    return 'Seriell: $port';
  }

  @override
  String get recordPositionInternalGps => 'Internes GPS';

  @override
  String get recordPositionNoConnection => 'Keine Verbindung';

  @override
  String get recordPositionTimestamp => 'Zeitpunkt';

  @override
  String get recordPositionCorrectionSignal => 'Korrektursignal';

  @override
  String get recordPositionCorrectionSignalAge => 'Alter Korrektursignal';

  @override
  String get recordPositionSatellites => 'Satelliten';

  @override
  String get recordPositionAltitude => 'Höhe';

  @override
  String get recordPositionNoGpsData => 'Keine GPS-Daten verfügbar';

  @override
  String get recordPositionSavedMeasurement => 'Gespeicherte Messung';

  @override
  String get recordPositionMeasurements => 'Messungen';

  @override
  String get recordPositionSatellitesAvg => 'Satelliten (avg)';

  @override
  String get recordPositionCurrentMeasurement => 'Aktuelle Messung';

  @override
  String recordPositionRecordingProgress(String current, String total) {
    return 'Aufzeichnung: $current / $total Positionen';
  }

  @override
  String get recordPositionStopMeasurement => 'Einmessung beenden';

  @override
  String recordPositionCompleted(String count) {
    return 'Abgeschlossen: $count Positionen aufgezeichnet';
  }

  @override
  String get recordPositionStartNewMeasurement => 'Neue Messung starten';

  @override
  String get recordPositionStartMeasurement => 'Einmessung starten';

  @override
  String get recordPositionWaitingForValidGps =>
      'Warte auf gültiges GPS-Signal...';

  @override
  String get recordPositionDiscardMeasurement => 'Messung verwerfen';

  @override
  String get recordPositionReplaceMeasurement => 'Messung ersetzen';

  @override
  String get recordPositionApplyMeasurement => 'Messung übernehmen';

  @override
  String get recordPositionNotSuitable => 'Nicht geeignet';

  @override
  String get recordPositionDgpsAvailable => 'DGPS verfügbar';

  @override
  String get recordPositionRtkFixedAvailable => 'RTK Fixed verfügbar';

  @override
  String get recordPositionRtkFloatAvailable => 'RTK Float verfügbar';

  @override
  String get displacedMarkerMinDistance => 'mind. 1 cm';

  @override
  String get displacedMarkerAdd => 'Versetzte Markierung anlegen';

  @override
  String get displacedMarkerTitle => 'Versetzte Markierung';

  @override
  String get displacedMarkerRemove => 'Versetzte Markierung entfernen';

  @override
  String get displacedMarkerHorizontalDistance => 'Horizontalentfernung';

  @override
  String get displacedMarkerAzimuth => 'Azimut';

  @override
  String get displacedMarkerDescription => 'Beschreibung';

  @override
  String get displacedMarkerIsMarked => 'Ist markiert';

  @override
  String get previousPositionsNavigationGpsLocked => 'GPS Position (Gesperrt)';

  @override
  String get previousPositionsNavigationNoPreviousData =>
      'Keine vorherigen Positionsdaten verfügbar';

  @override
  String get previousPositionsNavigationNoCoordinates =>
      'Keine Koordinaten in vorherigen Positionsdaten gefunden';

  @override
  String get previousPositionsNavigationTitle => 'Navigation:';

  @override
  String get previousPositionsNavigationTarget => 'Ziel';

  @override
  String previousPositionsNavigationDistanceAzimuth(
    String distance,
    String azimuth,
    String coordinates,
  ) {
    return 'Distanz: $distance, Azimut: $azimuth gon$coordinates';
  }

  @override
  String get previousPositionsNavigationNoNavigationData =>
      'Keine Navigationsdaten verfügbar, verbinde ein externes GPS oder nutze das interne GPS des Geräts.';

  @override
  String get previousPositionsSelectionNoData =>
      'Keine vorherigen Positionsdaten verfügbar';

  @override
  String get previousPositionsSelectionTitle => 'Vorherige Positionsmessungen';

  @override
  String get manualNavigationStepsAzimuthRange =>
      'Azimut muss zwischen 0 und 400 Gon liegen';

  @override
  String get manualNavigationStepsTooltip => 'Manuelle Navigation';

  @override
  String get manualNavigationStepsSelectStartAndTarget =>
      'Start und Ziel auswählen';

  @override
  String get manualNavigationStepsDistance => 'Entfernung';

  @override
  String get manualNavigationStepsAzimuth => 'Azimut';

  @override
  String get landmarkPointsMinDistance => 'mind. 1 cm';

  @override
  String landmarkPointsTitle(int number) {
    return 'Geländepunkt $number';
  }

  @override
  String get landmarkPointsRemove => 'Geländepunkt entfernen';

  @override
  String get landmarkPointsHorizontalDistance => 'Horizontalentfernung';

  @override
  String get landmarkPointsAzimuth => 'Azimut';

  @override
  String get landmarkPointsDescription => 'Beschreibung';

  @override
  String get landmarkPointsHint =>
      'Azimut und Entfernung von der Ecke zum Geländepunkt';

  @override
  String get landmarkPointsAdd => 'Geländepunkt hinzufügen';

  @override
  String get helpingPointUnknown => 'Unbekannt';

  @override
  String helpingPointRecordingProgress(int current, int total) {
    return 'Einmessung... $current/$total';
  }

  @override
  String get helpingPointCancel => 'Abbrechen';

  @override
  String helpingPointMeasurementCountShort(String count) {
    return '$count Mess.';
  }

  @override
  String get helpingPointNewMeasurement => 'neue Einmessung';

  @override
  String get helpingPointMeasurements => 'Messungen';

  @override
  String get helpingPointAccuracy => 'Genauigkeit';

  @override
  String get helpingPointSatellites => 'Satelliten';

  @override
  String get helpingPointCorrectionSignal => 'Korrektursignal';

  @override
  String get helpingPointTimestamp => 'Zeitpunkt';

  @override
  String get helpingPointStartMeasurement => 'Einmessung starten';

  @override
  String plotSupportPointsAzimuth(String azimuth) {
    return 'Azimut: $azimuth gon';
  }

  @override
  String plotSupportPointsDistance(String distance) {
    return 'Distanz: $distance cm';
  }

  @override
  String get formWrapperMessagesUnavailable =>
      'Nachrichtenfunktion nicht verfügbar: Kein Datensatz geladen';

  @override
  String get arrayElementArchiveRowDeleteBlocked =>
      'Bestehender Eintrag aus der Inventur – Löschen nicht möglich.';

  @override
  String get arrayElementTrinaFilterTooltip => 'Filter';

  @override
  String get arrayElementCardlistDeleteProtectedTooltip =>
      'Bestehender Eintrag aus der Inventur – nicht löschbar';

  @override
  String get arrayElementCardlistDeleteEntry => 'Eintrag löschen';

  @override
  String arrayElementCardlistMaxEntries(int maxRows) {
    return 'Maximal $maxRows Einträge';
  }

  @override
  String arrayElementCardlistAddEntry(String label) {
    return '$label hinzufügen';
  }

  @override
  String get arrayElementCardlistEntryDefault => 'Eintrag';

  @override
  String get arrayFilterDialogTitle => 'Ausblenden';

  @override
  String get arrayFilterDialogNoFilters => 'Keine Filter verfügbar';

  @override
  String get cardDialogNoFields => 'Keine Felder verfügbar';

  @override
  String get cardDialogDone => 'Fertig';

  @override
  String get genericTextfieldInfoTooltip => 'Info';

  @override
  String permissionsSelectionSyncing(String percent) {
    return 'Berechtigungen werden synchronisiert…$percent';
  }

  @override
  String get permissionsSelectionNone => 'Keine Berechtigungen gefunden';

  @override
  String get permissionsSelectionTroopRequired =>
      'Trupp-Zugehörigkeit benötigt';

  @override
  String get databaseBackupSaveDialogTitle => 'Datenbank-Backup speichern';

  @override
  String get databaseBackupSavedSealed => 'Backup verschlüsselt gespeichert';

  @override
  String get databaseBackupSaved => 'Backup gespeichert';

  @override
  String databaseBackupFailed(String error) {
    return 'Backup fehlgeschlagen: $error';
  }

  @override
  String get databaseBackupInProgress => 'Backup wird erstellt …';

  @override
  String get databaseBackupAllSealed =>
      'Backup aller Datenbanken (verschlüsselt)';

  @override
  String get databaseBackupAllZip => 'Backup aller Datenbanken (ZIP)';
}
