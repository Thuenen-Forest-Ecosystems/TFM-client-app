import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// The conventional newborn programmer greeting
  ///
  /// In en, this message translates to:
  /// **'Hello World!'**
  String get helloWorld;

  /// The language of the app
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// The settings of the app
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// The energy saving mode of the app
  ///
  /// In en, this message translates to:
  /// **'Energy Saving'**
  String get energySaving;

  /// The description of the energy saving mode
  ///
  /// In en, this message translates to:
  /// **'Reduce the brightness of the screen'**
  String get energySavingDescription;

  /// The login button
  ///
  /// In en, this message translates to:
  /// **'LOGIN'**
  String get authenticationLogin;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileTitle;

  /// No description provided for @profileMapManagement.
  ///
  /// In en, this message translates to:
  /// **'Map management'**
  String get profileMapManagement;

  /// No description provided for @profileLayoutSettings.
  ///
  /// In en, this message translates to:
  /// **'Layout settings'**
  String get profileLayoutSettings;

  /// No description provided for @profileLanguageSettings.
  ///
  /// In en, this message translates to:
  /// **'Language settings'**
  String get profileLanguageSettings;

  /// No description provided for @profileKeyboardSettings.
  ///
  /// In en, this message translates to:
  /// **'Keyboard settings'**
  String get profileKeyboardSettings;

  /// No description provided for @profileCompactMode.
  ///
  /// In en, this message translates to:
  /// **'Compact mode'**
  String get profileCompactMode;

  /// No description provided for @profileNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get profileNetwork;

  /// No description provided for @profileProxySettings.
  ///
  /// In en, this message translates to:
  /// **'Proxy settings'**
  String get profileProxySettings;

  /// No description provided for @profileProxySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configuration for state data networks'**
  String get profileProxySubtitle;

  /// No description provided for @profileResetSettings.
  ///
  /// In en, this message translates to:
  /// **'Reset settings'**
  String get profileResetSettings;

  /// No description provided for @profileResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset settings?'**
  String get profileResetTitle;

  /// No description provided for @profileResetContent.
  ///
  /// In en, this message translates to:
  /// **'The following local settings will be deleted:\n\n• Compact mode\n• Keyboard setting\n• Column widths in tables\n• Filter states\n• Recently used enum values\n• Map settings\n\nServer, organisation and proxy settings are retained.'**
  String get profileResetContent;

  /// No description provided for @profileResetCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileResetCancel;

  /// No description provided for @profileResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get profileResetConfirm;

  /// No description provided for @profileResetSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Settings have been reset.'**
  String get profileResetSnackbar;

  /// No description provided for @profileLogoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out and delete data?'**
  String get profileLogoutTitle;

  /// No description provided for @profileLogoutContent.
  ///
  /// In en, this message translates to:
  /// **'All local data will be irreversibly deleted.\n\nUnsynchronised entries will be lost and cannot be restored.\n\nPlease make sure all data has been synchronised before proceeding.'**
  String get profileLogoutContent;

  /// No description provided for @profileLogoutCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileLogoutCancel;

  /// No description provided for @profileLogoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete and sign out'**
  String get profileLogoutConfirm;

  /// No description provided for @profileLoggingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing out…'**
  String get profileLoggingIn;

  /// No description provided for @profileLogoutOffline.
  ///
  /// In en, this message translates to:
  /// **'Sign out (offline not possible)'**
  String get profileLogoutOffline;

  /// No description provided for @profileLogout.
  ///
  /// In en, this message translates to:
  /// **'Sign out and delete data'**
  String get profileLogout;

  /// No description provided for @profileImprint.
  ///
  /// In en, this message translates to:
  /// **'Imprint'**
  String get profileImprint;

  /// No description provided for @profilePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get profilePrivacy;

  /// No description provided for @profileAppVersion.
  ///
  /// In en, this message translates to:
  /// **'App Version: {version} ({build})'**
  String profileAppVersion(String version, String build);

  /// No description provided for @profileShowRecords.
  ///
  /// In en, this message translates to:
  /// **'Show records'**
  String get profileShowRecords;

  /// No description provided for @profileShowSyncedTables.
  ///
  /// In en, this message translates to:
  /// **'Show synced tables'**
  String get profileShowSyncedTables;

  /// No description provided for @profileShowLogs.
  ///
  /// In en, this message translates to:
  /// **'Show logs'**
  String get profileShowLogs;

  /// No description provided for @langDe.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get langDe;

  /// No description provided for @langDeSubtitle.
  ///
  /// In en, this message translates to:
  /// **''**
  String get langDeSubtitle;

  /// No description provided for @langEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEn;

  /// No description provided for @langEnSubtitle.
  ///
  /// In en, this message translates to:
  /// **'(BETA) not fully translated yet'**
  String get langEnSubtitle;

  /// No description provided for @langSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get langSystem;

  /// No description provided for @langSystemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use system language'**
  String get langSystemSubtitle;

  /// No description provided for @enumDialogSearch.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get enumDialogSearch;

  /// No description provided for @enumDialogRecentlyUsed.
  ///
  /// In en, this message translates to:
  /// **'Recently used'**
  String get enumDialogRecentlyUsed;

  /// No description provided for @enumDialogListView.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get enumDialogListView;

  /// No description provided for @enumDialogChipsView.
  ///
  /// In en, this message translates to:
  /// **'Chips view'**
  String get enumDialogChipsView;

  /// No description provided for @enumDialogClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get enumDialogClose;

  /// No description provided for @enumDialogNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get enumDialogNoResults;

  /// No description provided for @enumDialogClearField.
  ///
  /// In en, this message translates to:
  /// **'Clear field content'**
  String get enumDialogClearField;

  /// No description provided for @gridRowOptions.
  ///
  /// In en, this message translates to:
  /// **'Row options'**
  String get gridRowOptions;

  /// No description provided for @gridRowEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit row'**
  String get gridRowEdit;

  /// No description provided for @gridRowCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy row'**
  String get gridRowCopy;

  /// No description provided for @gridRowDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete row'**
  String get gridRowDelete;

  /// No description provided for @gridBoolYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get gridBoolYes;

  /// No description provided for @gridBoolNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get gridBoolNo;

  /// No description provided for @gridNestedEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get gridNestedEmpty;

  /// No description provided for @gridNestedEntries.
  ///
  /// In en, this message translates to:
  /// **'{count} entries'**
  String gridNestedEntries(int count);

  /// No description provided for @gridRowEntries.
  ///
  /// In en, this message translates to:
  /// **'{count} entries'**
  String gridRowEntries(int count);

  /// No description provided for @gridNestedEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get gridNestedEdit;

  /// No description provided for @gridAddRow.
  ///
  /// In en, this message translates to:
  /// **'Add row'**
  String get gridAddRow;

  /// No description provided for @gridAddRowForm.
  ///
  /// In en, this message translates to:
  /// **'Add entry'**
  String get gridAddRowForm;

  /// No description provided for @gridAddRowFormTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add row via form'**
  String get gridAddRowFormTooltip;

  /// No description provided for @gridNoEntryRequired.
  ///
  /// In en, this message translates to:
  /// **'No entry required'**
  String get gridNoEntryRequired;

  /// No description provided for @gridRowEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit row'**
  String get gridRowEditTitle;

  /// No description provided for @gridRowEditSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get gridRowEditSave;

  /// No description provided for @gridRowAddSave.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get gridRowAddSave;

  /// No description provided for @gridRowAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add row'**
  String get gridRowAddTitle;

  /// No description provided for @gridRowAddTitleDefault.
  ///
  /// In en, this message translates to:
  /// **'Add new row'**
  String get gridRowAddTitleDefault;

  /// No description provided for @gridSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get gridSave;

  /// No description provided for @gridCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get gridCancel;

  /// No description provided for @gridClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get gridClose;

  /// No description provided for @gridView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get gridView;

  /// No description provided for @gridValidationErrors.
  ///
  /// In en, this message translates to:
  /// **'Show validation errors'**
  String get gridValidationErrors;

  /// No description provided for @gridValidationWarnings.
  ///
  /// In en, this message translates to:
  /// **'Show validation warnings'**
  String get gridValidationWarnings;

  /// No description provided for @gridNoValidationErrors.
  ///
  /// In en, this message translates to:
  /// **'No validation errors'**
  String get gridNoValidationErrors;

  /// No description provided for @versionNewAvailable.
  ///
  /// In en, this message translates to:
  /// **'New version available'**
  String get versionNewAvailable;

  /// No description provided for @versionCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current version'**
  String get versionCurrent;

  /// No description provided for @versionNewDetail.
  ///
  /// In en, this message translates to:
  /// **'Version {latest} is available (Current: {current})'**
  String versionNewDetail(String latest, String current);

  /// No description provided for @versionCurrentDetail.
  ///
  /// In en, this message translates to:
  /// **'Version {current}'**
  String versionCurrentDetail(String current);

  /// No description provided for @versionOpenRelease.
  ///
  /// In en, this message translates to:
  /// **'Open new version release'**
  String get versionOpenRelease;

  /// No description provided for @versionOpenAllReleases.
  ///
  /// In en, this message translates to:
  /// **'Open all releases'**
  String get versionOpenAllReleases;

  /// No description provided for @versionCheckForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get versionCheckForUpdates;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
