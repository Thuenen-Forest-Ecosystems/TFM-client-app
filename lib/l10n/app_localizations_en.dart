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

  @override
  String get profileTitle => 'Settings';

  @override
  String get profileMapManagement => 'Map management';

  @override
  String get profileLayoutSettings => 'Layout settings';

  @override
  String get profileLanguageSettings => 'Language settings';

  @override
  String get profileKeyboardSettings => 'Keyboard settings';

  @override
  String get profileCompactMode => 'Compact mode';

  @override
  String get profileNetwork => 'Network';

  @override
  String get profileProxySettings => 'Proxy settings';

  @override
  String get profileProxySubtitle => 'Configuration for state data networks';

  @override
  String get profileResetSettings => 'Reset settings';

  @override
  String get profileResetTitle => 'Reset settings?';

  @override
  String get profileResetContent =>
      'The following local settings will be deleted:\n\n• Compact mode\n• Keyboard setting\n• Column widths in tables\n• Filter states\n• Recently used enum values\n• Map settings\n\nServer, organisation and proxy settings are retained.';

  @override
  String get profileResetCancel => 'Cancel';

  @override
  String get profileResetConfirm => 'Reset';

  @override
  String get profileResetSnackbar => 'Settings have been reset.';

  @override
  String get profileLogoutTitle => 'Sign out and delete data?';

  @override
  String get profileLogoutContent =>
      'All local data will be irreversibly deleted.\n\nUnsynchronised entries will be lost and cannot be restored.\n\nPlease make sure all data has been synchronised before proceeding.';

  @override
  String get profileLogoutCancel => 'Cancel';

  @override
  String get profileLogoutConfirm => 'Delete and sign out';

  @override
  String get profileLoggingIn => 'Signing out…';

  @override
  String get profileLogoutOffline => 'Sign out (offline not possible)';

  @override
  String get profileLogout => 'Sign out and delete data';

  @override
  String get profileImprint => 'Imprint';

  @override
  String get profilePrivacy => 'Privacy policy';

  @override
  String profileAppVersion(String version, String build) {
    return 'App Version: $version ($build)';
  }

  @override
  String get profileShowRecords => 'Show records';

  @override
  String get profileShowSyncedTables => 'Show synced tables';

  @override
  String get profileShowLogs => 'Show logs';

  @override
  String get langDe => 'German';

  @override
  String get langDeSubtitle => '';

  @override
  String get langEn => 'English';

  @override
  String get langEnSubtitle => '(BETA) not fully translated yet';

  @override
  String get langSystem => 'System';

  @override
  String get langSystemSubtitle => 'Use system language';

  @override
  String get enumDialogSearch => 'Search…';

  @override
  String get enumDialogRecentlyUsed => 'Recently used';

  @override
  String get enumDialogListView => 'List view';

  @override
  String get enumDialogChipsView => 'Chips view';

  @override
  String get enumDialogClose => 'Close';

  @override
  String get enumDialogNoResults => 'No results found';

  @override
  String get enumDialogClearField => 'Clear field content';

  @override
  String get gridRowOptions => 'Row options';

  @override
  String get gridRowEdit => 'Edit row';

  @override
  String get gridRowCopy => 'Copy row';

  @override
  String get gridRowDelete => 'Delete row';

  @override
  String get gridBoolYes => 'Yes';

  @override
  String get gridBoolNo => 'No';

  @override
  String get gridNestedEmpty => 'Empty';

  @override
  String gridNestedEntries(int count) {
    return '$count entries';
  }

  @override
  String gridRowEntries(int count) {
    return '$count entries';
  }

  @override
  String get gridNestedEdit => 'Edit';

  @override
  String get gridAddRow => 'Add row';

  @override
  String get gridAddRowForm => 'Add entry';

  @override
  String get gridAddRowFormTooltip => 'Add row via form';

  @override
  String get gridNoEntryRequired => 'No entry required';

  @override
  String get gridRowEditTitle => 'Edit row';

  @override
  String get gridRowEditSave => 'Save';

  @override
  String get gridRowAddSave => 'Add';

  @override
  String get gridRowAddTitle => 'Add row';

  @override
  String get gridRowAddTitleDefault => 'Add new row';

  @override
  String get gridSave => 'Save';

  @override
  String get gridCancel => 'Cancel';

  @override
  String get gridClose => 'Close';

  @override
  String get gridView => 'View';

  @override
  String get gridValidationErrors => 'Show validation errors';

  @override
  String get gridValidationWarnings => 'Show validation warnings';

  @override
  String get gridNoValidationErrors => 'No validation errors';

  @override
  String get versionNewAvailable => 'New version available';

  @override
  String get versionCurrent => 'Current version';

  @override
  String versionNewDetail(String latest, String current) {
    return 'Version $latest is available (Current: $current)';
  }

  @override
  String versionCurrentDetail(String current) {
    return 'Version $current';
  }

  @override
  String get versionOpenRelease => 'Open new version release';

  @override
  String get versionOpenAllReleases => 'Open all releases';

  @override
  String get versionCheckForUpdates => 'Check for updates';

  @override
  String get messageAddTitle => 'Add message';

  @override
  String get messageHint => 'Enter message…';

  @override
  String get messageCancel => 'Cancel';

  @override
  String get messageSend => 'Send';

  @override
  String get messageEmpty => 'No messages';

  @override
  String get messageDeleteTitle => 'Delete message';

  @override
  String get messageDeleteConfirm =>
      'Do you really want to delete this message?';

  @override
  String get messageDelete => 'Delete';

  @override
  String messageSendError(String error) {
    return 'Error sending message: $error';
  }

  @override
  String messageDeleteError(String error) {
    return 'Error deleting message: $error';
  }
}
