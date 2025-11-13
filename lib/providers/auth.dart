import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _userEmail;
  String? _userId;
  bool _loggingIn = false;
  StreamSubscription<AuthState>? _authSubscription;

  bool get isAuthenticated => _isAuthenticated;
  String? get userEmail => _userEmail;
  String? get userId => _userId;
  bool get loggingIn => _loggingIn;

  AuthProvider() {
    // Safely listen to auth state changes only if Supabase is initialized
    try {
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
        _loggingIn = false;
        _getUser();
      });
      _getUser();
    } catch (e) {
      // Supabase not yet initialized - will be called later via checkAuthStatus
      print('AuthProvider: Supabase not initialized yet in constructor');
    }
  }

  void _getUser() {
    final user = Supabase.instance.client.auth.currentUser;

    if (user != null) {
      _isAuthenticated = true;
      _userEmail = user.email;
      _userId = user.id;
    } else {
      _isAuthenticated = false;
      _userEmail = null;
      _userId = null;
    }

    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    try {
      _loggingIn = true;
      notifyListeners();

      await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);

      // User will be updated via the auth state listener
    } catch (e) {
      _loggingIn = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      // User will be cleared via the auth state listener
    } catch (e) {
      print('Logout error: $e');
      // Force logout even if there's an error
      _isAuthenticated = false;
      _userEmail = null;
      _userId = null;
      notifyListeners();
    }
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
    super.dispose();
  }
}
