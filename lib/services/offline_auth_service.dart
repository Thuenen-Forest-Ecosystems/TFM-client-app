import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:terrestrial_forest_monitor/services/secure_storage_service.dart';

/// Service for handling offline authentication
class OfflineAuthService {
  final SecureStorageService _secureStorage = SecureStorageService();

  /// Check if device is online
  Future<bool> isOnline() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult.any((result) => result != ConnectivityResult.none);
    } catch (e) {
      print('OfflineAuthService: Error checking connectivity - $e');
      return false;
    }
  }

  /// Attempt offline login
  /// Returns a map with success status and optional error message
  Future<Map<String, dynamic>> loginOffline(String email, String password) async {
    try {
      print('OfflineAuthService: Attempting offline login for $email');

      // Check if we have cached credentials
      final hasCredentials = await _secureStorage.hasCredentials();
      if (!hasCredentials) {
        print('OfflineAuthService: No cached credentials found');
        return {
          'success': false,
          'error':
              'Keine zwischengespeicherten Anmeldedaten gefunden. Bitte melden Sie sich online an, um den Offline-Modus zu aktivieren.',
        };
      }

      // Check if offline login is still allowed (not expired)
      final isAllowed = await _secureStorage.isOfflineLoginAllowed(maxDaysOffline: 30);
      if (!isAllowed) {
        print('OfflineAuthService: Offline login expired');
        return {
          'success': false,
          'error':
              'Offline-Anmeldung abgelaufen. Bitte melden Sie sich online an, um fortzufahren.',
        };
      }

      // Validate credentials
      final isValid = await _secureStorage.validateOfflineCredentials(email, password);
      if (!isValid) {
        print('OfflineAuthService: Invalid offline credentials');
        return {
          'success': false,
          'error':
              'Ungültige Anmeldedaten. Die eingegebenen Daten stimmen nicht mit den zwischengespeicherten Anmeldedaten überein.',
        };
      }

      // Get cached user data
      final userId = await _secureStorage.getCachedUserId();
      final cachedEmail = await _secureStorage.getCachedEmail();

      print('OfflineAuthService: Offline login successful for $cachedEmail');

      return {'success': true, 'userId': userId, 'email': cachedEmail};
    } catch (e) {
      print('OfflineAuthService: Error during offline login - $e');
      return {
        'success': false,
        'error': 'Ein Fehler ist während der Offline-Anmeldung aufgetreten: $e',
      };
    }
  }

  /// Save credentials after successful online login
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
      print('OfflineAuthService: Online login credentials saved');
    } catch (e) {
      print('OfflineAuthService: Error saving credentials - $e');
      rethrow;
    }
  }

  /// Clear stored credentials on logout
  Future<void> clearStoredCredentials() async {
    try {
      await _secureStorage.clearCredentials();
      print('OfflineAuthService: Stored credentials cleared');
    } catch (e) {
      print('OfflineAuthService: Error clearing credentials - $e');
      rethrow;
    }
  }

  /// Check if user has previously logged in (has cached credentials)
  Future<bool> hasPreviousLogin() async {
    try {
      return await _secureStorage.hasCredentials();
    } catch (e) {
      print('OfflineAuthService: Error checking previous login - $e');
      return false;
    }
  }

  /// Get cached email for convenience
  Future<String?> getCachedEmail() async {
    try {
      return await _secureStorage.getCachedEmail();
    } catch (e) {
      print('OfflineAuthService: Error getting cached email - $e');
      return null;
    }
  }

  /// Get last online login date for display
  Future<DateTime?> getLastOnlineLogin() async {
    try {
      return await _secureStorage.getLastOnlineLogin();
    } catch (e) {
      print('OfflineAuthService: Error getting last online login - $e');
      return null;
    }
  }

  /// Get the stored refresh token for session restoration
  Future<String?> getRefreshToken() async {
    try {
      return await _secureStorage.getCachedRefreshToken();
    } catch (e) {
      print('OfflineAuthService: Error getting refresh token - $e');
      return null;
    }
  }

  /// Get the stored access token for session restoration
  Future<String?> getAccessToken() async {
    try {
      return await _secureStorage.getCachedAccessToken();
    } catch (e) {
      print('OfflineAuthService: Error getting access token - $e');
      return null;
    }
  }

  /// Update stored tokens after successful refresh
  Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
    DateTime? tokenExpiry,
  }) async {
    try {
      await _secureStorage.updateTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        tokenExpiry: tokenExpiry,
      );
      print('OfflineAuthService: Tokens updated successfully');
    } catch (e) {
      print('OfflineAuthService: Error updating tokens - $e');
      rethrow;
    }
  }
}
