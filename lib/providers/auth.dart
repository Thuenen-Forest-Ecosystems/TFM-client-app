import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:terrestrial_forest_monitor/services/organization_selection_service.dart';
import 'package:terrestrial_forest_monitor/services/offline_auth_service.dart';
import 'dart:async';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _userEmail;
  String? _userId;
  bool _loggingIn = false;
  bool _isOfflineMode = false;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final OfflineAuthService _offlineAuthService = OfflineAuthService();

  bool get isAuthenticated => _isAuthenticated;
  String? get userEmail => _userEmail;
  String? get userId => _userId;
  bool get loggingIn => _loggingIn;
  bool get isOfflineMode => _isOfflineMode;

  AuthProvider() {
    // Safely listen to auth state changes only if Supabase is initialized
    try {
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
        print(
          'AuthProvider: Auth state changed - event: ${data.event}, user: ${data.session?.user.email}',
        );
        _loggingIn = false;
        _getUser();
      });
      _getUser();
    } catch (e) {
      // Supabase not yet initialized - will be called later via checkAuthStatus
      print('AuthProvider: Supabase not initialized yet in constructor');
    }

    // Listen for connectivity changes to transition from offline to online
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final isOnline = results.any((result) => result != ConnectivityResult.none);

    // If we're in offline mode and connection is restored, try to upgrade to online mode
    if (_isOfflineMode && isOnline) {
      print('AuthProvider: Connection restored, attempting to upgrade to online mode');
      await _upgradeToOnlineMode();
    }
  }

  Future<void> _upgradeToOnlineMode() async {
    try {
      // Get cached refresh token and access token
      final refreshToken = await _offlineAuthService.getRefreshToken();
      final accessToken = await _offlineAuthService.getAccessToken();

      if (refreshToken == null || accessToken == null) {
        print('AuthProvider: Cannot upgrade to online mode - no tokens available');
        return;
      }

      print('AuthProvider: Attempting to restore Supabase session with stored tokens');

      // Set the session using stored tokens, which will automatically refresh if needed
      final response = await Supabase.instance.client.auth.setSession(refreshToken);

      if (response.session != null && response.user != null) {
        print('AuthProvider: Successfully upgraded to online mode - ${response.user!.email}');

        // Update stored tokens with new ones (only if refresh token is available)
        if (response.session!.refreshToken != null) {
          await _offlineAuthService.updateTokens(
            accessToken: response.session!.accessToken,
            refreshToken: response.session!.refreshToken!,
            tokenExpiry:
                response.session!.expiresAt != null
                    ? DateTime.fromMillisecondsSinceEpoch(response.session!.expiresAt! * 1000)
                    : null,
          );
        }

        // Clear offline mode - the auth state listener will update authentication state
        _isOfflineMode = false;
        notifyListeners();
      } else {
        print('AuthProvider: Session restore returned no session - staying in offline mode');
      }
    } catch (e) {
      print('AuthProvider: Error upgrading to online mode - $e');
      // If refresh fails, stay in offline mode until manual re-login
    }
  }

  void _getUser() {
    final user = Supabase.instance.client.auth.currentUser;

    if (user != null) {
      print('AuthProvider: User authenticated - email: ${user.email}, id: ${user.id}');
      _isAuthenticated = true;
      _userEmail = user.email;
      _userId = user.id;
    } else {
      print('AuthProvider: No authenticated user');
      _isAuthenticated = false;
      _userEmail = null;
      _userId = null;
    }

    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    try {
      print('AuthProvider: Starting login for $email');
      _loggingIn = true;
      _isOfflineMode = false;
      notifyListeners();

      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      print(
        'AuthProvider: Login response - user: ${response.user?.email}, session: ${response.session != null}',
      );

      // Save credentials for offline use
      if (response.user != null && response.session != null) {
        await _offlineAuthService.saveOnlineLoginCredentials(
          email: email,
          password: password,
          userId: response.user!.id,
          accessToken: response.session!.accessToken,
          refreshToken: response.session!.refreshToken,
          tokenExpiry:
              response.session!.expiresAt != null
                  ? DateTime.fromMillisecondsSinceEpoch(response.session!.expiresAt! * 1000)
                  : null,
        );
        print('AuthProvider: Credentials saved for offline use');
      }

      // User will be updated via the auth state listener
    } catch (e) {
      print('AuthProvider: Login failed - $e');
      _loggingIn = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loginOffline(String email, String password) async {
    try {
      print('AuthProvider: Starting offline login for $email');
      _loggingIn = true;
      notifyListeners();

      final result = await _offlineAuthService.loginOffline(email, password);

      if (result['success']) {
        _isAuthenticated = true;
        _isOfflineMode = true;
        _userEmail = result['email'];
        _userId = result['userId'];
        _loggingIn = false;

        print('AuthProvider: Offline login successful - user: $_userEmail, id: $_userId');
        notifyListeners();
      } else {
        _loggingIn = false;
        notifyListeners();
        throw Exception(result['error']);
      }
    } catch (e) {
      print('AuthProvider: Offline login failed - $e');
      _loggingIn = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      // Clear selected organization before logging out
      await OrganizationSelectionService().clearSelectedOrganization();

      // DO NOT clear offline credentials - keep them for future offline login
      // Users should be able to log back in offline with the same credentials
      print('AuthProvider: Logging out but keeping cached credentials for offline use');

      if (_isOfflineMode) {
        // If offline mode, just clear local state
        _isAuthenticated = false;
        _isOfflineMode = false;
        _userEmail = null;
        _userId = null;
        notifyListeners();
      } else {
        // If online, sign out from Supabase
        await Supabase.instance.client.auth.signOut();
        // User will be cleared via the auth state listener
      }
    } catch (e) {
      print('Logout error: $e');
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
    return await _offlineAuthService.getLastOnlineLogin();
  }

  Future<void> checkAuthStatus() async {
    // Set up auth subscription if it wasn't initialized in constructor
    if (_authSubscription == null) {
      try {
        _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
          _loggingIn = false;
          _getUser();
        });
      } catch (e) {
        print('checkAuthStatus: Error setting up auth subscription: $e');
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
