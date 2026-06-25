import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:terrestrial_forest_monitor/services/organization_selection_service.dart';
import 'package:terrestrial_forest_monitor/services/offline_auth_service.dart';
import 'package:terrestrial_forest_monitor/services/background_sync_service.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'dart:async';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _userEmail;
  String? _userId;
  bool _loggingIn = false;
  bool _isOfflineMode = false;
  bool _isExplicitLogout = false;
  bool _sessionExpiredError = false;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final OfflineAuthService _offlineAuthService = OfflineAuthService();

  bool get isAuthenticated => _isAuthenticated;
  String? get userEmail => _userEmail;
  String? get userId => _userId;
  bool get loggingIn => _loggingIn;
  bool get isOfflineMode => _isOfflineMode;

  /// True when the user was signed out by Supabase (token expiry / refresh
  /// failure) rather than by an explicit logout action.
  bool get sessionExpiredError => _sessionExpiredError;

  void clearSessionExpiredError() {
    if (_sessionExpiredError) {
      _sessionExpiredError = false;
      // no notifyListeners needed — caller redraws on its own
    }
  }

  AuthProvider() {
    // Safely listen to auth state changes only if Supabase is initialized
    try {
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
        _onAuthStateChange,
      );
      _getUser();
    } catch (e) {
      // Supabase not yet initialized - will be called later via checkAuthStatus
    }

    // Listen for connectivity changes to transition from offline to online
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);

    // Also check connectivity right now — onConnectivityChanged only fires on
    // *changes*, so if the app starts while already online with _isOfflineMode
    // still true (e.g. network was restored before the app was opened), the
    // upgrade would never be triggered without this initial check.
    _checkInitialConnectivityAndUpgrade();
  }

  Future<void> _checkInitialConnectivityAndUpgrade() async {
    if (!_isOfflineMode) return;
    final results = await Connectivity().checkConnectivity();
    final isOnline = results.any((r) => r != ConnectivityResult.none);
    if (isOnline) {
      await _upgradeToOnlineMode();
    }
  }

  /// Shared handler for all onAuthStateChange events.
  Future<void> _onAuthStateChange(AuthState data) async {
    _loggingIn = false;

    // Always persist refreshed tokens so that offline-mode session
    // restoration uses the latest (valid) refresh token. Supabase uses
    // rolling refresh-token rotation: every auto-refresh invalidates the
    // previous token. Without this update the stored token becomes stale
    // and _upgradeToOnlineMode() would fail after even a single refresh
    // cycle, locking the user out after coming back from days offline.
    if ((data.event == AuthChangeEvent.tokenRefreshed || data.event == AuthChangeEvent.signedIn) &&
        data.session != null &&
        data.session!.refreshToken != null &&
        data.session!.user.email != null) {
      try {
        await _offlineAuthService.updateTokens(
          email: data.session!.user.email!,
          accessToken: data.session!.accessToken,
          refreshToken: data.session!.refreshToken!,
          tokenExpiry: data.session!.expiresAt != null
              ? DateTime.fromMillisecondsSinceEpoch(data.session!.expiresAt! * 1000)
              : null,
        );
      } catch (e) {
      }
    }

    // When Supabase fires signedOut while we are already in offline mode
    // (e.g. it detects a stale/expired stored session after connectivity is
    // restored) we must NOT log the user out — the offline session is still
    // valid and _upgradeToOnlineMode() will re-establish the Supabase session.
    if (data.event == AuthChangeEvent.signedOut &&
        _isAuthenticated &&
        _isOfflineMode &&
        !_isExplicitLogout) {
      return;
    }

    // When Supabase fires signedOut due to a failed token refresh while the
    // device is offline, we must NOT log the user out — the app is
    // offline-first and the session will be restored once connectivity
    // returns. Switch to offline mode using cached credentials instead.
    if (data.event == AuthChangeEvent.signedOut &&
        _isAuthenticated &&
        !_isOfflineMode &&
        !_isExplicitLogout) {
      final isOnline = await _offlineAuthService.isOnline();
      if (!isOnline && await _offlineAuthService.hasPreviousLogin()) {
        final cachedEmail = await _offlineAuthService.getCachedEmail();
        _isOfflineMode = true;
        // Keep _isAuthenticated = true; preserve userId/email from current
        // state or fall back to cached values.
        _userEmail = _userEmail ?? cachedEmail;
        _isExplicitLogout = false;
        notifyListeners();
        return; // Do not call _getUser() — it would clear auth
      }
      // Device is online but session was rejected — real session expiry.
      _sessionExpiredError = true;
    }

    // Whenever we have a valid session, point the global [db] at that user's
    // personal database BEFORE calling _getUser() so that navigation
    // (triggered by notifyListeners inside _getUser) never sees the previous
    // user's data and writes never land in the legacy shared tfm.db.
    //
    // This must cover initialSession and tokenRefreshed, not just signedIn:
    // on app restart Supabase restores the persisted session and replays
    // initialSession (or tokenRefreshed when the stored token had expired and
    // was refreshed online) — never signedIn. Relying on signedIn alone left
    // the db on the legacy tfm.db, so offline-restored users wrote to the
    // wrong file. switchUserDatabase is idempotent, so calling it on every
    // session-bearing event is safe.
    final sessionUserId = data.session?.user.id;
    if (sessionUserId != null &&
        (data.event == AuthChangeEvent.signedIn ||
            data.event == AuthChangeEvent.initialSession ||
            data.event == AuthChangeEvent.tokenRefreshed)) {
      try {
        final didSwitch = await switchUserDatabase(sessionUserId);
        // Only (re)connect when we actually swapped to a new per-user db.
        // Calling db.connect() on every tokenRefreshed would restart the sync
        // connection and make in-progress downloads start over from scratch.
        if (didSwitch) {
          db.connect(connector: SupabaseConnector());
        }
      } catch (e) {
      }
    }

    _isExplicitLogout = false;
    _getUser();
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final isOnline = results.any((result) => result != ConnectivityResult.none);

    // If we're in offline mode and connection is restored, try to upgrade to online mode
    if (_isOfflineMode && isOnline) {
      await _upgradeToOnlineMode();
    }
  }

  Future<void> _upgradeToOnlineMode() async {
    try {
      // Get cached refresh token and access token for the current offline user
      if (_userEmail == null) {
        return;
      }
      final refreshToken = await _offlineAuthService.getRefreshToken(_userEmail!);
      final accessToken = await _offlineAuthService.getAccessToken(_userEmail!);

      if (refreshToken == null || accessToken == null) {
        return;
      }


      // Set the session using stored tokens, which will automatically refresh if needed
      final response = await Supabase.instance.client.auth.setSession(refreshToken);

      if (response.session != null && response.user != null) {

        // Update stored tokens with new ones (only if refresh token is available)
        if (response.session!.refreshToken != null && response.user!.email != null) {
          await _offlineAuthService.updateTokens(
            email: response.user!.email!,
            accessToken: response.session!.accessToken,
            refreshToken: response.session!.refreshToken!,
            tokenExpiry: response.session!.expiresAt != null
                ? DateTime.fromMillisecondsSinceEpoch(response.session!.expiresAt! * 1000)
                : null,
          );
        }

        // Clear offline mode first so the BeamGuard doesn't redirect on notify.
        _isOfflineMode = false;
        notifyListeners();

        // Connect PowerSync directly here. The onAuthStateChange(signedIn)
        // handler also calls db.connect(), but it runs asynchronously and its
        // timing relative to this point is unpredictable. Calling connect()
        // here ensures the sync chip updates immediately when the session is
        // restored. PowerSyncDatabase.connect() is safe to call more than once.
        db.connect(connector: SupabaseConnector());
      } else {
      }
    } catch (e) {

      // If the stored refresh token has been revoked / rotated server-side
      // (Supabase returns refresh_token_not_found / 400), fall back to
      // re-authenticating with the cached password. This is transparent to
      // the user — they stay on the current screen and PowerSync connects
      // normally once the fresh session is established.
      final errStr = e.toString();
      final isTokenInvalid =
          errStr.contains('refresh_token_not_found') ||
          errStr.contains('token_not_found') ||
          errStr.contains('Invalid Refresh Token') ||
          (errStr.contains('statusCode: 400') && errStr.contains('AuthApiException'));

      if (isTokenInvalid && _userEmail != null) {
        await _upgradeWithPassword();
      }
      // For transient errors (SocketException, timeout, etc.) stay in offline
      // mode — the upgrade will be retried when connectivity changes again.
    }
  }

  /// Fallback: re-authenticate using the stored password when the refresh
  /// token has been rotated. Stays in offline mode silently on failure.
  Future<void> _upgradeWithPassword() async {
    try {
      final password = await _offlineAuthService.getCachedPassword(_userEmail!);
      if (password == null) {
        return;
      }

      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _userEmail!,
        password: password,
      );

      if (response.session != null && response.user != null) {
        // signedIn event will fire and call db.connect() via the auth listener,
        // but call it directly here too for immediate feedback.
        _isOfflineMode = false;
        notifyListeners();
        db.connect(connector: SupabaseConnector());
      } else {
      }
    } catch (e) {
      // Silently stay in offline mode; never force-redirect to login.
    }
  }

  void _getUser() {
    final user = Supabase.instance.client.auth.currentUser;
    bool shouldNotify = false;

    if (user != null) {
      if (!_isAuthenticated || _userId != user.id || _userEmail != user.email) {
        _isAuthenticated = true;
        _userEmail = user.email;
        _userId = user.id;
        shouldNotify = true;
      }
    } else if (!_isOfflineMode) {
      // Only clear auth if we are NOT in offline mode. In offline mode there
      // is intentionally no Supabase session, so a null currentUser is expected
      // and must not be treated as a sign-out.
      if (_isAuthenticated) {
        _isAuthenticated = false;
        _userEmail = null;
        _userId = null;
        shouldNotify = true;
      }
    }

    if (shouldNotify) {
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    try {
      _loggingIn = true;
      _isOfflineMode = false;
      notifyListeners();

      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );


      // Save credentials for offline use
      if (response.user != null && response.session != null) {
        await _offlineAuthService.saveOnlineLoginCredentials(
          email: email,
          password: password,
          userId: response.user!.id,
          accessToken: response.session!.accessToken,
          refreshToken: response.session!.refreshToken,
          tokenExpiry: response.session!.expiresAt != null
              ? DateTime.fromMillisecondsSinceEpoch(response.session!.expiresAt! * 1000)
              : null,
        );

        // Register periodic background sync (runs every hour, for when app is backgrounded)
        // Do NOT register an immediate one-time sync here — the foreground
        // PowerSync connection is already syncing. A competing background
        // connection would interfere with the in-progress download.
        await BackgroundSyncService.registerPeriodicSync();
      }

      // User will be updated via the auth state listener
    } catch (e) {
      _loggingIn = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loginOffline(String email, String password) async {
    try {
      _loggingIn = true;
      notifyListeners();

      final result = await _offlineAuthService.loginOffline(email, password);

      if (result['success']) {
        _isAuthenticated = true;
        _isOfflineMode = true;
        _userEmail = result['email'];
        _userId = result['userId'];
        _loggingIn = false;

        // Switch to this user's personal database file so their offline
        // data is available and other users' data is not visible.
        if (_userId != null) {
          await switchUserDatabase(_userId!);
        }

        notifyListeners();
      } else {
        _loggingIn = false;
        notifyListeners();
        throw Exception(result['error']);
      }
    } catch (e) {
      _loggingIn = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      // Clear ALL selected-organization preferences before logging out so the
      // next user starts with a clean slate (troop, isAdmin, permissionId, etc.)
      await OrganizationSelectionService().clearAllSelections();

      // Cancel background sync when logging out
      await BackgroundSyncService.cancelAll();

      // DO NOT clear offline credentials - keep them for future offline login
      // Users should be able to log back in offline with the same credentials

      if (_isOfflineMode) {
        // If offline mode, just clear local state
        _isAuthenticated = false;
        _isOfflineMode = false;
        _userEmail = null;
        _userId = null;
        notifyListeners();
      } else {
        // Mark as explicit so the signedOut event is not misread as a session
        // expiry by the onAuthStateChange listener.
        _isExplicitLogout = true;
        // If online, sign out from Supabase
        await Supabase.instance.client.auth.signOut();
        // User will be cleared via the auth state listener
      }
    } catch (e) {
      // Force logout even if there's an error
      _isAuthenticated = false;
      _isOfflineMode = false;
      _userEmail = null;
      _userId = null;
      notifyListeners();
    }
  }

  Future<bool> hasPreviousLogin() async {
    return await _offlineAuthService.hasPreviousLogin();
  }

  Future<String?> getCachedEmail() async {
    return await _offlineAuthService.getCachedEmail();
  }

  Future<DateTime?> getLastOnlineLogin() async {
    if (_userEmail == null) return null;
    return await _offlineAuthService.getLastOnlineLogin(_userEmail!);
  }

  Future<void> checkAuthStatus() async {
    // Set up auth subscription if it wasn't initialized in constructor
    if (_authSubscription == null) {
      try {
        _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
          _onAuthStateChange,
        );
      } catch (e) {
      }
    }
    _getUser();
  }

  Future<void> register(String email, String password) async {
    try {
      _loggingIn = true;
      notifyListeners();

      await Supabase.instance.client.auth.signUp(email: email, password: password);

      // User will be updated via the auth state listener
    } catch (e) {
      _loggingIn = false;
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
