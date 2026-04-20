import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for securely storing and retrieving user credentials
/// Uses flutter_secure_storage for encryption on device
class SecureStorageService {
  static const String _keyEmail = 'cached_user_email';
  static const String _keyPassword = 'cached_user_password';
  static const String _keyUserId = 'cached_user_id';
  static const String _keyAccessToken = 'cached_access_token';
  static const String _keyRefreshToken = 'cached_refresh_token';
  static const String _keyTokenExpiry = 'cached_token_expiry';
  static const String _keyLastOnlineLogin = 'last_online_login';

  // v10: default cipher is AES-GCM (was CBC in v9 — fixes MobSF HIGH finding).
  // migrateOnAlgorithmChange: true re-encrypts existing data on first access.
  // resetOnError: false keeps explicit control (v10 changed default to true).
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(migrateOnAlgorithmChange: true, resetOnError: false),
  );

  /// Store user credentials securely after successful online login
  Future<void> cacheCredentials({
    required String email,
    required String password,
    required String userId,
    String? accessToken,
    String? refreshToken,
    DateTime? tokenExpiry,
  }) async {
    try {
      await _storage.write(key: _keyEmail, value: email);
      await _storage.write(key: _keyPassword, value: password);
      await _storage.write(key: _keyUserId, value: userId);

      if (accessToken != null) {
        await _storage.write(key: _keyAccessToken, value: accessToken);
      }

      if (refreshToken != null) {
        await _storage.write(key: _keyRefreshToken, value: refreshToken);
      }

      if (tokenExpiry != null) {
        await _storage.write(key: _keyTokenExpiry, value: tokenExpiry.toIso8601String());
      }

      await _storage.write(key: _keyLastOnlineLogin, value: DateTime.now().toIso8601String());
    } catch (e) {
      rethrow;
    }
  }

  /// Get cached email
  Future<String?> getCachedEmail() async {
    try {
      return await _storage.read(key: _keyEmail);
    } catch (e) {
      return null;
    }
  }

  /// Get cached password
  Future<String?> getCachedPassword() async {
    try {
      return await _storage.read(key: _keyPassword);
    } catch (e) {
      return null;
    }
  }

  /// Get cached user ID
  Future<String?> getCachedUserId() async {
    try {
      return await _storage.read(key: _keyUserId);
    } catch (e) {
      return null;
    }
  }

  /// Get cached access token
  Future<String?> getCachedAccessToken() async {
    try {
      return await _storage.read(key: _keyAccessToken);
    } catch (e) {
      return null;
    }
  }

  /// Get cached refresh token
  Future<String?> getCachedRefreshToken() async {
    try {
      return await _storage.read(key: _keyRefreshToken);
    } catch (e) {
      return null;
    }
  }

  /// Get last online login timestamp
  Future<DateTime?> getLastOnlineLogin() async {
    try {
      final dateStr = await _storage.read(key: _keyLastOnlineLogin);
      if (dateStr != null) {
        return DateTime.parse(dateStr);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if credentials are cached
  Future<bool> hasCredentials() async {
    try {
      final email = await getCachedEmail();
      final password = await getCachedPassword();
      return email != null && password != null;
    } catch (e) {
      return false;
    }
  }

  /// Validate offline login credentials
  Future<bool> validateOfflineCredentials(String email, String password) async {
    try {
      final cachedEmail = await getCachedEmail();
      final cachedPassword = await getCachedPassword();

      if (cachedEmail == null || cachedPassword == null) {
        return false;
      }

      return cachedEmail == email && cachedPassword == password;
    } catch (e) {
      return false;
    }
  }

  /// Check if offline login is allowed (e.g., not too old)
  Future<bool> isOfflineLoginAllowed({int maxDaysOffline = 30}) async {
    try {
      final lastOnlineLogin = await getLastOnlineLogin();

      if (lastOnlineLogin == null) {
        return false;
      }

      final daysSinceLastOnline = DateTime.now().difference(lastOnlineLogin).inDays;
      return daysSinceLastOnline <= maxDaysOffline;
    } catch (e) {
      return false;
    }
  }

  /// Clear all cached credentials
  Future<void> clearCredentials() async {
    try {
      await _storage.delete(key: _keyEmail);
      await _storage.delete(key: _keyPassword);
      await _storage.delete(key: _keyUserId);
      await _storage.delete(key: _keyAccessToken);
      await _storage.delete(key: _keyRefreshToken);
      await _storage.delete(key: _keyTokenExpiry);
      await _storage.delete(key: _keyLastOnlineLogin);

      print('SecureStorageService: All credentials cleared');
    } catch (e) {
      rethrow;
    }
  }

  /// Clear all secure storage (use with caution)
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      rethrow;
    }
  }

  /// Update stored tokens after successful refresh
  Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
    DateTime? tokenExpiry,
  }) async {
    try {
      await _storage.write(key: _keyAccessToken, value: accessToken);
      await _storage.write(key: _keyRefreshToken, value: refreshToken);
      if (tokenExpiry != null) {
        await _storage.write(key: _keyTokenExpiry, value: tokenExpiry.toIso8601String());
      }
      // Update last online login since we just connected to Supabase
      await _storage.write(key: _keyLastOnlineLogin, value: DateTime.now().toIso8601String());
    } catch (e) {
      rethrow;
    }
  }
}
