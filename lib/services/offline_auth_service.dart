import 'package:terrestrial_forest_monitor/services/connectivity_service.dart';
import 'package:terrestrial_forest_monitor/services/secure_storage_service.dart';

/// Service for handling offline authentication.
/// Supports multiple users — credentials are stored per-user so that
/// each user can log in offline independently on the same device.
class OfflineAuthService {
  final SecureStorageService _secureStorage = SecureStorageService();

  /// Check if device is online (via the shared [ConnectivityService]).
  Future<bool> isOnline() => ConnectivityService.instance.checkOnline();

  /// Attempt offline login for [email] / [password].
  Future<Map<String, dynamic>> loginOffline(String email, String password) async {
    try {

      final hasCredentials = await _secureStorage.hasCredentials(email);
      if (!hasCredentials) {
        return {
          'success': false,
          'error':
              'Keine zwischengespeicherten Anmeldedaten gefunden. Bitte melden Sie sich online an, um den Offline-Modus zu aktivieren.',
        };
      }

      final isAllowed = await _secureStorage.isOfflineLoginAllowed(email, maxDaysOffline: 30);
      if (!isAllowed) {
        return {
          'success': false,
          'error':
              'Offline-Anmeldung abgelaufen. Bitte melden Sie sich online an, um fortzufahren.',
        };
      }

      final isValid = await _secureStorage.validateOfflineCredentials(email, password);
      if (!isValid) {
        return {
          'success': false,
          'error':
              'Ungültige Anmeldedaten. Die eingegebenen Daten stimmen nicht mit den zwischengespeicherten Anmeldedaten überein.',
        };
      }

      final userId = await _secureStorage.getCachedUserId(email);
      return {'success': true, 'userId': userId, 'email': email};
    } catch (e) {
      return {
        'success': false,
        'error': 'Ein Fehler ist während der Offline-Anmeldung aufgetreten: $e',
      };
    }
  }

  /// Save credentials after successful online login.
  Future<void> saveOnlineLoginCredentials({
    required String email,
    required String password,
    required String userId,
    String? accessToken,
    String? refreshToken,
    DateTime? tokenExpiry,
  }) async {
    try {
      await _secureStorage.cacheCredentials(
        email: email,
        password: password,
        userId: userId,
        accessToken: accessToken,
        refreshToken: refreshToken,
        tokenExpiry: tokenExpiry,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Clear stored credentials for [email].
  Future<void> clearStoredCredentials(String email) async {
    try {
      await _secureStorage.clearCredentials(email);
    } catch (e) {
      rethrow;
    }
  }

  /// Whether ANY user on this device has previously logged in online.
  Future<bool> hasPreviousLogin() async {
    try {
      return await _secureStorage.hasAnyCredentials();
    } catch (e) {
      return false;
    }
  }

  /// Most-recently-used email (for pre-filling the login field).
  Future<String?> getCachedEmail() async {
    try {
      return await _secureStorage.getCachedEmail();
    } catch (e) {
      return null;
    }
  }

  /// Timestamp of last online login for [email].
  Future<DateTime?> getLastOnlineLogin(String email) async {
    try {
      return await _secureStorage.getLastOnlineLogin(email);
    } catch (e) {
      return null;
    }
  }

  /// Stored refresh token for [email].
  Future<String?> getRefreshToken(String email) async {
    try {
      return await _secureStorage.getCachedRefreshToken(email);
    } catch (e) {
      return null;
    }
  }

  /// Cached password for [email] (used as fallback for token-rotation recovery).
  Future<String?> getCachedPassword(String email) async {
    try {
      return await _secureStorage.getCachedPassword(email);
    } catch (e) {
      return null;
    }
  }

  /// Stored access token for [email].
  Future<String?> getAccessToken(String email) async {
    try {
      return await _secureStorage.getCachedAccessToken(email);
    } catch (e) {
      return null;
    }
  }

  /// Update stored tokens after a successful refresh for [email].
  Future<void> updateTokens({
    required String email,
    required String accessToken,
    required String refreshToken,
    DateTime? tokenExpiry,
  }) async {
    try {
      await _secureStorage.updateTokens(
        email: email,
        accessToken: accessToken,
        refreshToken: refreshToken,
        tokenExpiry: tokenExpiry,
      );
    } catch (e) {
      rethrow;
    }
  }
}
