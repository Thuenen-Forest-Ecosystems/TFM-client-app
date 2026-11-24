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

  /// No description provided for @gridRowUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock row'**
  String get gridRowUnlock;

  /// No description provided for @gridRowLock.
  ///
  /// In en, this message translates to:
  /// **'Lock row'**
  String get gridRowLock;

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

  /// No description provided for @messageAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add message'**
  String get messageAddTitle;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Enter message…'**
  String get messageHint;

  /// No description provided for @messageCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get messageCancel;

  /// No description provided for @messageSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get messageSend;

  /// No description provided for @messageEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages'**
  String get messageEmpty;

  /// No description provided for @messageDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete message'**
  String get messageDeleteTitle;

  /// No description provided for @messageDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to delete this message?'**
  String get messageDeleteConfirm;

  /// No description provided for @messageDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get messageDelete;

  /// No description provided for @messageSendError.
  ///
  /// In en, this message translates to:
  /// **'Error sending message: {error}'**
  String messageSendError(String error);

  /// No description provided for @messageDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Error deleting message: {error}'**
  String messageDeleteError(String error);

  /// Banner on the recording screen when playground mode blocks editing/saving
  ///
  /// In en, this message translates to:
  /// **'Playground mode: data cannot be saved.'**
  String get recordingReadOnlyPlayground;

  /// Banner on the recording screen when the admin view is read-only
  ///
  /// In en, this message translates to:
  /// **'Admin view: data cannot be saved.'**
  String get recordingReadOnlyAdmin;

  /// Banner on the recording screen when a read-only group (Admin, nur Leserechte) opens a record
  ///
  /// In en, this message translates to:
  /// **'Read-only access: data cannot be saved.'**
  String get recordingReadOnlyGroup;

  /// No description provided for @mapSettingsTreeDisplay.
  ///
  /// In en, this message translates to:
  /// **'Tree display'**
  String get mapSettingsTreeDisplay;

  /// No description provided for @mapSettingsDiameterMultiplier.
  ///
  /// In en, this message translates to:
  /// **'Diameter multiplier: {value}x'**
  String mapSettingsDiameterMultiplier(String value);

  /// No description provided for @mapSettingsShowLabels.
  ///
  /// In en, this message translates to:
  /// **'Show labels'**
  String get mapSettingsShowLabels;

  /// No description provided for @mapSettingsTreeNumber.
  ///
  /// In en, this message translates to:
  /// **'Tree number'**
  String get mapSettingsTreeNumber;

  /// No description provided for @mapSettingsDbh.
  ///
  /// In en, this message translates to:
  /// **'DBH'**
  String get mapSettingsDbh;

  /// No description provided for @mapSettingsSpeciesCode.
  ///
  /// In en, this message translates to:
  /// **'Tree species (code)'**
  String get mapSettingsSpeciesCode;

  /// No description provided for @mapSettingsSpeciesName.
  ///
  /// In en, this message translates to:
  /// **'Tree species (name)'**
  String get mapSettingsSpeciesName;

  /// No description provided for @mapSettingsAzimuth.
  ///
  /// In en, this message translates to:
  /// **'Azimuth'**
  String get mapSettingsAzimuth;

  /// No description provided for @mapSettingsDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get mapSettingsDistance;

  /// No description provided for @mapSettingsLayers.
  ///
  /// In en, this message translates to:
  /// **'Layers'**
  String get mapSettingsLayers;

  /// No description provided for @mapSettingsEdges.
  ///
  /// In en, this message translates to:
  /// **'Stand edges'**
  String get mapSettingsEdges;

  /// No description provided for @mapSettingsBoundaryCircles.
  ///
  /// In en, this message translates to:
  /// **'Boundary circles'**
  String get mapSettingsBoundaryCircles;

  /// No description provided for @mapSettingsBoundaryCirclesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'based on DBH'**
  String get mapSettingsBoundaryCirclesSubtitle;

  /// No description provided for @mapSettingsCluster.
  ///
  /// In en, this message translates to:
  /// **'Tract'**
  String get mapSettingsCluster;

  /// No description provided for @mapSettingsClusterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tract outlines'**
  String get mapSettingsClusterSubtitle;

  /// No description provided for @mapSettingsSampleCircles.
  ///
  /// In en, this message translates to:
  /// **'Sample circles'**
  String get mapSettingsSampleCircles;

  /// No description provided for @mapSettingsSampleCirclesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'5 m · 10 m · 25 m reference circles'**
  String get mapSettingsSampleCirclesSubtitle;

  /// No description provided for @mapSettingsRegenerationCircle.
  ///
  /// In en, this message translates to:
  /// **'Regeneration circle'**
  String get mapSettingsRegenerationCircle;

  /// No description provided for @mapSettingsRegenerationCircleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sampling circle for regeneration'**
  String get mapSettingsRegenerationCircleSubtitle;

  /// No description provided for @mapSettingsRescuePoints.
  ///
  /// In en, this message translates to:
  /// **'Emergency rescue points'**
  String get mapSettingsRescuePoints;

  /// No description provided for @mapSettingsRescuePointsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only visible at high zoom levels'**
  String get mapSettingsRescuePointsSubtitle;

  /// No description provided for @mapSettingsBasemaps.
  ///
  /// In en, this message translates to:
  /// **'Base maps'**
  String get mapSettingsBasemaps;

  /// No description provided for @mapSettingsDtk25Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Topographic map of the BKG'**
  String get mapSettingsDtk25Subtitle;

  /// No description provided for @mapSettingsOpenCycleMapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Online; offline only for areas already viewed'**
  String get mapSettingsOpenCycleMapSubtitle;

  /// No description provided for @mapSettingsAerialImagery.
  ///
  /// In en, this message translates to:
  /// **'Aerial imagery (offline)'**
  String get mapSettingsAerialImagery;

  /// No description provided for @mapSettingsAerialImagerySubtitle.
  ///
  /// In en, this message translates to:
  /// **'highest zoom levels only'**
  String get mapSettingsAerialImagerySubtitle;

  /// No description provided for @mapAdminDeleteCache.
  ///
  /// In en, this message translates to:
  /// **'Delete cache'**
  String get mapAdminDeleteCache;

  /// No description provided for @mapAdminDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Do you want to delete all tiles for \"{storeName}\"?'**
  String mapAdminDeleteConfirm(String storeName);

  /// No description provided for @mapAdminCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get mapAdminCancel;

  /// No description provided for @mapAdminDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get mapAdminDelete;

  /// No description provided for @mapAdminCacheDeleted.
  ///
  /// In en, this message translates to:
  /// **'Cache for \"{storeName}\" deleted'**
  String mapAdminCacheDeleted(String storeName);

  /// No description provided for @mapAdminDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Error while deleting: {error}'**
  String mapAdminDeleteError(String error);

  /// No description provided for @mapAdminStoreAerial.
  ///
  /// In en, this message translates to:
  /// **'Aerial imagery (DOP)'**
  String get mapAdminStoreAerial;

  /// No description provided for @mapAdminTileCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tiles (~{size})'**
  String mapAdminTileCount(int count, String size);

  /// No description provided for @mapAdminNoCache.
  ///
  /// In en, this message translates to:
  /// **'No cache available'**
  String get mapAdminNoCache;

  /// No description provided for @mapTilesDownloadNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No survey points found. Please load data first.'**
  String get mapTilesDownloadNoRecords;

  /// No description provided for @mapTilesDownloadTileProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} / {total} tiles'**
  String mapTilesDownloadTileProgress(String done, String total);

  /// No description provided for @mapTilesDownloadCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get mapTilesDownloadCancel;

  /// No description provided for @mapTilesDownloadChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking data...'**
  String get mapTilesDownloadChecking;

  /// No description provided for @mapTilesDownloadLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error while loading'**
  String get mapTilesDownloadLoadError;

  /// No description provided for @mapTilesDownloadRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get mapTilesDownloadRetry;

  /// No description provided for @mapTilesDownloadNoPoints.
  ///
  /// In en, this message translates to:
  /// **'No survey points available.\nPlease synchronize data first.'**
  String get mapTilesDownloadNoPoints;

  /// No description provided for @mapTilesDownloadRecheck.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get mapTilesDownloadRecheck;

  /// No description provided for @mapTilesDownloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get mapTilesDownloadComplete;

  /// No description provided for @mapTilesDownloadResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get mapTilesDownloadResume;

  /// No description provided for @mainExitConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirmation required'**
  String get mainExitConfirmTitle;

  /// No description provided for @mainExitConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to quit the application?'**
  String get mainExitConfirmContent;

  /// No description provided for @mainExitConfirmNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get mainExitConfirmNo;

  /// No description provided for @mainExitConfirmYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get mainExitConfirmYes;

  /// No description provided for @startConfirmGoBack.
  ///
  /// In en, this message translates to:
  /// **'Confirm going back'**
  String get startConfirmGoBack;

  /// No description provided for @startLeaveRecording.
  ///
  /// In en, this message translates to:
  /// **'Leave survey'**
  String get startLeaveRecording;

  /// No description provided for @startChangesSaved.
  ///
  /// In en, this message translates to:
  /// **'Any changes have been saved automatically.'**
  String get startChangesSaved;

  /// No description provided for @startCancel.
  ///
  /// In en, this message translates to:
  /// **'cancel'**
  String get startCancel;

  /// No description provided for @startToOverview.
  ///
  /// In en, this message translates to:
  /// **'To overview'**
  String get startToOverview;

  /// No description provided for @loginSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get loginSessionExpired;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get loginFailed;

  /// No description provided for @loginInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid login credentials. Please check your email and password.'**
  String get loginInvalidCredentials;

  /// No description provided for @loginEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Email address has not been confirmed yet. Please check your inbox.'**
  String get loginEmailNotConfirmed;

  /// No description provided for @loginAuthError.
  ///
  /// In en, this message translates to:
  /// **'Sign-in error: {message}'**
  String loginAuthError(String message);

  /// No description provided for @loginProxyError.
  ///
  /// In en, this message translates to:
  /// **'Proxy connection error: The configured proxy server cannot be reached.\n\nPlease check:\n• Your proxy settings via \"Network settings (proxy)\" below\n• Whether the proxy server is reachable\n• Your Windows system proxy settings\n\nTip: If you do not need a proxy, disable the proxy function in the network settings.'**
  String get loginProxyError;

  /// No description provided for @loginTimeoutError.
  ///
  /// In en, this message translates to:
  /// **'Connection timeout: The server could not be reached in time.\n\nPlease try:\n• A different internet connection (e.g. Wi-Fi instead of mobile data)\n• Again later\n• Contacting your network administrator if you are on a corporate or institutional network'**
  String get loginTimeoutError;

  /// No description provided for @loginCertificateError.
  ///
  /// In en, this message translates to:
  /// **'Connection error: Please check your internet connection and make sure that the date and time are set correctly.\n\nIf the problem persists, contact bwi-support@thuenen.de.'**
  String get loginCertificateError;

  /// No description provided for @loginUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred: {error}'**
  String loginUnexpectedError(String error);

  /// No description provided for @loginOfflineFailed.
  ///
  /// In en, this message translates to:
  /// **'Offline sign-in failed'**
  String get loginOfflineFailed;

  /// No description provided for @loginEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginEmail;

  /// No description provided for @loginEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address'**
  String get loginEmailRequired;

  /// No description provided for @loginEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get loginEmailInvalid;

  /// No description provided for @loginPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPassword;

  /// No description provided for @loginPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get loginPasswordRequired;

  /// No description provided for @loginPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'The password must be at least 6 characters long'**
  String get loginPasswordTooShort;

  /// No description provided for @loginSubmit.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginSubmit;

  /// No description provided for @loginOfflineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline mode: No internet connection'**
  String get loginOfflineMode;

  /// No description provided for @loginNoInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get loginNoInternet;

  /// No description provided for @loginNoInternetFirstLogin.
  ///
  /// In en, this message translates to:
  /// **'Please connect to the internet to sign in for the first time.'**
  String get loginNoInternetFirstLogin;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get loginForgotPassword;

  /// No description provided for @loginNetworkSettings.
  ///
  /// In en, this message translates to:
  /// **'Network settings (proxy)'**
  String get loginNetworkSettings;

  /// No description provided for @schemaLogout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get schemaLogout;

  /// No description provided for @orderClusterByDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance (GPS required)'**
  String get orderClusterByDistance;

  /// No description provided for @orderClusterByUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Modified on'**
  String get orderClusterByUpdatedAt;

  /// No description provided for @orderClusterByClusterName.
  ///
  /// In en, this message translates to:
  /// **'Tract number'**
  String get orderClusterByClusterName;

  /// No description provided for @clusterInfoNoRecord.
  ///
  /// In en, this message translates to:
  /// **'No record available'**
  String get clusterInfoNoRecord;

  /// No description provided for @clusterInfoNoClusterInfo.
  ///
  /// In en, this message translates to:
  /// **'No tract information available'**
  String get clusterInfoNoClusterInfo;

  /// No description provided for @clusterInfoShowTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show tract information'**
  String get clusterInfoShowTooltip;

  /// No description provided for @clusterInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get clusterInfoTitle;

  /// No description provided for @clusterInfoClusterPlot.
  ///
  /// In en, this message translates to:
  /// **'Tract: {clusterName} / Corner: {plotName}'**
  String clusterInfoClusterPlot(String clusterName, String plotName);

  /// No description provided for @clusterInfoClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get clusterInfoClose;

  /// No description provided for @clusterInfoUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated on'**
  String get clusterInfoUpdatedAt;

  /// No description provided for @clusterInfoUpdatedBy.
  ///
  /// In en, this message translates to:
  /// **'Updated by'**
  String get clusterInfoUpdatedBy;

  /// No description provided for @clusterInfoTroop.
  ///
  /// In en, this message translates to:
  /// **'Crew'**
  String get clusterInfoTroop;

  /// No description provided for @clusterInfoYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get clusterInfoYes;

  /// No description provided for @clusterInfoNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get clusterInfoNo;

  /// No description provided for @clusterInfoListEntries.
  ///
  /// In en, this message translates to:
  /// **'List ({count} entries)'**
  String clusterInfoListEntries(int count);

  /// No description provided for @clusterInfoObjectFields.
  ///
  /// In en, this message translates to:
  /// **'Object ({count} fields)'**
  String clusterInfoObjectFields(int count);

  /// No description provided for @recordsSelectionSearchCluster.
  ///
  /// In en, this message translates to:
  /// **'Search tract number...'**
  String get recordsSelectionSearchCluster;

  /// No description provided for @recordsSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Plot corners'**
  String get recordsSelectionTitle;

  /// No description provided for @recordsSelectionNoneAssigned.
  ///
  /// In en, this message translates to:
  /// **'No plot corner has been assigned to you yet.'**
  String get recordsSelectionNoneAssigned;

  /// No description provided for @schemaSelectionError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String schemaSelectionError(String error);

  /// No description provided for @schemaSelectionLoading1.
  ///
  /// In en, this message translates to:
  /// **'Please wait...'**
  String get schemaSelectionLoading1;

  /// No description provided for @schemaSelectionLoading2.
  ///
  /// In en, this message translates to:
  /// **'This may take a moment...'**
  String get schemaSelectionLoading2;

  /// No description provided for @schemaSelectionLoading3.
  ///
  /// In en, this message translates to:
  /// **'... not much longer now...'**
  String get schemaSelectionLoading3;

  /// No description provided for @schemaSelectionLoading4.
  ///
  /// In en, this message translates to:
  /// **'Almost there...'**
  String get schemaSelectionLoading4;

  /// No description provided for @schemaSelectionLoading5.
  ///
  /// In en, this message translates to:
  /// **'Just a little more patience...'**
  String get schemaSelectionLoading5;

  /// No description provided for @schemaSelectionLoading6.
  ///
  /// In en, this message translates to:
  /// **'Synchronizing data...'**
  String get schemaSelectionLoading6;

  /// No description provided for @schemaSelectionLoading7.
  ///
  /// In en, this message translates to:
  /// **'Nearly done...'**
  String get schemaSelectionLoading7;

  /// No description provided for @schemaSelectionNoSchemas.
  ///
  /// In en, this message translates to:
  /// **'No schemas available'**
  String get schemaSelectionNoSchemas;

  /// No description provided for @schemaSelectionPleaseSync.
  ///
  /// In en, this message translates to:
  /// **'Please synchronize the data'**
  String get schemaSelectionPleaseSync;

  /// No description provided for @loggerTitle.
  ///
  /// In en, this message translates to:
  /// **'Application logs'**
  String get loggerTitle;

  /// No description provided for @loggerAddTestLog.
  ///
  /// In en, this message translates to:
  /// **'Add test log'**
  String get loggerAddTestLog;

  /// No description provided for @loggerFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get loggerFilter;

  /// No description provided for @loggerFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All logs'**
  String get loggerFilterAll;

  /// No description provided for @loggerFilterInfo.
  ///
  /// In en, this message translates to:
  /// **'Info & higher'**
  String get loggerFilterInfo;

  /// No description provided for @loggerFilterWarning.
  ///
  /// In en, this message translates to:
  /// **'Warnings & errors'**
  String get loggerFilterWarning;

  /// No description provided for @loggerFilterError.
  ///
  /// In en, this message translates to:
  /// **'Errors only'**
  String get loggerFilterError;

  /// No description provided for @loggerAutoScrollOn.
  ///
  /// In en, this message translates to:
  /// **'Auto-scroll on'**
  String get loggerAutoScrollOn;

  /// No description provided for @loggerAutoScrollOff.
  ///
  /// In en, this message translates to:
  /// **'Auto-scroll off'**
  String get loggerAutoScrollOff;

  /// No description provided for @loggerCopyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all logs'**
  String get loggerCopyAll;

  /// No description provided for @loggerCopiedAll.
  ///
  /// In en, this message translates to:
  /// **'Logs copied to clipboard'**
  String get loggerCopiedAll;

  /// No description provided for @loggerClear.
  ///
  /// In en, this message translates to:
  /// **'Clear logs'**
  String get loggerClear;

  /// No description provided for @loggerClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear logs?'**
  String get loggerClearTitle;

  /// No description provided for @loggerClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to delete all logs?'**
  String get loggerClearConfirm;

  /// No description provided for @loggerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get loggerCancel;

  /// No description provided for @loggerDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get loggerDelete;

  /// No description provided for @loggerEntryCount.
  ///
  /// In en, this message translates to:
  /// **'{count} entries'**
  String loggerEntryCount(int count);

  /// No description provided for @loggerFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter: {level}'**
  String loggerFilterLabel(String level);

  /// No description provided for @loggerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No logs available'**
  String get loggerEmpty;

  /// No description provided for @loggerCopiedEntry.
  ///
  /// In en, this message translates to:
  /// **'Log entry copied'**
  String get loggerCopiedEntry;

  /// No description provided for @recordsRawColCluster.
  ///
  /// In en, this message translates to:
  /// **'Tract'**
  String get recordsRawColCluster;

  /// No description provided for @recordsRawColPlot.
  ///
  /// In en, this message translates to:
  /// **'Corner'**
  String get recordsRawColPlot;

  /// No description provided for @recordsRawColValidatedBy.
  ///
  /// In en, this message translates to:
  /// **'Validated with schema'**
  String get recordsRawColValidatedBy;

  /// No description provided for @recordsRawColValid.
  ///
  /// In en, this message translates to:
  /// **'Valid'**
  String get recordsRawColValid;

  /// No description provided for @recordsRawColPlotId.
  ///
  /// In en, this message translates to:
  /// **'Corner ID'**
  String get recordsRawColPlotId;

  /// No description provided for @recordsRawColClusterId.
  ///
  /// In en, this message translates to:
  /// **'Tract ID'**
  String get recordsRawColClusterId;

  /// No description provided for @recordsRawColAdministration.
  ///
  /// In en, this message translates to:
  /// **'Administration'**
  String get recordsRawColAdministration;

  /// No description provided for @recordsRawColProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get recordsRawColProvider;

  /// No description provided for @recordsRawColState.
  ///
  /// In en, this message translates to:
  /// **'Federal state'**
  String get recordsRawColState;

  /// No description provided for @recordsRawColTroop.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get recordsRawColTroop;

  /// No description provided for @recordsRawColUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get recordsRawColUpdatedAt;

  /// No description provided for @recordsRawColLocalUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated locally'**
  String get recordsRawColLocalUpdatedAt;

  /// No description provided for @recordsRawColCompletedState.
  ///
  /// In en, this message translates to:
  /// **'Completed (federal state)'**
  String get recordsRawColCompletedState;

  /// No description provided for @recordsRawColCompletedTroop.
  ///
  /// In en, this message translates to:
  /// **'Completed (team)'**
  String get recordsRawColCompletedTroop;

  /// No description provided for @recordsRawColCompletedAdministration.
  ///
  /// In en, this message translates to:
  /// **'Completed (administration)'**
  String get recordsRawColCompletedAdministration;

  /// No description provided for @recordsRawColToBeRecorded.
  ///
  /// In en, this message translates to:
  /// **'To be recorded'**
  String get recordsRawColToBeRecorded;

  /// No description provided for @recordsRawColNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get recordsRawColNote;

  /// No description provided for @recordsRawColProperties.
  ///
  /// In en, this message translates to:
  /// **'Properties (JSON)'**
  String get recordsRawColProperties;

  /// No description provided for @recordsRawColPreviousProperties.
  ///
  /// In en, this message translates to:
  /// **'Previous properties (JSON)'**
  String get recordsRawColPreviousProperties;

  /// No description provided for @recordsRawColPreviousPosition.
  ///
  /// In en, this message translates to:
  /// **'Previous position (JSON)'**
  String get recordsRawColPreviousPosition;

  /// No description provided for @recordsRawTitle.
  ///
  /// In en, this message translates to:
  /// **'Raw data - records'**
  String get recordsRawTitle;

  /// No description provided for @recordsRawRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get recordsRawRefresh;

  /// No description provided for @recordsRawTotal.
  ///
  /// In en, this message translates to:
  /// **'Total: {count} records'**
  String recordsRawTotal(int count);

  /// No description provided for @recordsRawPageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}'**
  String recordsRawPageOf(int page, int total);

  /// No description provided for @recordsRawLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error loading records: {error}'**
  String recordsRawLoadError(String error);

  /// No description provided for @recordsRawRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get recordsRawRetry;

  /// No description provided for @recordsRawEmpty.
  ///
  /// In en, this message translates to:
  /// **'No records found'**
  String get recordsRawEmpty;

  /// No description provided for @recordsRawFirstPage.
  ///
  /// In en, this message translates to:
  /// **'First page'**
  String get recordsRawFirstPage;

  /// No description provided for @recordsRawPreviousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get recordsRawPreviousPage;

  /// No description provided for @recordsRawNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get recordsRawNextPage;

  /// No description provided for @recordsRawLastPage.
  ///
  /// In en, this message translates to:
  /// **'Last page'**
  String get recordsRawLastPage;

  /// No description provided for @syncedTablesReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get syncedTablesReload;

  /// No description provided for @syncedTablesError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String syncedTablesError(String error);

  /// No description provided for @syncedTablesRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get syncedTablesRetry;

  /// No description provided for @syncedTablesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tables found.'**
  String get syncedTablesEmpty;

  /// No description provided for @uploadFailuresRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore upload?'**
  String get uploadFailuresRestoreTitle;

  /// No description provided for @uploadFailuresRestoreContent.
  ///
  /// In en, this message translates to:
  /// **'The saved state of {title} will be applied locally (overwriting the current local state of this record) and uploaded again with the next sync.\n\nIf the upload fails again, the entry will reappear in this list.'**
  String uploadFailuresRestoreContent(String title);

  /// No description provided for @uploadFailuresCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get uploadFailuresCancel;

  /// No description provided for @uploadFailuresRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get uploadFailuresRestore;

  /// No description provided for @uploadFailuresRestoredSnack.
  ///
  /// In en, this message translates to:
  /// **'Restored — will be uploaded again with the next sync.'**
  String get uploadFailuresRestoredSnack;

  /// No description provided for @uploadFailuresRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed: {error}'**
  String uploadFailuresRestoreFailed(String error);

  /// No description provided for @uploadFailuresRestoreAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore all {count} entries?'**
  String uploadFailuresRestoreAllTitle(int count);

  /// No description provided for @uploadFailuresRestoreAllContent.
  ///
  /// In en, this message translates to:
  /// **'All saved states will be applied locally (oldest first) and uploaded again with the next sync. The current local state of the affected records will be overwritten.'**
  String get uploadFailuresRestoreAllContent;

  /// No description provided for @uploadFailuresRestoreAll.
  ///
  /// In en, this message translates to:
  /// **'Restore all'**
  String get uploadFailuresRestoreAll;

  /// No description provided for @uploadFailuresRestoreAllSuccess.
  ///
  /// In en, this message translates to:
  /// **'All entries restored — upload will follow with the next sync.'**
  String get uploadFailuresRestoreAllSuccess;

  /// No description provided for @uploadFailuresRestoreAllErrors.
  ///
  /// In en, this message translates to:
  /// **'{count} entries could not be applied:\n{errors}'**
  String uploadFailuresRestoreAllErrors(int count, String errors);

  /// No description provided for @uploadFailuresDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently discard entry?'**
  String get uploadFailuresDiscardTitle;

  /// No description provided for @uploadFailuresDiscardContent.
  ///
  /// In en, this message translates to:
  /// **'The saved data of {title} will be deleted and can no longer be restored afterwards.'**
  String uploadFailuresDiscardContent(String title);

  /// No description provided for @uploadFailuresDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get uploadFailuresDiscard;

  /// No description provided for @uploadFailuresDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String uploadFailuresDeleteFailed(String error);

  /// No description provided for @uploadFailuresTractTitle.
  ///
  /// In en, this message translates to:
  /// **'Tract {cluster} / {plot}'**
  String uploadFailuresTractTitle(String cluster, String plot);

  /// No description provided for @uploadFailuresReasonIgnored.
  ///
  /// In en, this message translates to:
  /// **'Ignored by the server (no write permission for this record)'**
  String get uploadFailuresReasonIgnored;

  /// No description provided for @uploadFailuresReasonRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected by the server'**
  String get uploadFailuresReasonRejected;

  /// No description provided for @uploadFailuresReasonUnattempted.
  ///
  /// In en, this message translates to:
  /// **'Not attempted (a previous upload of the same transfer was rejected)'**
  String get uploadFailuresReasonUnattempted;

  /// No description provided for @uploadFailuresReasonUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get uploadFailuresReasonUnknown;

  /// No description provided for @uploadFailuresTitle.
  ///
  /// In en, this message translates to:
  /// **'Backups'**
  String get uploadFailuresTitle;

  /// No description provided for @uploadFailuresActiveDbTab.
  ///
  /// In en, this message translates to:
  /// **'Active DB'**
  String get uploadFailuresActiveDbTab;

  /// No description provided for @uploadFailuresActiveDbTabCount.
  ///
  /// In en, this message translates to:
  /// **'Active DB ({count})'**
  String uploadFailuresActiveDbTabCount(int count);

  /// No description provided for @uploadFailuresActiveDatabase.
  ///
  /// In en, this message translates to:
  /// **'Active database'**
  String get uploadFailuresActiveDatabase;

  /// No description provided for @uploadFailuresNotAppliedSuffix.
  ///
  /// In en, this message translates to:
  /// **' · {count} not applied'**
  String uploadFailuresNotAppliedSuffix(int count);

  /// No description provided for @uploadFailuresQuarantineExplanation.
  ///
  /// In en, this message translates to:
  /// **'The server did not accept these changes. The data is saved locally and can be transferred again.'**
  String get uploadFailuresQuarantineExplanation;

  /// No description provided for @uploadFailuresAllAccepted.
  ///
  /// In en, this message translates to:
  /// **'All uploads of this database were accepted by the server.'**
  String get uploadFailuresAllAccepted;

  /// No description provided for @uploadFailuresRestoreAllCount.
  ///
  /// In en, this message translates to:
  /// **'Restore all {count}'**
  String uploadFailuresRestoreAllCount(int count);

  /// No description provided for @uploadFailuresEmpty.
  ///
  /// In en, this message translates to:
  /// **'No entries — all uploads were accepted.'**
  String get uploadFailuresEmpty;

  /// No description provided for @uploadFailuresRecoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore record?'**
  String get uploadFailuresRecoverTitle;

  /// No description provided for @uploadFailuresRecoverContent.
  ///
  /// In en, this message translates to:
  /// **'The state of {title} from \"{fileName}\" will be copied into the active database (overwriting the state there) and uploaded with the next sync.\n\nIf the server rejects the upload, it will appear in the \"Active DB\" tab. The source file remains unchanged.'**
  String uploadFailuresRecoverContent(String title, String fileName);

  /// No description provided for @uploadFailuresRecoveredSnack.
  ///
  /// In en, this message translates to:
  /// **'Copied into the active database — upload will follow with the next sync.'**
  String get uploadFailuresRecoveredSnack;

  /// No description provided for @uploadFailuresRecordNotFound.
  ///
  /// In en, this message translates to:
  /// **'Record no longer found in \"{fileName}\".'**
  String uploadFailuresRecordNotFound(String fileName);

  /// No description provided for @uploadFailuresRecoverAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore {count} records that were never uploaded?'**
  String uploadFailuresRecoverAllTitle(int count);

  /// No description provided for @uploadFailuresRecoverAllContent.
  ///
  /// In en, this message translates to:
  /// **'All records with changes that were never uploaded will be copied into the active database (overwriting the state there) and uploaded with the next sync.'**
  String get uploadFailuresRecoverAllContent;

  /// No description provided for @uploadFailuresRecoverAllSuccess.
  ///
  /// In en, this message translates to:
  /// **'{count} records copied — upload will follow with the next sync.'**
  String uploadFailuresRecoverAllSuccess(int count);

  /// No description provided for @uploadFailuresRecoverAllPartial.
  ///
  /// In en, this message translates to:
  /// **'{recovered} copied, {failed} failed:\n{errors}'**
  String uploadFailuresRecoverAllPartial(
    int recovered,
    int failed,
    String errors,
  );

  /// No description provided for @uploadFailuresTractLabel.
  ///
  /// In en, this message translates to:
  /// **'Tract {title}'**
  String uploadFailuresTractLabel(String title);

  /// No description provided for @uploadFailuresReadError.
  ///
  /// In en, this message translates to:
  /// **'Error reading \"{fileName}\": {error}'**
  String uploadFailuresReadError(String fileName, String error);

  /// No description provided for @uploadFailuresFileSummary.
  ///
  /// In en, this message translates to:
  /// **'{fileName} · {count} records'**
  String uploadFailuresFileSummary(String fileName, int count);

  /// No description provided for @uploadFailuresNeverUploadedSuffix.
  ///
  /// In en, this message translates to:
  /// **' · {count} never uploaded'**
  String uploadFailuresNeverUploadedSuffix(int count);

  /// No description provided for @uploadFailuresPendingExplanation.
  ///
  /// In en, this message translates to:
  /// **'Records marked \"Not uploaded\" exist ONLY in this file — the server never received them.'**
  String get uploadFailuresPendingExplanation;

  /// No description provided for @uploadFailuresAllUploadedExplanation.
  ///
  /// In en, this message translates to:
  /// **'All records in this file have also been uploaded to the server or originate from it.'**
  String get uploadFailuresAllUploadedExplanation;

  /// No description provided for @uploadFailuresReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get uploadFailuresReload;

  /// No description provided for @uploadFailuresNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No records in this file.'**
  String get uploadFailuresNoRecords;

  /// No description provided for @uploadFailuresNotUploaded.
  ///
  /// In en, this message translates to:
  /// **'Not uploaded'**
  String get uploadFailuresNotUploaded;

  /// No description provided for @diagnosticExportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Save diagnostic data'**
  String get diagnosticExportDialogTitle;

  /// No description provided for @diagnosticExportSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved: {path}'**
  String diagnosticExportSaved(String path);

  /// No description provided for @diagnosticExportError.
  ///
  /// In en, this message translates to:
  /// **'Error while saving: {error}'**
  String diagnosticExportError(String error);

  /// No description provided for @diagnosticExportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save diagnostic data as JSON'**
  String get diagnosticExportTooltip;

  /// No description provided for @playgroundModeButtonExit.
  ///
  /// In en, this message translates to:
  /// **'Exit playground mode'**
  String get playgroundModeButtonExit;

  /// No description provided for @playgroundModeButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Playground'**
  String get playgroundModeButtonLabel;

  /// No description provided for @playgroundModeButtonActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate playground mode (saving not possible)'**
  String get playgroundModeButtonActivate;

  /// No description provided for @recordsExportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Save records'**
  String get recordsExportDialogTitle;

  /// No description provided for @recordsExportSaved.
  ///
  /// In en, this message translates to:
  /// **'{count} records saved:\n{path}'**
  String recordsExportSaved(int count, String path);

  /// No description provided for @recordsExportError.
  ///
  /// In en, this message translates to:
  /// **'Error while exporting: {error}'**
  String recordsExportError(String error);

  /// No description provided for @recordsExportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Export all records as JSON'**
  String get recordsExportTooltip;

  /// No description provided for @recordCardNotAccessible.
  ///
  /// In en, this message translates to:
  /// **'Not accessible'**
  String get recordCardNotAccessible;

  /// No description provided for @recordCardNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get recordCardNever;

  /// No description provided for @recordCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Tract: {cluster} | Corner: {plot}'**
  String recordCardTitle(String cluster, String plot);

  /// No description provided for @submissionSuccessDialogDeliveredTitle.
  ///
  /// In en, this message translates to:
  /// **'Submitted and confirmed by the server'**
  String get submissionSuccessDialogDeliveredTitle;

  /// No description provided for @submissionSuccessDialogUploadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved — uploading …'**
  String get submissionSuccessDialogUploadingTitle;

  /// No description provided for @submissionSuccessDialogPendingOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved on the device'**
  String get submissionSuccessDialogPendingOfflineTitle;

  /// No description provided for @submissionSuccessDialogRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer not accepted'**
  String get submissionSuccessDialogRejectedTitle;

  /// No description provided for @submissionSuccessDialogDeliveredSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The recording has arrived on the server.'**
  String get submissionSuccessDialogDeliveredSubtitle;

  /// No description provided for @submissionSuccessDialogUploadingQueue.
  ///
  /// In en, this message translates to:
  /// **'{count} changes still in the queue.'**
  String submissionSuccessDialogUploadingQueue(int count);

  /// No description provided for @submissionSuccessDialogUploadingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The transfer is in progress.'**
  String get submissionSuccessDialogUploadingSubtitle;

  /// No description provided for @submissionSuccessDialogPendingOfflineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Not yet transferred — this happens automatically as soon as a connection is available again. Please go online and check the sync status before finishing the field day.'**
  String get submissionSuccessDialogPendingOfflineSubtitle;

  /// No description provided for @submissionSuccessDialogRejectedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The server did not accept this change. The data is saved locally and can be restored under \"Backups\" in the profile.'**
  String get submissionSuccessDialogRejectedSubtitle;

  /// No description provided for @submissionSuccessDialogTractCorner.
  ///
  /// In en, this message translates to:
  /// **'Tract {cluster} · Corner {plot}'**
  String submissionSuccessDialogTractCorner(String cluster, String plot);

  /// No description provided for @submissionSuccessDialogOtherCorners.
  ///
  /// In en, this message translates to:
  /// **'Other corners in tract {cluster}:'**
  String submissionSuccessDialogOtherCorners(String cluster);

  /// No description provided for @submissionSuccessDialogCorner.
  ///
  /// In en, this message translates to:
  /// **'Corner {plot}'**
  String submissionSuccessDialogCorner(String plot);

  /// No description provided for @submissionSuccessDialogCompletedAt.
  ///
  /// In en, this message translates to:
  /// **'Completed: {date}'**
  String submissionSuccessDialogCompletedAt(String date);

  /// No description provided for @submissionSuccessDialogEditedAt.
  ///
  /// In en, this message translates to:
  /// **'Edited: {date}'**
  String submissionSuccessDialogEditedAt(String date);

  /// No description provided for @submissionSuccessDialogNotEdited.
  ///
  /// In en, this message translates to:
  /// **'Not edited'**
  String get submissionSuccessDialogNotEdited;

  /// No description provided for @submissionSuccessDialogNoOtherCorners.
  ///
  /// In en, this message translates to:
  /// **'No other corners in this tract.'**
  String get submissionSuccessDialogNoOtherCorners;

  /// No description provided for @submissionSuccessDialogBackToOverview.
  ///
  /// In en, this message translates to:
  /// **'Back to overview'**
  String get submissionSuccessDialogBackToOverview;

  /// No description provided for @syncStatusButtonLastSync.
  ///
  /// In en, this message translates to:
  /// **'Last sync'**
  String get syncStatusButtonLastSync;

  /// No description provided for @syncStatusButtonNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get syncStatusButtonNever;

  /// No description provided for @syncStatusButtonCertificateHint.
  ///
  /// In en, this message translates to:
  /// **'Have you already run the \"Install SSL Certificates\" application? If not, please find the application and run it.'**
  String get syncStatusButtonCertificateHint;

  /// No description provided for @syncStatusButtonQueue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get syncStatusButtonQueue;

  /// No description provided for @syncStatusButtonPending.
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String syncStatusButtonPending(int count);

  /// No description provided for @syncStatusButtonUploadFailures.
  ///
  /// In en, this message translates to:
  /// **'⚠ {count} upload(s) not accepted by the server'**
  String syncStatusButtonUploadFailures(int count);

  /// No description provided for @syncStatusButtonUploadFailuresHint.
  ///
  /// In en, this message translates to:
  /// **'The data is saved locally (upload_failures). Please create a diagnostic export and send it to support.'**
  String get syncStatusButtonUploadFailuresHint;

  /// No description provided for @syncStatusButtonAndMore.
  ///
  /// In en, this message translates to:
  /// **'… and {count} more'**
  String syncStatusButtonAndMore(int count);

  /// No description provided for @syncStatusButtonNotSynced.
  ///
  /// In en, this message translates to:
  /// **'Not synced'**
  String get syncStatusButtonNotSynced;

  /// No description provided for @syncStatusButtonRecordCount.
  ///
  /// In en, this message translates to:
  /// **'{count} records'**
  String syncStatusButtonRecordCount(int count);

  /// No description provided for @syncStatusButtonServerSql.
  ///
  /// In en, this message translates to:
  /// **'Server diagnostic SQL:'**
  String get syncStatusButtonServerSql;

  /// No description provided for @syncStatusButtonCopySql.
  ///
  /// In en, this message translates to:
  /// **'Copy SQL'**
  String get syncStatusButtonCopySql;

  /// No description provided for @syncStatusButtonSqlCopied.
  ///
  /// In en, this message translates to:
  /// **'SQL copied to clipboard'**
  String get syncStatusButtonSqlCopied;

  /// No description provided for @syncStatusButtonRecordRow.
  ///
  /// In en, this message translates to:
  /// **'{cluster} / {plot}\nLocal: {localTs}  •  Server: {serverTs}'**
  String syncStatusButtonRecordRow(
    String cluster,
    String plot,
    String localTs,
    String serverTs,
  );

  /// No description provided for @densitySettingsCompactTable.
  ///
  /// In en, this message translates to:
  /// **'Compact table mode'**
  String get densitySettingsCompactTable;

  /// No description provided for @densitySettingsReducedRowHeight.
  ///
  /// In en, this message translates to:
  /// **'Reduced row height (for stylus/tablet)'**
  String get densitySettingsReducedRowHeight;

  /// No description provided for @densitySettingsStandardRowHeight.
  ///
  /// In en, this message translates to:
  /// **'Standard row height'**
  String get densitySettingsStandardRowHeight;

  /// No description provided for @keyboardSettingsFloatingNumpad.
  ///
  /// In en, this message translates to:
  /// **'Floating number pad'**
  String get keyboardSettingsFloatingNumpad;

  /// No description provided for @keyboardSettingsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available on this platform.'**
  String get keyboardSettingsNotAvailable;

  /// No description provided for @keyboardSettingsNumpadForNumbers.
  ///
  /// In en, this message translates to:
  /// **'Number pad for numeric fields'**
  String get keyboardSettingsNumpadForNumbers;

  /// No description provided for @keyboardSettingsSystemKeyboardForNumbers.
  ///
  /// In en, this message translates to:
  /// **'System keyboard for numeric fields'**
  String get keyboardSettingsSystemKeyboardForNumbers;

  /// No description provided for @profileLogoutUnsyncedWarning.
  ///
  /// In en, this message translates to:
  /// **'There is data on this device that has not been uploaded yet!'**
  String get profileLogoutUnsyncedWarning;

  /// No description provided for @profileLogoutPendingUploads.
  ///
  /// In en, this message translates to:
  /// **'• {count} change(s) waiting to be uploaded'**
  String profileLogoutPendingUploads(int count);

  /// No description provided for @profileLogoutQuarantined.
  ///
  /// In en, this message translates to:
  /// **'• {count} saved entry/entries under \"Backups\"'**
  String profileLogoutQuarantined(int count);

  /// No description provided for @profileLogoutDataLostHint.
  ///
  /// In en, this message translates to:
  /// **'This data will then be irretrievably lost. Please synchronize first — or create a backup.'**
  String get profileLogoutDataLostHint;

  /// No description provided for @profileBackupsWithCount.
  ///
  /// In en, this message translates to:
  /// **'Backups ({count})'**
  String profileBackupsWithCount(int count);

  /// No description provided for @profileBackups.
  ///
  /// In en, this message translates to:
  /// **'Backups'**
  String get profileBackups;

  /// No description provided for @profileBackupsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore data that has not been uploaded'**
  String get profileBackupsSubtitle;

  /// No description provided for @propertiesEditNoSchemaFound.
  ///
  /// In en, this message translates to:
  /// **'No schema found for: {intervalName}'**
  String propertiesEditNoSchemaFound(String intervalName);

  /// No description provided for @propertiesEditControlTroopStyleMissing.
  ///
  /// In en, this message translates to:
  /// **'Control troop requires the style_control schema, but it is not available'**
  String get propertiesEditControlTroopStyleMissing;

  /// No description provided for @propertiesEditSchemaLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error loading the schema: {error}'**
  String propertiesEditSchemaLoadError(String error);

  /// No description provided for @propertiesEditNewRecordNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'New records cannot be created here.'**
  String get propertiesEditNewRecordNotAllowed;

  /// No description provided for @propertiesEditPlaygroundNoSave.
  ///
  /// In en, this message translates to:
  /// **'🧪 Playground mode active – saving not possible.'**
  String get propertiesEditPlaygroundNoSave;

  /// No description provided for @propertiesEditAdminViewNoSave.
  ///
  /// In en, this message translates to:
  /// **'Admin view – saving not possible.'**
  String get propertiesEditAdminViewNoSave;

  /// No description provided for @propertiesEditSaveError.
  ///
  /// In en, this message translates to:
  /// **'Error saving: {error}'**
  String propertiesEditSaveError(String error);

  /// No description provided for @propertiesEditInformation.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get propertiesEditInformation;

  /// No description provided for @propertiesEditCluster.
  ///
  /// In en, this message translates to:
  /// **'Tract: {cluster}'**
  String propertiesEditCluster(String cluster);

  /// No description provided for @propertiesEditPlot.
  ///
  /// In en, this message translates to:
  /// **'Corner: {plot}'**
  String propertiesEditPlot(String plot);

  /// No description provided for @propertiesEditDone.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get propertiesEditDone;

  /// No description provided for @proxyServiceTimeoutAfter10s.
  ///
  /// In en, this message translates to:
  /// **'Connection aborted after 10 seconds'**
  String get proxyServiceTimeoutAfter10s;

  /// No description provided for @proxyServiceWebSocketTimeout.
  ///
  /// In en, this message translates to:
  /// **'WebSocket connection timeout'**
  String get proxyServiceWebSocketTimeout;

  /// No description provided for @proxyServiceWebSocketWorks.
  ///
  /// In en, this message translates to:
  /// **'WebSocket is working'**
  String get proxyServiceWebSocketWorks;

  /// No description provided for @proxyServiceHttpSuccess.
  ///
  /// In en, this message translates to:
  /// **'HTTP connection successful ({statusCode})'**
  String proxyServiceHttpSuccess(int statusCode);

  /// No description provided for @proxyServiceServerStatus.
  ///
  /// In en, this message translates to:
  /// **'Server responded with status {statusCode}'**
  String proxyServiceServerStatus(int statusCode);

  /// No description provided for @proxyServiceConnectionRefused.
  ///
  /// In en, this message translates to:
  /// **'Connection refused. Please check:\n• Is the proxy running on {address}:{port}?\n• Is the proxy address correct?\n• Firewall settings?'**
  String proxyServiceConnectionRefused(String address, int port);

  /// No description provided for @proxyServiceHostUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Host unreachable: {address}'**
  String proxyServiceHostUnreachable(String address);

  /// No description provided for @proxyServiceNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error: {error}'**
  String proxyServiceNetworkError(String error);

  /// No description provided for @proxyServiceTimeout.
  ///
  /// In en, this message translates to:
  /// **'Timeout: {message}'**
  String proxyServiceTimeout(String message);

  /// No description provided for @proxyServiceNoResponse10s.
  ///
  /// In en, this message translates to:
  /// **'No response after 10 seconds'**
  String get proxyServiceNoResponse10s;

  /// No description provided for @proxyServiceUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error: {error}'**
  String proxyServiceUnexpectedError(String error);

  /// No description provided for @proxySettingsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error loading settings: {error}'**
  String proxySettingsLoadError(String error);

  /// No description provided for @proxySettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Proxy settings saved'**
  String get proxySettingsSaved;

  /// No description provided for @proxySettingsSaveError.
  ///
  /// In en, this message translates to:
  /// **'Error saving: {error}'**
  String proxySettingsSaveError(String error);

  /// No description provided for @proxySettingsProxyDisabled.
  ///
  /// In en, this message translates to:
  /// **'Proxy is disabled'**
  String get proxySettingsProxyDisabled;

  /// No description provided for @proxySettingsTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Test failed: {error}'**
  String proxySettingsTestFailed(String error);

  /// No description provided for @proxySettingsRestartTitle.
  ///
  /// In en, this message translates to:
  /// **'Restart required'**
  String get proxySettingsRestartTitle;

  /// No description provided for @proxySettingsRestartContent.
  ///
  /// In en, this message translates to:
  /// **'The proxy settings will take effect the next time the application starts.\n\nDo you want to close the application now?'**
  String get proxySettingsRestartContent;

  /// No description provided for @proxySettingsRestartLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get proxySettingsRestartLater;

  /// No description provided for @proxySettingsCloseApp.
  ///
  /// In en, this message translates to:
  /// **'Close application'**
  String get proxySettingsCloseApp;

  /// No description provided for @proxySettingsEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable proxy'**
  String get proxySettingsEnable;

  /// No description provided for @proxySettingsEnableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect via proxy server'**
  String get proxySettingsEnableSubtitle;

  /// No description provided for @proxySettingsUseSystemProxy.
  ///
  /// In en, this message translates to:
  /// **'Use system proxy'**
  String get proxySettingsUseSystemProxy;

  /// No description provided for @proxySettingsUseSystemProxySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Uses the Windows proxy settings (RECOMMENDED - supports WebSocket)'**
  String get proxySettingsUseSystemProxySubtitle;

  /// No description provided for @proxySettingsManualConfig.
  ///
  /// In en, this message translates to:
  /// **'Manual configuration'**
  String get proxySettingsManualConfig;

  /// No description provided for @proxySettingsManualConfigDeprecated.
  ///
  /// In en, this message translates to:
  /// **'Deprecated: should no longer be used.'**
  String get proxySettingsManualConfigDeprecated;

  /// No description provided for @proxySettingsProxyServer.
  ///
  /// In en, this message translates to:
  /// **'Proxy server'**
  String get proxySettingsProxyServer;

  /// No description provided for @proxySettingsHostLabel.
  ///
  /// In en, this message translates to:
  /// **'Host/IP address'**
  String get proxySettingsHostLabel;

  /// No description provided for @proxySettingsHostHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. proxy.example.com or 192.168.1.1'**
  String get proxySettingsHostHint;

  /// No description provided for @proxySettingsHostRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a host address'**
  String get proxySettingsHostRequired;

  /// No description provided for @proxySettingsPortLabel.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get proxySettingsPortLabel;

  /// No description provided for @proxySettingsPortHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 8080, 3128'**
  String get proxySettingsPortHint;

  /// No description provided for @proxySettingsPortRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a port'**
  String get proxySettingsPortRequired;

  /// No description provided for @proxySettingsPortInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid port (1-65535)'**
  String get proxySettingsPortInvalid;

  /// No description provided for @proxySettingsAuthTitle.
  ///
  /// In en, this message translates to:
  /// **'Authentication (optional)'**
  String get proxySettingsAuthTitle;

  /// No description provided for @proxySettingsAuthHint.
  ///
  /// In en, this message translates to:
  /// **'Only required if the proxy server asks for a username and password.'**
  String get proxySettingsAuthHint;

  /// No description provided for @proxySettingsUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get proxySettingsUsername;

  /// No description provided for @proxySettingsPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get proxySettingsPassword;

  /// No description provided for @proxySettingsTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing connection...'**
  String get proxySettingsTesting;

  /// No description provided for @proxySettingsTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get proxySettingsTestConnection;

  /// No description provided for @proxySettingsNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get proxySettingsNotes;

  /// No description provided for @proxySettingsNotesBody.
  ///
  /// In en, this message translates to:
  /// **'• For state data networks: enable \"Use system proxy\"\n• The Windows proxy settings are detected automatically\n• Environment variables (HTTP_PROXY, HTTPS_PROXY) are supported'**
  String get proxySettingsNotesBody;

  /// No description provided for @proxySettingsNotesRestart.
  ///
  /// In en, this message translates to:
  /// **'• A restart of the application is required after saving'**
  String get proxySettingsNotesRestart;

  /// No description provided for @proxySettingsSave.
  ///
  /// In en, this message translates to:
  /// **'Save settings'**
  String get proxySettingsSave;

  /// No description provided for @themeSettingsLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeSettingsLight;

  /// No description provided for @themeSettingsDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeSettingsDark;

  /// No description provided for @themeSettingsSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSettingsSystem;

  /// No description provided for @themeSettingsLightSubtitle.
  ///
  /// In en, this message translates to:
  /// **'High contrast for bright days'**
  String get themeSettingsLightSubtitle;

  /// No description provided for @themeSettingsDarkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Energy-saving mode for shady surroundings'**
  String get themeSettingsDarkSubtitle;

  /// No description provided for @themeSettingsSystemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follow system setting'**
  String get themeSettingsSystemSubtitle;

  /// No description provided for @validationErrorsDialogAllErrorsNeedNote.
  ///
  /// In en, this message translates to:
  /// **'All errors must be acknowledged with a note ({count} remaining)'**
  String validationErrorsDialogAllErrorsNeedNote(int count);

  /// No description provided for @validationErrorsDialogGroupCorner.
  ///
  /// In en, this message translates to:
  /// **'Plot corner'**
  String get validationErrorsDialogGroupCorner;

  /// No description provided for @validationErrorsDialogGroupPosition.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get validationErrorsDialogGroupPosition;

  /// No description provided for @validationErrorsDialogGroupEdges.
  ///
  /// In en, this message translates to:
  /// **'Edges'**
  String get validationErrorsDialogGroupEdges;

  /// No description provided for @validationErrorsDialogGroupStructureLt4m.
  ///
  /// In en, this message translates to:
  /// **'Structure < 4m'**
  String get validationErrorsDialogGroupStructureLt4m;

  /// No description provided for @validationErrorsDialogGroupStructureGt4m.
  ///
  /// In en, this message translates to:
  /// **'Structure > 4m'**
  String get validationErrorsDialogGroupStructureGt4m;

  /// No description provided for @validationErrorsDialogGroupStocking.
  ///
  /// In en, this message translates to:
  /// **'Stocking'**
  String get validationErrorsDialogGroupStocking;

  /// No description provided for @validationErrorsDialogGroupRegeneration.
  ///
  /// In en, this message translates to:
  /// **'Regeneration'**
  String get validationErrorsDialogGroupRegeneration;

  /// No description provided for @validationErrorsDialogGroupDeadwood.
  ///
  /// In en, this message translates to:
  /// **'Deadwood'**
  String get validationErrorsDialogGroupDeadwood;

  /// No description provided for @validationErrorsDialogPlausibilityUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The plausibility check could not be run (temporary technical problem). The plot corner can still be completed and submitted.'**
  String get validationErrorsDialogPlausibilityUnavailable;

  /// No description provided for @validationErrorsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Check results'**
  String get validationErrorsDialogTitle;

  /// No description provided for @validationErrorsDialogNoIssues.
  ///
  /// In en, this message translates to:
  /// **'No errors or warnings found.'**
  String get validationErrorsDialogNoIssues;

  /// No description provided for @validationErrorsDialogErrorCount.
  ///
  /// In en, this message translates to:
  /// **'{count} errors'**
  String validationErrorsDialogErrorCount(int count);

  /// No description provided for @validationErrorsDialogWarningCount.
  ///
  /// In en, this message translates to:
  /// **'{count} warnings'**
  String validationErrorsDialogWarningCount(int count);

  /// No description provided for @validationErrorsDialogNote.
  ///
  /// In en, this message translates to:
  /// **'Note: {note}'**
  String validationErrorsDialogNote(String note);

  /// No description provided for @validationErrorsDialogObject.
  ///
  /// In en, this message translates to:
  /// **'Object: {object}'**
  String validationErrorsDialogObject(String object);

  /// No description provided for @validationErrorsDialogPath.
  ///
  /// In en, this message translates to:
  /// **'Path: {path}'**
  String validationErrorsDialogPath(String path);

  /// No description provided for @validationErrorsDialogAddNoteRequired.
  ///
  /// In en, this message translates to:
  /// **'Add note (required for errors)*'**
  String get validationErrorsDialogAddNoteRequired;

  /// No description provided for @validationErrorsDialogAddNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Add note (optional)'**
  String get validationErrorsDialogAddNoteOptional;

  /// No description provided for @validationErrorsDialogNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get validationErrorsDialogNoteLabel;

  /// No description provided for @validationErrorsDialogNoteRequired.
  ///
  /// In en, this message translates to:
  /// **'Note required'**
  String get validationErrorsDialogNoteRequired;

  /// No description provided for @validationErrorsDialogSubmit.
  ///
  /// In en, this message translates to:
  /// **'SUBMIT TO STATE INVENTORY MANAGEMENT'**
  String get validationErrorsDialogSubmit;

  /// No description provided for @validationErrorsDialogFixOrComment.
  ///
  /// In en, this message translates to:
  /// **'Fix or comment on {count} errors'**
  String validationErrorsDialogFixOrComment(int count);

  /// No description provided for @serialPortGpsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get serialPortGpsCancel;

  /// No description provided for @bluetoothIconClassicScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Search for Bluetooth Classic devices failed: {error}'**
  String bluetoothIconClassicScanFailed(String error);

  /// No description provided for @bluetoothIconPairingFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Pairing failed'**
  String get bluetoothIconPairingFailedTitle;

  /// No description provided for @bluetoothIconPairingFailedHint.
  ///
  /// In en, this message translates to:
  /// **'Device \"{label}\" could not be paired.\n\nPlease check that the device is switched on and discoverable, and confirm the pairing request on both devices.'**
  String bluetoothIconPairingFailedHint(String label);

  /// No description provided for @bluetoothIconPairingFailedError.
  ///
  /// In en, this message translates to:
  /// **'Device \"{label}\" could not be paired.\n\n{error}'**
  String bluetoothIconPairingFailedError(String label, String error);

  /// No description provided for @bluetoothIconAvailableDevices.
  ///
  /// In en, this message translates to:
  /// **'Available GNSS devices'**
  String get bluetoothIconAvailableDevices;

  /// No description provided for @bluetoothIconNotPairedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Not paired yet – pairing starts when tapped'**
  String get bluetoothIconNotPairedTooltip;

  /// No description provided for @bluetoothIconPaired.
  ///
  /// In en, this message translates to:
  /// **'paired'**
  String get bluetoothIconPaired;

  /// No description provided for @positionSelectorNavigateByCar.
  ///
  /// In en, this message translates to:
  /// **'Navigate by car'**
  String get positionSelectorNavigateByCar;

  /// No description provided for @positionSelectorNavigateOnFoot.
  ///
  /// In en, this message translates to:
  /// **'Navigate on foot'**
  String get positionSelectorNavigateOnFoot;

  /// No description provided for @positionSelectorShowOnMap.
  ///
  /// In en, this message translates to:
  /// **'Show on map'**
  String get positionSelectorShowOnMap;

  /// No description provided for @positionSelectorMapPosition.
  ///
  /// In en, this message translates to:
  /// **'Map position'**
  String get positionSelectorMapPosition;

  /// No description provided for @positionSelectorCurrentGpsPosition.
  ///
  /// In en, this message translates to:
  /// **'Current GPS position'**
  String get positionSelectorCurrentGpsPosition;

  /// No description provided for @positionSelectorSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get positionSelectorSaved;

  /// No description provided for @positionSelectorGpsPosition.
  ///
  /// In en, this message translates to:
  /// **'GPS position'**
  String get positionSelectorGpsPosition;

  /// No description provided for @positionSelectorNoGpsData.
  ///
  /// In en, this message translates to:
  /// **'No GPS data available'**
  String get positionSelectorNoGpsData;

  /// No description provided for @positionSelectorSetPosition.
  ///
  /// In en, this message translates to:
  /// **'Set position'**
  String get positionSelectorSetPosition;

  /// No description provided for @positionSelectorSavedLower.
  ///
  /// In en, this message translates to:
  /// **'saved'**
  String get positionSelectorSavedLower;

  /// No description provided for @positionSelectorEnableLiveTracking.
  ///
  /// In en, this message translates to:
  /// **'Enable live tracking'**
  String get positionSelectorEnableLiveTracking;

  /// No description provided for @positionSelectorPickOnMap.
  ///
  /// In en, this message translates to:
  /// **'Select position on map'**
  String get positionSelectorPickOnMap;

  /// No description provided for @positionSelectorTapOnMap.
  ///
  /// In en, this message translates to:
  /// **'Tap on the map'**
  String get positionSelectorTapOnMap;

  /// No description provided for @positionSelectorDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get positionSelectorDelete;

  /// No description provided for @positionSelectorCornerMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Corner measurements'**
  String get positionSelectorCornerMeasurements;

  /// No description provided for @positionSelectorCenter.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get positionSelectorCenter;

  /// No description provided for @positionSelectorSupportPoints.
  ///
  /// In en, this message translates to:
  /// **'Support points'**
  String get positionSelectorSupportPoints;

  /// No description provided for @positionSelectorSetAsCenter.
  ///
  /// In en, this message translates to:
  /// **'Set as center'**
  String get positionSelectorSetAsCenter;

  /// No description provided for @manuellRelativePositionInvalidValues.
  ///
  /// In en, this message translates to:
  /// **'Please enter valid values for azimuth and distance'**
  String get manuellRelativePositionInvalidValues;

  /// No description provided for @manuellRelativePositionAzimuthRange.
  ///
  /// In en, this message translates to:
  /// **'Azimuth must be between 0 and 400 gon'**
  String get manuellRelativePositionAzimuthRange;

  /// No description provided for @manuellRelativePositionNothingToFocus.
  ///
  /// In en, this message translates to:
  /// **'No {label} available to focus on'**
  String manuellRelativePositionNothingToFocus(String label);

  /// No description provided for @manuellRelativePositionSelectedPosition.
  ///
  /// In en, this message translates to:
  /// **'Selected position'**
  String get manuellRelativePositionSelectedPosition;

  /// No description provided for @manuellRelativePositionGpsPosition.
  ///
  /// In en, this message translates to:
  /// **'GPS position'**
  String get manuellRelativePositionGpsPosition;

  /// No description provided for @manuellRelativePositionStartPosition.
  ///
  /// In en, this message translates to:
  /// **'Start position: {label}'**
  String manuellRelativePositionStartPosition(String label);

  /// No description provided for @manuellRelativePositionNoData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get manuellRelativePositionNoData;

  /// No description provided for @manuellRelativePositionPosition.
  ///
  /// In en, this message translates to:
  /// **'position'**
  String get manuellRelativePositionPosition;

  /// No description provided for @manuellRelativePositionDestination.
  ///
  /// In en, this message translates to:
  /// **'Target position'**
  String get manuellRelativePositionDestination;

  /// No description provided for @manuellRelativePositionSetDestination.
  ///
  /// In en, this message translates to:
  /// **'Set target'**
  String get manuellRelativePositionSetDestination;

  /// No description provided for @manuellRelativePositionAzimuth.
  ///
  /// In en, this message translates to:
  /// **'Azimuth'**
  String get manuellRelativePositionAzimuth;

  /// No description provided for @manuellRelativePositionDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get manuellRelativePositionDistance;

  /// No description provided for @manuellRelativePositionAzimuthGon.
  ///
  /// In en, this message translates to:
  /// **'Azimuth (gon)'**
  String get manuellRelativePositionAzimuthGon;

  /// No description provided for @manuellRelativePositionDistanceMeters.
  ///
  /// In en, this message translates to:
  /// **'Distance (m)'**
  String get manuellRelativePositionDistanceMeters;

  /// No description provided for @manuellRelativePositionMetersHint.
  ///
  /// In en, this message translates to:
  /// **'Meters'**
  String get manuellRelativePositionMetersHint;

  /// No description provided for @manuellRelativePositionAfterStep.
  ///
  /// In en, this message translates to:
  /// **'position after step {step}'**
  String manuellRelativePositionAfterStep(int step);

  /// No description provided for @recordPositionQualityGood.
  ///
  /// In en, this message translates to:
  /// **'good'**
  String get recordPositionQualityGood;

  /// No description provided for @recordPositionQualityOk.
  ///
  /// In en, this message translates to:
  /// **'suitable'**
  String get recordPositionQualityOk;

  /// No description provided for @recordPositionQualityNotAcceptable.
  ///
  /// In en, this message translates to:
  /// **'not suitable'**
  String get recordPositionQualityNotAcceptable;

  /// No description provided for @recordPositionLastGpsInfo.
  ///
  /// In en, this message translates to:
  /// **'Last measured GPS information'**
  String get recordPositionLastGpsInfo;

  /// No description provided for @recordPositionConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get recordPositionConnection;

  /// No description provided for @recordPositionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get recordPositionUnknown;

  /// No description provided for @recordPositionSerial.
  ///
  /// In en, this message translates to:
  /// **'Serial: {port}'**
  String recordPositionSerial(String port);

  /// No description provided for @recordPositionInternalGps.
  ///
  /// In en, this message translates to:
  /// **'Internal GPS'**
  String get recordPositionInternalGps;

  /// No description provided for @recordPositionNoConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get recordPositionNoConnection;

  /// No description provided for @recordPositionTimestamp.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get recordPositionTimestamp;

  /// No description provided for @recordPositionCorrectionSignal.
  ///
  /// In en, this message translates to:
  /// **'Correction signal'**
  String get recordPositionCorrectionSignal;

  /// No description provided for @recordPositionCorrectionSignalAge.
  ///
  /// In en, this message translates to:
  /// **'Correction signal age'**
  String get recordPositionCorrectionSignalAge;

  /// No description provided for @recordPositionSatellites.
  ///
  /// In en, this message translates to:
  /// **'Satellites'**
  String get recordPositionSatellites;

  /// No description provided for @recordPositionAltitude.
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get recordPositionAltitude;

  /// No description provided for @recordPositionNoGpsData.
  ///
  /// In en, this message translates to:
  /// **'No GPS data available'**
  String get recordPositionNoGpsData;

  /// No description provided for @recordPositionSavedMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Saved measurement'**
  String get recordPositionSavedMeasurement;

  /// No description provided for @recordPositionMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Measurements'**
  String get recordPositionMeasurements;

  /// No description provided for @recordPositionSatellitesAvg.
  ///
  /// In en, this message translates to:
  /// **'Satellites (avg)'**
  String get recordPositionSatellitesAvg;

  /// No description provided for @recordPositionCurrentMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Current measurement'**
  String get recordPositionCurrentMeasurement;

  /// No description provided for @recordPositionRecordingProgress.
  ///
  /// In en, this message translates to:
  /// **'Recording: {current} / {total} positions'**
  String recordPositionRecordingProgress(String current, String total);

  /// No description provided for @recordPositionStopMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Stop measurement'**
  String get recordPositionStopMeasurement;

  /// No description provided for @recordPositionCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed: {count} positions recorded'**
  String recordPositionCompleted(String count);

  /// No description provided for @recordPositionStartNewMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Start new measurement'**
  String get recordPositionStartNewMeasurement;

  /// No description provided for @recordPositionStartMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Start measurement'**
  String get recordPositionStartMeasurement;

  /// No description provided for @recordPositionWaitingForValidGps.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a valid GPS signal...'**
  String get recordPositionWaitingForValidGps;

  /// No description provided for @recordPositionDiscardMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Discard measurement'**
  String get recordPositionDiscardMeasurement;

  /// No description provided for @recordPositionReplaceMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Replace measurement'**
  String get recordPositionReplaceMeasurement;

  /// No description provided for @recordPositionApplyMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Apply measurement'**
  String get recordPositionApplyMeasurement;

  /// No description provided for @recordPositionNotSuitable.
  ///
  /// In en, this message translates to:
  /// **'Not suitable'**
  String get recordPositionNotSuitable;

  /// No description provided for @recordPositionDgpsAvailable.
  ///
  /// In en, this message translates to:
  /// **'DGPS available'**
  String get recordPositionDgpsAvailable;

  /// No description provided for @recordPositionRtkFixedAvailable.
  ///
  /// In en, this message translates to:
  /// **'RTK Fixed available'**
  String get recordPositionRtkFixedAvailable;

  /// No description provided for @recordPositionRtkFloatAvailable.
  ///
  /// In en, this message translates to:
  /// **'RTK Float available'**
  String get recordPositionRtkFloatAvailable;

  /// No description provided for @displacedMarkerMinDistance.
  ///
  /// In en, this message translates to:
  /// **'at least 1 cm'**
  String get displacedMarkerMinDistance;

  /// No description provided for @displacedMarkerAdd.
  ///
  /// In en, this message translates to:
  /// **'Add displaced marker'**
  String get displacedMarkerAdd;

  /// No description provided for @displacedMarkerTitle.
  ///
  /// In en, this message translates to:
  /// **'Displaced marker'**
  String get displacedMarkerTitle;

  /// No description provided for @displacedMarkerRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove displaced marker'**
  String get displacedMarkerRemove;

  /// No description provided for @displacedMarkerHorizontalDistance.
  ///
  /// In en, this message translates to:
  /// **'Horizontal distance'**
  String get displacedMarkerHorizontalDistance;

  /// No description provided for @displacedMarkerAzimuth.
  ///
  /// In en, this message translates to:
  /// **'Azimuth'**
  String get displacedMarkerAzimuth;

  /// No description provided for @displacedMarkerDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get displacedMarkerDescription;

  /// No description provided for @displacedMarkerIsMarked.
  ///
  /// In en, this message translates to:
  /// **'Is marked'**
  String get displacedMarkerIsMarked;

  /// No description provided for @previousPositionsNavigationGpsLocked.
  ///
  /// In en, this message translates to:
  /// **'GPS position (locked)'**
  String get previousPositionsNavigationGpsLocked;

  /// No description provided for @previousPositionsNavigationNoPreviousData.
  ///
  /// In en, this message translates to:
  /// **'No previous position data available'**
  String get previousPositionsNavigationNoPreviousData;

  /// No description provided for @previousPositionsNavigationNoCoordinates.
  ///
  /// In en, this message translates to:
  /// **'No coordinates found in previous position data'**
  String get previousPositionsNavigationNoCoordinates;

  /// No description provided for @previousPositionsNavigationTitle.
  ///
  /// In en, this message translates to:
  /// **'Navigation:'**
  String get previousPositionsNavigationTitle;

  /// No description provided for @previousPositionsNavigationTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get previousPositionsNavigationTarget;

  /// No description provided for @previousPositionsNavigationDistanceAzimuth.
  ///
  /// In en, this message translates to:
  /// **'Distance: {distance}, azimuth: {azimuth} gon{coordinates}'**
  String previousPositionsNavigationDistanceAzimuth(
    String distance,
    String azimuth,
    String coordinates,
  );

  /// No description provided for @previousPositionsNavigationNoNavigationData.
  ///
  /// In en, this message translates to:
  /// **'No navigation data available. Connect an external GPS or use the device\'s internal GPS.'**
  String get previousPositionsNavigationNoNavigationData;

  /// No description provided for @previousPositionsSelectionNoData.
  ///
  /// In en, this message translates to:
  /// **'No previous position data available'**
  String get previousPositionsSelectionNoData;

  /// No description provided for @previousPositionsSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Previous position measurements'**
  String get previousPositionsSelectionTitle;

  /// No description provided for @manualNavigationStepsAzimuthRange.
  ///
  /// In en, this message translates to:
  /// **'Azimuth must be between 0 and 400 gon'**
  String get manualNavigationStepsAzimuthRange;

  /// No description provided for @manualNavigationStepsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Manual navigation'**
  String get manualNavigationStepsTooltip;

  /// No description provided for @manualNavigationStepsSelectStartAndTarget.
  ///
  /// In en, this message translates to:
  /// **'Select start and target'**
  String get manualNavigationStepsSelectStartAndTarget;

  /// No description provided for @manualNavigationStepsDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get manualNavigationStepsDistance;

  /// No description provided for @manualNavigationStepsAzimuth.
  ///
  /// In en, this message translates to:
  /// **'Azimuth'**
  String get manualNavigationStepsAzimuth;

  /// No description provided for @landmarkPointsMinDistance.
  ///
  /// In en, this message translates to:
  /// **'at least 1 cm'**
  String get landmarkPointsMinDistance;

  /// No description provided for @landmarkPointsTitle.
  ///
  /// In en, this message translates to:
  /// **'Landmark point {number}'**
  String landmarkPointsTitle(int number);

  /// No description provided for @landmarkPointsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove landmark point'**
  String get landmarkPointsRemove;

  /// No description provided for @landmarkPointsHorizontalDistance.
  ///
  /// In en, this message translates to:
  /// **'Horizontal distance'**
  String get landmarkPointsHorizontalDistance;

  /// No description provided for @landmarkPointsAzimuth.
  ///
  /// In en, this message translates to:
  /// **'Azimuth'**
  String get landmarkPointsAzimuth;

  /// No description provided for @landmarkPointsDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get landmarkPointsDescription;

  /// No description provided for @landmarkPointsHint.
  ///
  /// In en, this message translates to:
  /// **'Azimuth and distance from the plot corner to the landmark point'**
  String get landmarkPointsHint;

  /// No description provided for @landmarkPointsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add landmark point'**
  String get landmarkPointsAdd;

  /// No description provided for @helpingPointUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get helpingPointUnknown;

  /// No description provided for @helpingPointRecordingProgress.
  ///
  /// In en, this message translates to:
  /// **'Measuring... {current}/{total}'**
  String helpingPointRecordingProgress(int current, int total);

  /// No description provided for @helpingPointCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get helpingPointCancel;

  /// No description provided for @helpingPointMeasurementCountShort.
  ///
  /// In en, this message translates to:
  /// **'{count} meas.'**
  String helpingPointMeasurementCountShort(String count);

  /// No description provided for @helpingPointNewMeasurement.
  ///
  /// In en, this message translates to:
  /// **'new measurement'**
  String get helpingPointNewMeasurement;

  /// No description provided for @helpingPointMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Measurements'**
  String get helpingPointMeasurements;

  /// No description provided for @helpingPointAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get helpingPointAccuracy;

  /// No description provided for @helpingPointSatellites.
  ///
  /// In en, this message translates to:
  /// **'Satellites'**
  String get helpingPointSatellites;

  /// No description provided for @helpingPointCorrectionSignal.
  ///
  /// In en, this message translates to:
  /// **'Correction signal'**
  String get helpingPointCorrectionSignal;

  /// No description provided for @helpingPointTimestamp.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get helpingPointTimestamp;

  /// No description provided for @helpingPointStartMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Start measurement'**
  String get helpingPointStartMeasurement;

  /// No description provided for @plotSupportPointsAzimuth.
  ///
  /// In en, this message translates to:
  /// **'Azimuth: {azimuth} gon'**
  String plotSupportPointsAzimuth(String azimuth);

  /// No description provided for @plotSupportPointsDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance: {distance} cm'**
  String plotSupportPointsDistance(String distance);

  /// No description provided for @formWrapperMessagesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Messages not available: no record loaded'**
  String get formWrapperMessagesUnavailable;

  /// No description provided for @arrayElementArchiveRowDeleteBlocked.
  ///
  /// In en, this message translates to:
  /// **'Existing entry from the inventory – cannot be deleted.'**
  String get arrayElementArchiveRowDeleteBlocked;

  /// No description provided for @arrayElementTrinaFilterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get arrayElementTrinaFilterTooltip;

  /// No description provided for @arrayElementCardlistDeleteProtectedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Existing entry from the inventory – cannot be deleted'**
  String get arrayElementCardlistDeleteProtectedTooltip;

  /// No description provided for @arrayElementCardlistDeleteEntry.
  ///
  /// In en, this message translates to:
  /// **'Delete entry'**
  String get arrayElementCardlistDeleteEntry;

  /// No description provided for @arrayElementCardlistMaxEntries.
  ///
  /// In en, this message translates to:
  /// **'Maximum {maxRows} entries'**
  String arrayElementCardlistMaxEntries(int maxRows);

  /// No description provided for @arrayElementCardlistAddEntry.
  ///
  /// In en, this message translates to:
  /// **'Add {label}'**
  String arrayElementCardlistAddEntry(String label);

  /// No description provided for @arrayElementCardlistEntryDefault.
  ///
  /// In en, this message translates to:
  /// **'entry'**
  String get arrayElementCardlistEntryDefault;

  /// No description provided for @arrayFilterDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get arrayFilterDialogTitle;

  /// No description provided for @arrayFilterDialogNoFilters.
  ///
  /// In en, this message translates to:
  /// **'No filters available'**
  String get arrayFilterDialogNoFilters;

  /// No description provided for @cardDialogNoFields.
  ///
  /// In en, this message translates to:
  /// **'No fields available'**
  String get cardDialogNoFields;

  /// No description provided for @cardDialogDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get cardDialogDone;

  /// No description provided for @genericTextfieldInfoTooltip.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get genericTextfieldInfoTooltip;

  /// No description provided for @permissionsSelectionSyncing.
  ///
  /// In en, this message translates to:
  /// **'Synchronising permissions…{percent}'**
  String permissionsSelectionSyncing(String percent);

  /// No description provided for @permissionsSelectionNone.
  ///
  /// In en, this message translates to:
  /// **'No permissions found'**
  String get permissionsSelectionNone;

  /// No description provided for @permissionsSelectionTroopRequired.
  ///
  /// In en, this message translates to:
  /// **'Troop membership required'**
  String get permissionsSelectionTroopRequired;

  /// No description provided for @databaseBackupSaveDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Save database backup'**
  String get databaseBackupSaveDialogTitle;

  /// No description provided for @databaseBackupSavedSealed.
  ///
  /// In en, this message translates to:
  /// **'Backup saved (encrypted)'**
  String get databaseBackupSavedSealed;

  /// No description provided for @databaseBackupSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get databaseBackupSaved;

  /// No description provided for @databaseBackupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup failed: {error}'**
  String databaseBackupFailed(String error);

  /// No description provided for @databaseBackupInProgress.
  ///
  /// In en, this message translates to:
  /// **'Creating backup …'**
  String get databaseBackupInProgress;

  /// No description provided for @databaseBackupAllSealed.
  ///
  /// In en, this message translates to:
  /// **'Backup of all databases (encrypted)'**
  String get databaseBackupAllSealed;

  /// No description provided for @databaseBackupAllZip.
  ///
  /// In en, this message translates to:
  /// **'Backup of all databases (ZIP)'**
  String get databaseBackupAllZip;
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
