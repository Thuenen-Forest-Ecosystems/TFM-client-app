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
  String get gridRowUnlock => 'Unlock row';

  @override
  String get gridRowLock => 'Lock row';

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

  @override
  String get recordingReadOnlyPlayground =>
      'Playground mode: data cannot be saved.';

  @override
  String get recordingReadOnlyAdmin => 'Admin view: data cannot be saved.';

  @override
  String get recordingReadOnlyGroup =>
      'Read-only access: data cannot be saved.';

  @override
  String get mapSettingsTreeDisplay => 'Tree display';

  @override
  String mapSettingsDiameterMultiplier(String value) {
    return 'Diameter multiplier: ${value}x';
  }

  @override
  String get mapSettingsShowLabels => 'Show labels';

  @override
  String get mapSettingsTreeNumber => 'Tree number';

  @override
  String get mapSettingsDbh => 'DBH';

  @override
  String get mapSettingsSpeciesCode => 'Tree species (code)';

  @override
  String get mapSettingsSpeciesName => 'Tree species (name)';

  @override
  String get mapSettingsAzimuth => 'Azimuth';

  @override
  String get mapSettingsDistance => 'Distance';

  @override
  String get mapSettingsLayers => 'Layers';

  @override
  String get mapSettingsEdges => 'Stand edges';

  @override
  String get mapSettingsBoundaryCircles => 'Boundary circles';

  @override
  String get mapSettingsBoundaryCirclesSubtitle => 'based on DBH';

  @override
  String get mapSettingsCluster => 'Tract';

  @override
  String get mapSettingsClusterSubtitle => 'Tract outlines';

  @override
  String get mapSettingsSampleCircles => 'Sample circles';

  @override
  String get mapSettingsSampleCirclesSubtitle =>
      '5 m · 10 m · 25 m reference circles';

  @override
  String get mapSettingsRegenerationCircle => 'Regeneration circle';

  @override
  String get mapSettingsRegenerationCircleSubtitle =>
      'Sampling circle for regeneration';

  @override
  String get mapSettingsRescuePoints => 'Emergency rescue points';

  @override
  String get mapSettingsRescuePointsSubtitle =>
      'Only visible at high zoom levels';

  @override
  String get mapSettingsBasemaps => 'Base maps';

  @override
  String get mapSettingsDtk25Subtitle => 'Topographic map of the BKG';

  @override
  String get mapSettingsOpenCycleMapSubtitle =>
      'Online; offline only for areas already viewed';

  @override
  String get mapSettingsAerialImagery => 'Aerial imagery (offline)';

  @override
  String get mapSettingsAerialImagerySubtitle => 'highest zoom levels only';

  @override
  String get mapAdminDeleteCache => 'Delete cache';

  @override
  String mapAdminDeleteConfirm(String storeName) {
    return 'Do you want to delete all tiles for \"$storeName\"?';
  }

  @override
  String get mapAdminCancel => 'Cancel';

  @override
  String get mapAdminDelete => 'Delete';

  @override
  String mapAdminCacheDeleted(String storeName) {
    return 'Cache for \"$storeName\" deleted';
  }

  @override
  String mapAdminDeleteError(String error) {
    return 'Error while deleting: $error';
  }

  @override
  String get mapAdminStoreAerial => 'Aerial imagery (DOP)';

  @override
  String mapAdminTileCount(int count, String size) {
    return '$count tiles (~$size)';
  }

  @override
  String get mapAdminNoCache => 'No cache available';

  @override
  String get mapTilesDownloadNoRecords =>
      'No survey points found. Please load data first.';

  @override
  String mapTilesDownloadTileProgress(String done, String total) {
    return '$done / $total tiles';
  }

  @override
  String get mapTilesDownloadCancel => 'Cancel';

  @override
  String get mapTilesDownloadChecking => 'Checking data...';

  @override
  String get mapTilesDownloadLoadError => 'Error while loading';

  @override
  String get mapTilesDownloadRetry => 'Try again';

  @override
  String get mapTilesDownloadNoPoints =>
      'No survey points available.\nPlease synchronize data first.';

  @override
  String get mapTilesDownloadRecheck => 'Check again';

  @override
  String get mapTilesDownloadComplete => 'Complete';

  @override
  String get mapTilesDownloadResume => 'Resume';

  @override
  String get mainExitConfirmTitle => 'Confirmation required';

  @override
  String get mainExitConfirmContent =>
      'Do you really want to quit the application?';

  @override
  String get mainExitConfirmNo => 'No';

  @override
  String get mainExitConfirmYes => 'Yes';

  @override
  String get startConfirmGoBack => 'Confirm going back';

  @override
  String get startLeaveRecording => 'Leave survey';

  @override
  String get startChangesSaved => 'Any changes have been saved automatically.';

  @override
  String get startCancel => 'cancel';

  @override
  String get startToOverview => 'To overview';

  @override
  String get loginSessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get loginFailed => 'Login failed';

  @override
  String get loginInvalidCredentials =>
      'Invalid login credentials. Please check your email and password.';

  @override
  String get loginEmailNotConfirmed =>
      'Email address has not been confirmed yet. Please check your inbox.';

  @override
  String loginAuthError(String message) {
    return 'Sign-in error: $message';
  }

  @override
  String get loginProxyError =>
      'Proxy connection error: The configured proxy server cannot be reached.\n\nPlease check:\n• Your proxy settings via \"Network settings (proxy)\" below\n• Whether the proxy server is reachable\n• Your Windows system proxy settings\n\nTip: If you do not need a proxy, disable the proxy function in the network settings.';

  @override
  String get loginTimeoutError =>
      'Connection timeout: The server could not be reached in time.\n\nPlease try:\n• A different internet connection (e.g. Wi-Fi instead of mobile data)\n• Again later\n• Contacting your network administrator if you are on a corporate or institutional network';

  @override
  String get loginCertificateError =>
      'Connection error: Please check your internet connection and make sure that the date and time are set correctly.\n\nIf the problem persists, contact bwi-support@thuenen.de.';

  @override
  String loginUnexpectedError(String error) {
    return 'An unexpected error occurred: $error';
  }

  @override
  String get loginOfflineFailed => 'Offline sign-in failed';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginEmailRequired => 'Please enter your email address';

  @override
  String get loginEmailInvalid => 'Please enter a valid email address';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginPasswordRequired => 'Please enter your password';

  @override
  String get loginPasswordTooShort =>
      'The password must be at least 6 characters long';

  @override
  String get loginSubmit => 'Sign in';

  @override
  String get loginOfflineMode => 'Offline mode: No internet connection';

  @override
  String get loginNoInternet => 'No internet connection';

  @override
  String get loginNoInternetFirstLogin =>
      'Please connect to the internet to sign in for the first time.';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginNetworkSettings => 'Network settings (proxy)';

  @override
  String get schemaLogout => 'Sign out';

  @override
  String get orderClusterByDistance => 'Distance (GPS required)';

  @override
  String get orderClusterByUpdatedAt => 'Modified on';

  @override
  String get orderClusterByClusterName => 'Tract number';

  @override
  String get clusterInfoNoRecord => 'No record available';

  @override
  String get clusterInfoNoClusterInfo => 'No tract information available';

  @override
  String get clusterInfoShowTooltip => 'Show tract information';

  @override
  String get clusterInfoTitle => 'Information';

  @override
  String clusterInfoClusterPlot(String clusterName, String plotName) {
    return 'Tract: $clusterName / Corner: $plotName';
  }

  @override
  String get clusterInfoClose => 'Close';

  @override
  String get clusterInfoUpdatedAt => 'Updated on';

  @override
  String get clusterInfoUpdatedBy => 'Updated by';

  @override
  String get clusterInfoTroop => 'Crew';

  @override
  String get clusterInfoYes => 'Yes';

  @override
  String get clusterInfoNo => 'No';

  @override
  String clusterInfoListEntries(int count) {
    return 'List ($count entries)';
  }

  @override
  String clusterInfoObjectFields(int count) {
    return 'Object ($count fields)';
  }

  @override
  String get recordsSelectionSearchCluster => 'Search tract number...';

  @override
  String get recordsSelectionTitle => 'Plot corners';

  @override
  String get recordsSelectionNoneAssigned =>
      'No plot corner has been assigned to you yet.';

  @override
  String schemaSelectionError(String error) {
    return 'Error: $error';
  }

  @override
  String get schemaSelectionLoading1 => 'Please wait...';

  @override
  String get schemaSelectionLoading2 => 'This may take a moment...';

  @override
  String get schemaSelectionLoading3 => '... not much longer now...';

  @override
  String get schemaSelectionLoading4 => 'Almost there...';

  @override
  String get schemaSelectionLoading5 => 'Just a little more patience...';

  @override
  String get schemaSelectionLoading6 => 'Synchronizing data...';

  @override
  String get schemaSelectionLoading7 => 'Nearly done...';

  @override
  String get schemaSelectionNoSchemas => 'No schemas available';

  @override
  String get schemaSelectionPleaseSync => 'Please synchronize the data';

  @override
  String get loggerTitle => 'Application logs';

  @override
  String get loggerAddTestLog => 'Add test log';

  @override
  String get loggerFilter => 'Filter';

  @override
  String get loggerFilterAll => 'All logs';

  @override
  String get loggerFilterInfo => 'Info & higher';

  @override
  String get loggerFilterWarning => 'Warnings & errors';

  @override
  String get loggerFilterError => 'Errors only';

  @override
  String get loggerAutoScrollOn => 'Auto-scroll on';

  @override
  String get loggerAutoScrollOff => 'Auto-scroll off';

  @override
  String get loggerCopyAll => 'Copy all logs';

  @override
  String get loggerCopiedAll => 'Logs copied to clipboard';

  @override
  String get loggerClear => 'Clear logs';

  @override
  String get loggerClearTitle => 'Clear logs?';

  @override
  String get loggerClearConfirm => 'Do you really want to delete all logs?';

  @override
  String get loggerCancel => 'Cancel';

  @override
  String get loggerDelete => 'Delete';

  @override
  String loggerEntryCount(int count) {
    return '$count entries';
  }

  @override
  String loggerFilterLabel(String level) {
    return 'Filter: $level';
  }

  @override
  String get loggerEmpty => 'No logs available';

  @override
  String get loggerCopiedEntry => 'Log entry copied';

  @override
  String get recordsRawColCluster => 'Tract';

  @override
  String get recordsRawColPlot => 'Corner';

  @override
  String get recordsRawColValidatedBy => 'Validated with schema';

  @override
  String get recordsRawColValid => 'Valid';

  @override
  String get recordsRawColPlotId => 'Corner ID';

  @override
  String get recordsRawColClusterId => 'Tract ID';

  @override
  String get recordsRawColAdministration => 'Administration';

  @override
  String get recordsRawColProvider => 'Provider';

  @override
  String get recordsRawColState => 'Federal state';

  @override
  String get recordsRawColTroop => 'Team';

  @override
  String get recordsRawColUpdatedAt => 'Updated';

  @override
  String get recordsRawColLocalUpdatedAt => 'Updated locally';

  @override
  String get recordsRawColCompletedState => 'Completed (federal state)';

  @override
  String get recordsRawColCompletedTroop => 'Completed (team)';

  @override
  String get recordsRawColCompletedAdministration =>
      'Completed (administration)';

  @override
  String get recordsRawColToBeRecorded => 'To be recorded';

  @override
  String get recordsRawColNote => 'Note';

  @override
  String get recordsRawColProperties => 'Properties (JSON)';

  @override
  String get recordsRawColPreviousProperties => 'Previous properties (JSON)';

  @override
  String get recordsRawColPreviousPosition => 'Previous position (JSON)';

  @override
  String get recordsRawTitle => 'Raw data - records';

  @override
  String get recordsRawRefresh => 'Refresh';

  @override
  String recordsRawTotal(int count) {
    return 'Total: $count records';
  }

  @override
  String recordsRawPageOf(int page, int total) {
    return 'Page $page of $total';
  }

  @override
  String recordsRawLoadError(String error) {
    return 'Error loading records: $error';
  }

  @override
  String get recordsRawRetry => 'Try again';

  @override
  String get recordsRawEmpty => 'No records found';

  @override
  String get recordsRawFirstPage => 'First page';

  @override
  String get recordsRawPreviousPage => 'Previous page';

  @override
  String get recordsRawNextPage => 'Next page';

  @override
  String get recordsRawLastPage => 'Last page';

  @override
  String get syncedTablesReload => 'Reload';

  @override
  String syncedTablesError(String error) {
    return 'Error: $error';
  }

  @override
  String get syncedTablesRetry => 'Retry';

  @override
  String get syncedTablesEmpty => 'No tables found.';

  @override
  String get uploadFailuresRestoreTitle => 'Restore upload?';

  @override
  String uploadFailuresRestoreContent(String title) {
    return 'The saved state of $title will be applied locally (overwriting the current local state of this record) and uploaded again with the next sync.\n\nIf the upload fails again, the entry will reappear in this list.';
  }

  @override
  String get uploadFailuresCancel => 'Cancel';

  @override
  String get uploadFailuresRestore => 'Restore';

  @override
  String get uploadFailuresRestoredSnack =>
      'Restored — will be uploaded again with the next sync.';

  @override
  String uploadFailuresRestoreFailed(String error) {
    return 'Restore failed: $error';
  }

  @override
  String uploadFailuresRestoreAllTitle(int count) {
    return 'Restore all $count entries?';
  }

  @override
  String get uploadFailuresRestoreAllContent =>
      'All saved states will be applied locally (oldest first) and uploaded again with the next sync. The current local state of the affected records will be overwritten.';

  @override
  String get uploadFailuresRestoreAll => 'Restore all';

  @override
  String get uploadFailuresRestoreAllSuccess =>
      'All entries restored — upload will follow with the next sync.';

  @override
  String uploadFailuresRestoreAllErrors(int count, String errors) {
    return '$count entries could not be applied:\n$errors';
  }

  @override
  String get uploadFailuresDiscardTitle => 'Permanently discard entry?';

  @override
  String uploadFailuresDiscardContent(String title) {
    return 'The saved data of $title will be deleted and can no longer be restored afterwards.';
  }

  @override
  String get uploadFailuresDiscard => 'Discard';

  @override
  String uploadFailuresDeleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String uploadFailuresTractTitle(String cluster, String plot) {
    return 'Tract $cluster / $plot';
  }

  @override
  String get uploadFailuresReasonIgnored =>
      'Ignored by the server (no write permission for this record)';

  @override
  String get uploadFailuresReasonRejected => 'Rejected by the server';

  @override
  String get uploadFailuresReasonUnattempted =>
      'Not attempted (a previous upload of the same transfer was rejected)';

  @override
  String get uploadFailuresReasonUnknown => 'Unknown';

  @override
  String get uploadFailuresTitle => 'Backups';

  @override
  String get uploadFailuresActiveDbTab => 'Active DB';

  @override
  String uploadFailuresActiveDbTabCount(int count) {
    return 'Active DB ($count)';
  }

  @override
  String get uploadFailuresActiveDatabase => 'Active database';

  @override
  String uploadFailuresNotAppliedSuffix(int count) {
    return ' · $count not applied';
  }

  @override
  String get uploadFailuresQuarantineExplanation =>
      'The server did not accept these changes. The data is saved locally and can be transferred again.';

  @override
  String get uploadFailuresAllAccepted =>
      'All uploads of this database were accepted by the server.';

  @override
  String uploadFailuresRestoreAllCount(int count) {
    return 'Restore all $count';
  }

  @override
  String get uploadFailuresEmpty => 'No entries — all uploads were accepted.';

  @override
  String get uploadFailuresRecoverTitle => 'Restore record?';

  @override
  String uploadFailuresRecoverContent(String title, String fileName) {
    return 'The state of $title from \"$fileName\" will be copied into the active database (overwriting the state there) and uploaded with the next sync.\n\nIf the server rejects the upload, it will appear in the \"Active DB\" tab. The source file remains unchanged.';
  }

  @override
  String get uploadFailuresRecoveredSnack =>
      'Copied into the active database — upload will follow with the next sync.';

  @override
  String uploadFailuresRecordNotFound(String fileName) {
    return 'Record no longer found in \"$fileName\".';
  }

  @override
  String uploadFailuresRecoverAllTitle(int count) {
    return 'Restore $count records that were never uploaded?';
  }

  @override
  String get uploadFailuresRecoverAllContent =>
      'All records with changes that were never uploaded will be copied into the active database (overwriting the state there) and uploaded with the next sync.';

  @override
  String uploadFailuresRecoverAllSuccess(int count) {
    return '$count records copied — upload will follow with the next sync.';
  }

  @override
  String uploadFailuresRecoverAllPartial(
    int recovered,
    int failed,
    String errors,
  ) {
    return '$recovered copied, $failed failed:\n$errors';
  }

  @override
  String uploadFailuresTractLabel(String title) {
    return 'Tract $title';
  }

  @override
  String uploadFailuresReadError(String fileName, String error) {
    return 'Error reading \"$fileName\": $error';
  }

  @override
  String uploadFailuresFileSummary(String fileName, int count) {
    return '$fileName · $count records';
  }

  @override
  String uploadFailuresNeverUploadedSuffix(int count) {
    return ' · $count never uploaded';
  }

  @override
  String get uploadFailuresPendingExplanation =>
      'Records marked \"Not uploaded\" exist ONLY in this file — the server never received them.';

  @override
  String get uploadFailuresAllUploadedExplanation =>
      'All records in this file have also been uploaded to the server or originate from it.';

  @override
  String get uploadFailuresReload => 'Reload';

  @override
  String get uploadFailuresNoRecords => 'No records in this file.';

  @override
  String get uploadFailuresNotUploaded => 'Not uploaded';

  @override
  String get diagnosticExportDialogTitle => 'Save diagnostic data';

  @override
  String diagnosticExportSaved(String path) {
    return 'Saved: $path';
  }

  @override
  String diagnosticExportError(String error) {
    return 'Error while saving: $error';
  }

  @override
  String get diagnosticExportTooltip => 'Save diagnostic data as JSON';

  @override
  String get playgroundModeButtonExit => 'Exit playground mode';

  @override
  String get playgroundModeButtonLabel => 'Playground';

  @override
  String get playgroundModeButtonActivate =>
      'Activate playground mode (saving not possible)';

  @override
  String get recordsExportDialogTitle => 'Save records';

  @override
  String recordsExportSaved(int count, String path) {
    return '$count records saved:\n$path';
  }

  @override
  String recordsExportError(String error) {
    return 'Error while exporting: $error';
  }

  @override
  String get recordsExportTooltip => 'Export all records as JSON';

  @override
  String get recordCardNotAccessible => 'Not accessible';

  @override
  String get recordCardNever => 'Never';

  @override
  String recordCardTitle(String cluster, String plot) {
    return 'Tract: $cluster | Corner: $plot';
  }

  @override
  String get submissionSuccessDialogDeliveredTitle =>
      'Submitted and confirmed by the server';

  @override
  String get submissionSuccessDialogUploadingTitle => 'Saved — uploading …';

  @override
  String get submissionSuccessDialogPendingOfflineTitle =>
      'Saved on the device';

  @override
  String get submissionSuccessDialogRejectedTitle => 'Transfer not accepted';

  @override
  String get submissionSuccessDialogDeliveredSubtitle =>
      'The recording has arrived on the server.';

  @override
  String submissionSuccessDialogUploadingQueue(int count) {
    return '$count changes still in the queue.';
  }

  @override
  String get submissionSuccessDialogUploadingSubtitle =>
      'The transfer is in progress.';

  @override
  String get submissionSuccessDialogPendingOfflineSubtitle =>
      'Not yet transferred — this happens automatically as soon as a connection is available again. Please go online and check the sync status before finishing the field day.';

  @override
  String get submissionSuccessDialogRejectedSubtitle =>
      'The server did not accept this change. The data is saved locally and can be restored under \"Backups\" in the profile.';

  @override
  String submissionSuccessDialogTractCorner(String cluster, String plot) {
    return 'Tract $cluster · Corner $plot';
  }

  @override
  String submissionSuccessDialogOtherCorners(String cluster) {
    return 'Other corners in tract $cluster:';
  }

  @override
  String submissionSuccessDialogCorner(String plot) {
    return 'Corner $plot';
  }

  @override
  String submissionSuccessDialogCompletedAt(String date) {
    return 'Completed: $date';
  }

  @override
  String submissionSuccessDialogEditedAt(String date) {
    return 'Edited: $date';
  }

  @override
  String get submissionSuccessDialogNotEdited => 'Not edited';

  @override
  String get submissionSuccessDialogNoOtherCorners =>
      'No other corners in this tract.';

  @override
  String get submissionSuccessDialogBackToOverview => 'Back to overview';

  @override
  String get syncStatusButtonLastSync => 'Last sync';

  @override
  String get syncStatusButtonNever => 'Never';

  @override
  String get syncStatusButtonCertificateHint =>
      'Have you already run the \"Install SSL Certificates\" application? If not, please find the application and run it.';

  @override
  String get syncStatusButtonQueue => 'Queue';

  @override
  String syncStatusButtonPending(int count) {
    return '$count pending';
  }

  @override
  String syncStatusButtonUploadFailures(int count) {
    return '⚠ $count upload(s) not accepted by the server';
  }

  @override
  String get syncStatusButtonUploadFailuresHint =>
      'The data is saved locally (upload_failures). Please create a diagnostic export and send it to support.';

  @override
  String syncStatusButtonAndMore(int count) {
    return '… and $count more';
  }

  @override
  String get syncStatusButtonNotSynced => 'Not synced';

  @override
  String syncStatusButtonRecordCount(int count) {
    return '$count records';
  }

  @override
  String get syncStatusButtonServerSql => 'Server diagnostic SQL:';

  @override
  String get syncStatusButtonCopySql => 'Copy SQL';

  @override
  String get syncStatusButtonSqlCopied => 'SQL copied to clipboard';

  @override
  String syncStatusButtonRecordRow(
    String cluster,
    String plot,
    String localTs,
    String serverTs,
  ) {
    return '$cluster / $plot\nLocal: $localTs  •  Server: $serverTs';
  }

  @override
  String get densitySettingsCompactTable => 'Compact table mode';

  @override
  String get densitySettingsReducedRowHeight =>
      'Reduced row height (for stylus/tablet)';

  @override
  String get densitySettingsStandardRowHeight => 'Standard row height';

  @override
  String get keyboardSettingsFloatingNumpad => 'Floating number pad';

  @override
  String get keyboardSettingsNotAvailable => 'Not available on this platform.';

  @override
  String get keyboardSettingsNumpadForNumbers =>
      'Number pad for numeric fields';

  @override
  String get keyboardSettingsSystemKeyboardForNumbers =>
      'System keyboard for numeric fields';

  @override
  String get profileLogoutUnsyncedWarning =>
      'There is data on this device that has not been uploaded yet!';

  @override
  String profileLogoutPendingUploads(int count) {
    return '• $count change(s) waiting to be uploaded';
  }

  @override
  String profileLogoutQuarantined(int count) {
    return '• $count saved entry/entries under \"Backups\"';
  }

  @override
  String get profileLogoutDataLostHint =>
      'This data will then be irretrievably lost. Please synchronize first — or create a backup.';

  @override
  String profileBackupsWithCount(int count) {
    return 'Backups ($count)';
  }

  @override
  String get profileBackups => 'Backups';

  @override
  String get profileBackupsSubtitle =>
      'Restore data that has not been uploaded';

  @override
  String propertiesEditNoSchemaFound(String intervalName) {
    return 'No schema found for: $intervalName';
  }

  @override
  String get propertiesEditControlTroopStyleMissing =>
      'Control troop requires the style_control schema, but it is not available';

  @override
  String propertiesEditSchemaLoadError(String error) {
    return 'Error loading the schema: $error';
  }

  @override
  String get propertiesEditNewRecordNotAllowed =>
      'New records cannot be created here.';

  @override
  String get propertiesEditPlaygroundNoSave =>
      '🧪 Playground mode active – saving not possible.';

  @override
  String get propertiesEditAdminViewNoSave =>
      'Admin view – saving not possible.';

  @override
  String propertiesEditSaveError(String error) {
    return 'Error saving: $error';
  }

  @override
  String get propertiesEditInformation => 'Information';

  @override
  String propertiesEditCluster(String cluster) {
    return 'Tract: $cluster';
  }

  @override
  String propertiesEditPlot(String plot) {
    return 'Corner: $plot';
  }

  @override
  String get propertiesEditDone => 'DONE';

  @override
  String get proxyServiceTimeoutAfter10s =>
      'Connection aborted after 10 seconds';

  @override
  String get proxyServiceWebSocketTimeout => 'WebSocket connection timeout';

  @override
  String get proxyServiceWebSocketWorks => 'WebSocket is working';

  @override
  String proxyServiceHttpSuccess(int statusCode) {
    return 'HTTP connection successful ($statusCode)';
  }

  @override
  String proxyServiceServerStatus(int statusCode) {
    return 'Server responded with status $statusCode';
  }

  @override
  String proxyServiceConnectionRefused(String address, int port) {
    return 'Connection refused. Please check:\n• Is the proxy running on $address:$port?\n• Is the proxy address correct?\n• Firewall settings?';
  }

  @override
  String proxyServiceHostUnreachable(String address) {
    return 'Host unreachable: $address';
  }

  @override
  String proxyServiceNetworkError(String error) {
    return 'Network error: $error';
  }

  @override
  String proxyServiceTimeout(String message) {
    return 'Timeout: $message';
  }

  @override
  String get proxyServiceNoResponse10s => 'No response after 10 seconds';

  @override
  String proxyServiceUnexpectedError(String error) {
    return 'Unexpected error: $error';
  }

  @override
  String proxySettingsLoadError(String error) {
    return 'Error loading settings: $error';
  }

  @override
  String get proxySettingsSaved => 'Proxy settings saved';

  @override
  String proxySettingsSaveError(String error) {
    return 'Error saving: $error';
  }

  @override
  String get proxySettingsProxyDisabled => 'Proxy is disabled';

  @override
  String proxySettingsTestFailed(String error) {
    return 'Test failed: $error';
  }

  @override
  String get proxySettingsRestartTitle => 'Restart required';

  @override
  String get proxySettingsRestartContent =>
      'The proxy settings will take effect the next time the application starts.\n\nDo you want to close the application now?';

  @override
  String get proxySettingsRestartLater => 'Later';

  @override
  String get proxySettingsCloseApp => 'Close application';

  @override
  String get proxySettingsEnable => 'Enable proxy';

  @override
  String get proxySettingsEnableSubtitle => 'Connect via proxy server';

  @override
  String get proxySettingsUseSystemProxy => 'Use system proxy';

  @override
  String get proxySettingsUseSystemProxySubtitle =>
      'Uses the Windows proxy settings (RECOMMENDED - supports WebSocket)';

  @override
  String get proxySettingsManualConfig => 'Manual configuration';

  @override
  String get proxySettingsManualConfigDeprecated =>
      'Deprecated: should no longer be used.';

  @override
  String get proxySettingsProxyServer => 'Proxy server';

  @override
  String get proxySettingsHostLabel => 'Host/IP address';

  @override
  String get proxySettingsHostHint => 'e.g. proxy.example.com or 192.168.1.1';

  @override
  String get proxySettingsHostRequired => 'Please enter a host address';

  @override
  String get proxySettingsPortLabel => 'Port';

  @override
  String get proxySettingsPortHint => 'e.g. 8080, 3128';

  @override
  String get proxySettingsPortRequired => 'Please enter a port';

  @override
  String get proxySettingsPortInvalid => 'Invalid port (1-65535)';

  @override
  String get proxySettingsAuthTitle => 'Authentication (optional)';

  @override
  String get proxySettingsAuthHint =>
      'Only required if the proxy server asks for a username and password.';

  @override
  String get proxySettingsUsername => 'Username';

  @override
  String get proxySettingsPassword => 'Password';

  @override
  String get proxySettingsTesting => 'Testing connection...';

  @override
  String get proxySettingsTestConnection => 'Test connection';

  @override
  String get proxySettingsNotes => 'Notes';

  @override
  String get proxySettingsNotesBody =>
      '• For state data networks: enable \"Use system proxy\"\n• The Windows proxy settings are detected automatically\n• Environment variables (HTTP_PROXY, HTTPS_PROXY) are supported';

  @override
  String get proxySettingsNotesRestart =>
      '• A restart of the application is required after saving';

  @override
  String get proxySettingsSave => 'Save settings';

  @override
  String get themeSettingsLight => 'Light';

  @override
  String get themeSettingsDark => 'Dark';

  @override
  String get themeSettingsSystem => 'System';

  @override
  String get themeSettingsLightSubtitle => 'High contrast for bright days';

  @override
  String get themeSettingsDarkSubtitle =>
      'Energy-saving mode for shady surroundings';

  @override
  String get themeSettingsSystemSubtitle => 'Follow system setting';

  @override
  String validationErrorsDialogAllErrorsNeedNote(int count) {
    return 'All errors must be acknowledged with a note ($count remaining)';
  }

  @override
  String get validationErrorsDialogGroupCorner => 'Plot corner';

  @override
  String get validationErrorsDialogGroupPosition => 'Position';

  @override
  String get validationErrorsDialogGroupEdges => 'Edges';

  @override
  String get validationErrorsDialogGroupStructureLt4m => 'Structure < 4m';

  @override
  String get validationErrorsDialogGroupStructureGt4m => 'Structure > 4m';

  @override
  String get validationErrorsDialogGroupStocking => 'Stocking';

  @override
  String get validationErrorsDialogGroupRegeneration => 'Regeneration';

  @override
  String get validationErrorsDialogGroupDeadwood => 'Deadwood';

  @override
  String get validationErrorsDialogPlausibilityUnavailable =>
      'The plausibility check could not be run (temporary technical problem). The plot corner can still be completed and submitted.';

  @override
  String get validationErrorsDialogTitle => 'Check results';

  @override
  String get validationErrorsDialogNoIssues => 'No errors or warnings found.';

  @override
  String validationErrorsDialogErrorCount(int count) {
    return '$count errors';
  }

  @override
  String validationErrorsDialogWarningCount(int count) {
    return '$count warnings';
  }

  @override
  String validationErrorsDialogNote(String note) {
    return 'Note: $note';
  }

  @override
  String validationErrorsDialogObject(String object) {
    return 'Object: $object';
  }

  @override
  String validationErrorsDialogPath(String path) {
    return 'Path: $path';
  }

  @override
  String get validationErrorsDialogAddNoteRequired =>
      'Add note (required for errors)*';

  @override
  String get validationErrorsDialogAddNoteOptional => 'Add note (optional)';

  @override
  String get validationErrorsDialogNoteLabel => 'Note';

  @override
  String get validationErrorsDialogNoteRequired => 'Note required';

  @override
  String get validationErrorsDialogSubmit =>
      'SUBMIT TO STATE INVENTORY MANAGEMENT';

  @override
  String validationErrorsDialogFixOrComment(int count) {
    return 'Fix or comment on $count errors';
  }

  @override
  String get serialPortGpsCancel => 'Cancel';

  @override
  String bluetoothIconClassicScanFailed(String error) {
    return 'Search for Bluetooth Classic devices failed: $error';
  }

  @override
  String get bluetoothIconPairingFailedTitle => 'Pairing failed';

  @override
  String bluetoothIconPairingFailedHint(String label) {
    return 'Device \"$label\" could not be paired.\n\nPlease check that the device is switched on and discoverable, and confirm the pairing request on both devices.';
  }

  @override
  String bluetoothIconPairingFailedError(String label, String error) {
    return 'Device \"$label\" could not be paired.\n\n$error';
  }

  @override
  String get bluetoothIconAvailableDevices => 'Available GNSS devices';

  @override
  String get bluetoothIconNotPairedTooltip =>
      'Not paired yet – pairing starts when tapped';

  @override
  String get bluetoothIconPaired => 'paired';

  @override
  String get positionSelectorNavigateByCar => 'Navigate by car';

  @override
  String get positionSelectorNavigateOnFoot => 'Navigate on foot';

  @override
  String get positionSelectorShowOnMap => 'Show on map';

  @override
  String get positionSelectorMapPosition => 'Map position';

  @override
  String get positionSelectorCurrentGpsPosition => 'Current GPS position';

  @override
  String get positionSelectorSaved => 'Saved';

  @override
  String get positionSelectorGpsPosition => 'GPS position';

  @override
  String get positionSelectorNoGpsData => 'No GPS data available';

  @override
  String get positionSelectorSetPosition => 'Set position';

  @override
  String get positionSelectorSavedLower => 'saved';

  @override
  String get positionSelectorEnableLiveTracking => 'Enable live tracking';

  @override
  String get positionSelectorPickOnMap => 'Select position on map';

  @override
  String get positionSelectorTapOnMap => 'Tap on the map';

  @override
  String get positionSelectorDelete => 'Delete';

  @override
  String get positionSelectorCornerMeasurements => 'Corner measurements';

  @override
  String get positionSelectorCenter => 'Center';

  @override
  String get positionSelectorSupportPoints => 'Support points';

  @override
  String get positionSelectorSetAsCenter => 'Set as center';

  @override
  String get manuellRelativePositionInvalidValues =>
      'Please enter valid values for azimuth and distance';

  @override
  String get manuellRelativePositionAzimuthRange =>
      'Azimuth must be between 0 and 400 gon';

  @override
  String manuellRelativePositionNothingToFocus(String label) {
    return 'No $label available to focus on';
  }

  @override
  String get manuellRelativePositionSelectedPosition => 'Selected position';

  @override
  String get manuellRelativePositionGpsPosition => 'GPS position';

  @override
  String manuellRelativePositionStartPosition(String label) {
    return 'Start position: $label';
  }

  @override
  String get manuellRelativePositionNoData => 'No data';

  @override
  String get manuellRelativePositionPosition => 'position';

  @override
  String get manuellRelativePositionDestination => 'Target position';

  @override
  String get manuellRelativePositionSetDestination => 'Set target';

  @override
  String get manuellRelativePositionAzimuth => 'Azimuth';

  @override
  String get manuellRelativePositionDistance => 'Distance';

  @override
  String get manuellRelativePositionAzimuthGon => 'Azimuth (gon)';

  @override
  String get manuellRelativePositionDistanceMeters => 'Distance (m)';

  @override
  String get manuellRelativePositionMetersHint => 'Meters';

  @override
  String manuellRelativePositionAfterStep(int step) {
    return 'position after step $step';
  }

  @override
  String get recordPositionQualityGood => 'good';

  @override
  String get recordPositionQualityOk => 'suitable';

  @override
  String get recordPositionQualityNotAcceptable => 'not suitable';

  @override
  String get recordPositionLastGpsInfo => 'Last measured GPS information';

  @override
  String get recordPositionConnection => 'Connection';

  @override
  String get recordPositionUnknown => 'Unknown';

  @override
  String recordPositionSerial(String port) {
    return 'Serial: $port';
  }

  @override
  String get recordPositionInternalGps => 'Internal GPS';

  @override
  String get recordPositionNoConnection => 'No connection';

  @override
  String get recordPositionTimestamp => 'Time';

  @override
  String get recordPositionCorrectionSignal => 'Correction signal';

  @override
  String get recordPositionCorrectionSignalAge => 'Correction signal age';

  @override
  String get recordPositionSatellites => 'Satellites';

  @override
  String get recordPositionAltitude => 'Altitude';

  @override
  String get recordPositionNoGpsData => 'No GPS data available';

  @override
  String get recordPositionSavedMeasurement => 'Saved measurement';

  @override
  String get recordPositionMeasurements => 'Measurements';

  @override
  String get recordPositionSatellitesAvg => 'Satellites (avg)';

  @override
  String get recordPositionCurrentMeasurement => 'Current measurement';

  @override
  String recordPositionRecordingProgress(String current, String total) {
    return 'Recording: $current / $total positions';
  }

  @override
  String get recordPositionStopMeasurement => 'Stop measurement';

  @override
  String recordPositionCompleted(String count) {
    return 'Completed: $count positions recorded';
  }

  @override
  String get recordPositionStartNewMeasurement => 'Start new measurement';

  @override
  String get recordPositionStartMeasurement => 'Start measurement';

  @override
  String get recordPositionWaitingForValidGps =>
      'Waiting for a valid GPS signal...';

  @override
  String get recordPositionDiscardMeasurement => 'Discard measurement';

  @override
  String get recordPositionReplaceMeasurement => 'Replace measurement';

  @override
  String get recordPositionApplyMeasurement => 'Apply measurement';

  @override
  String get recordPositionNotSuitable => 'Not suitable';

  @override
  String get recordPositionDgpsAvailable => 'DGPS available';

  @override
  String get recordPositionRtkFixedAvailable => 'RTK Fixed available';

  @override
  String get recordPositionRtkFloatAvailable => 'RTK Float available';

  @override
  String get displacedMarkerMinDistance => 'at least 1 cm';

  @override
  String get displacedMarkerAdd => 'Add displaced marker';

  @override
  String get displacedMarkerTitle => 'Displaced marker';

  @override
  String get displacedMarkerRemove => 'Remove displaced marker';

  @override
  String get displacedMarkerHorizontalDistance => 'Horizontal distance';

  @override
  String get displacedMarkerAzimuth => 'Azimuth';

  @override
  String get displacedMarkerDescription => 'Description';

  @override
  String get displacedMarkerIsMarked => 'Is marked';

  @override
  String get previousPositionsNavigationGpsLocked => 'GPS position (locked)';

  @override
  String get previousPositionsNavigationNoPreviousData =>
      'No previous position data available';

  @override
  String get previousPositionsNavigationNoCoordinates =>
      'No coordinates found in previous position data';

  @override
  String get previousPositionsNavigationTitle => 'Navigation:';

  @override
  String get previousPositionsNavigationTarget => 'Target';

  @override
  String previousPositionsNavigationDistanceAzimuth(
    String distance,
    String azimuth,
    String coordinates,
  ) {
    return 'Distance: $distance, azimuth: $azimuth gon$coordinates';
  }

  @override
  String get previousPositionsNavigationNoNavigationData =>
      'No navigation data available. Connect an external GPS or use the device\'s internal GPS.';

  @override
  String get previousPositionsSelectionNoData =>
      'No previous position data available';

  @override
  String get previousPositionsSelectionTitle =>
      'Previous position measurements';

  @override
  String get manualNavigationStepsAzimuthRange =>
      'Azimuth must be between 0 and 400 gon';

  @override
  String get manualNavigationStepsTooltip => 'Manual navigation';

  @override
  String get manualNavigationStepsSelectStartAndTarget =>
      'Select start and target';

  @override
  String get manualNavigationStepsDistance => 'Distance';

  @override
  String get manualNavigationStepsAzimuth => 'Azimuth';

  @override
  String get landmarkPointsMinDistance => 'at least 1 cm';

  @override
  String landmarkPointsTitle(int number) {
    return 'Landmark point $number';
  }

  @override
  String get landmarkPointsRemove => 'Remove landmark point';

  @override
  String get landmarkPointsHorizontalDistance => 'Horizontal distance';

  @override
  String get landmarkPointsAzimuth => 'Azimuth';

  @override
  String get landmarkPointsDescription => 'Description';

  @override
  String get landmarkPointsHint =>
      'Azimuth and distance from the plot corner to the landmark point';

  @override
  String get landmarkPointsAdd => 'Add landmark point';

  @override
  String get helpingPointUnknown => 'Unknown';

  @override
  String helpingPointRecordingProgress(int current, int total) {
    return 'Measuring... $current/$total';
  }

  @override
  String get helpingPointCancel => 'Cancel';

  @override
  String helpingPointMeasurementCountShort(String count) {
    return '$count meas.';
  }

  @override
  String get helpingPointNewMeasurement => 'new measurement';

  @override
  String get helpingPointMeasurements => 'Measurements';

  @override
  String get helpingPointAccuracy => 'Accuracy';

  @override
  String get helpingPointSatellites => 'Satellites';

  @override
  String get helpingPointCorrectionSignal => 'Correction signal';

  @override
  String get helpingPointTimestamp => 'Time';

  @override
  String get helpingPointStartMeasurement => 'Start measurement';

  @override
  String plotSupportPointsAzimuth(String azimuth) {
    return 'Azimuth: $azimuth gon';
  }

  @override
  String plotSupportPointsDistance(String distance) {
    return 'Distance: $distance cm';
  }

  @override
  String get formWrapperMessagesUnavailable =>
      'Messages not available: no record loaded';

  @override
  String get arrayElementArchiveRowDeleteBlocked =>
      'Existing entry from the inventory – cannot be deleted.';

  @override
  String get arrayElementTrinaFilterTooltip => 'Filter';

  @override
  String get arrayElementCardlistDeleteProtectedTooltip =>
      'Existing entry from the inventory – cannot be deleted';

  @override
  String get arrayElementCardlistDeleteEntry => 'Delete entry';

  @override
  String arrayElementCardlistMaxEntries(int maxRows) {
    return 'Maximum $maxRows entries';
  }

  @override
  String arrayElementCardlistAddEntry(String label) {
    return 'Add $label';
  }

  @override
  String get arrayElementCardlistEntryDefault => 'entry';

  @override
  String get arrayFilterDialogTitle => 'Hide';

  @override
  String get arrayFilterDialogNoFilters => 'No filters available';

  @override
  String get cardDialogNoFields => 'No fields available';

  @override
  String get cardDialogDone => 'Done';

  @override
  String get genericTextfieldInfoTooltip => 'Info';

  @override
  String permissionsSelectionSyncing(String percent) {
    return 'Synchronising permissions…$percent';
  }

  @override
  String get permissionsSelectionNone => 'No permissions found';

  @override
  String get permissionsSelectionTroopRequired => 'Troop membership required';

  @override
  String get databaseBackupSaveDialogTitle => 'Save database backup';

  @override
  String get databaseBackupSavedSealed => 'Backup saved (encrypted)';

  @override
  String get databaseBackupSaved => 'Backup saved';

  @override
  String databaseBackupFailed(String error) {
    return 'Backup failed: $error';
  }

  @override
  String get databaseBackupInProgress => 'Creating backup …';

  @override
  String get databaseBackupAllSealed => 'Backup of all databases (encrypted)';

  @override
  String get databaseBackupAllZip => 'Backup of all databases (ZIP)';
}
