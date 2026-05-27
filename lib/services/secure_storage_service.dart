import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for securely storing and retrieving user credentials per user.
/// Multiple users can have credentials cached simultaneously so that each
/// can log in offline independently on the same device.
class SecureStorageService {
  // ── Legacy (v1) keys ────────────────────────────────────────────────────────
  // Kept only for one-time migration to per-user keys.
  static const String _legacyKeyEmail = 'cached_user_email';
  static const String _legacyKeyPassword = 'cached_user_password';
  static const String _legacyKeyUserId = 'cached_user_id';
  static const String _legacyKeyAccessToken = 'cached_access_token';
  static const String _legacyKeyRefreshToken = 'cached_refresh_token';
  static const String _legacyKeyTokenExpiry = 'cached_token_expiry';
  static const String _legacyKeyLastOnlineLogin = 'last_online_login';

  // ── Global keys ─────────────────────────────────────────────────────────────
  /// Most-recently-used email — used only to pre-fill the login field.
  static const String _keyLastCachedEmail = 'last_cached_email';

  // v10: default cipher is AES-GCM (was CBC in v9 — fixes MobSF HIGH finding).
  // migrateOnAlgorithmChange: true re-encrypts existing data on first access.
  // resetOnError: false keeps explicit control (v10 changed default to true).
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(migrateOnAlgorithmChange: true, resetOnError: false),
  );

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Build a per-user storage key.
  /// Sanitises the email so it is safe to embed in a key string.
  static String _userKey(String email, String field) {
    final sanitized = email.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return 'user_${sanitized}_$field';
  }

  /// One-time migration: if legacy single-user keys exist, move them to the
  /// per-user format and remove the old keys.
  bool _migrationDone = false;
  Future<void> _migrateIfNeeded() async {
    if (_migrationDone) return;
    _migrationDone = true;

    final legacyEmail = await _storage.read(key: _legacyKeyEmail);
    if (legacyEmail == null) return;


    final fields = {
      _legacyKeyPassword: 'password',
      _legacyKeyUserId: 'user_id',
      _legacyKeyAccessToken: 'access_token',
      _legacyKeyRefreshToken: 'refresh_token',
      _legacyKeyTokenExpiry: 'token_expiry',
      _legacyKeyLastOnlineLogin: 'last_online_login',
    };

    for (final entry in fields.entries) {
      final value = await _storage.read(key: entry.key);
      if (value != null) {
        await _storage.write(key: _userKey(legacyEmail, entry.value), value: value);
        await _storage.delete(key: entry.key);
      }
    }

    await _storage.write(key: _keyLastCachedEmail, value: legacyEmail);
    await _storage.delete(key: _legacyKeyEmail);
  }

  // ── Public API ───────────────────────────────────────────────────────────────

  /// Store user credentials securely after a successful online login.
  Future<void> cacheCredentials({
    required String email,
    required String password,
    required String userId,
    String? accessToken,
    String? refreshToken,
    DateTime? tokenExpiry,
  }) async {
    await _migrateIfNeeded();
    try {
      await _storage.write(key: _userKey(email, 'password'), value: password);
      await _storage.write(key: _userKey(email, 'user_id'), value: userId);
      if (accessToken != null) {
        await _storage.write(key: _userKey(email, 'access_token'), value: accessToken);
      }
      if (refreshToken != null) {
        await _storage.write(key: _userKey(email, 'refresh_token'), value: refreshToken);
      }
      if (tokenExpiry != null) {
        await _storage.write(
          key: _userKey(email, 'token_expiry'),
          value: tokenExpiry.toIso8601String(),
        );
      }
      await _storage.write(
        key: _userKey(email, 'last_online_login'),
        value: DateTime.now().toIso8601String(),
      );
      // Track the most recently used email for pre-filling the login field.
      await _storage.write(key: _keyLastCachedEmail, value: email);
    } catch (e) {
      rethrow;
    }
  }

  /// Most-recently-used email (for pre-filling the login field).
  Future<String?> getCachedEmail() async {
    await _migrateIfNeeded();
    try {
      return await _storage.read(key: _keyLastCachedEmail);
    } catch (e) {
      return null;
    }
  }

  /// Cached user ID for [email].
  Future<String?> getCachedUserId(String email) async {
    try {
      return await _storage.read(key: _userKey(email, 'user_id'));
    } catch (e) {
      return null;
    }
  }

  /// Cached access token for [email].
  Future<String?> getCachedAccessToken(String email) async {
    try {
      return await _storage.read(key: _userKey(email, 'access_token'));
    } catch (e) {
      return null;
    }
  }

  /// Cached refresh token for [email].
  Future<String?> getCachedRefreshToken(String email) async {
    try {
      return await _storage.read(key: _userKey(email, 'refresh_token'));
    } catch (e) {
      return null;
    }
  }

  /// Timestamp of last online login for [email].
  Future<DateTime?> getLastOnlineLogin(String email) async {
    try {
      final dateStr = await _storage.read(key: _userKey(email, 'last_online_login'));
      if (dateStr != null) return DateTime.tryParse(dateStr);
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Whether credentials are cached for [email].
  Future<bool> hasCredentials(String email) async {
    await _migrateIfNeeded();
    try {
      final password = await _storage.read(key: _userKey(email, 'password'));
      return password != null;
    } catch (e) {
      return false;
    }
  }

  /// Whether ANY user has cached credentials on this device.
  Future<bool> hasAnyCredentials() async {
    await _migrateIfNeeded();
    try {
      final lastEmail = await _storage.read(key: _keyLastCachedEmail);
      if (lastEmail == null) return false;
      return hasCredentials(lastEmail);
    } catch (e) {
      return false;
    }
  }

  /// Return the cached plaintext password for [email], or null if not stored.
  Future<String?> getCachedPassword(String email) async {
    await _migrateIfNeeded();
    try {
      return await _storage.read(key: _userKey(email, 'password'));
    } catch (e) {
      return null;
    }
  }

  /// Validate offline credentials for [email].
  Future<bool> validateOfflineCredentials(String email, String password) async {
    await _migrateIfNeeded();
    try {
      final cachedPassword = await _storage.read(key: _userKey(email, 'password'));
      if (cachedPassword == null) return false;
      return cachedPassword == password;
    } catch (e) {
      return false;
    }
  }

  /// Whether offline login is still permitted for [email] (not expired).
  Future<bool> isOfflineLoginAllowed(String email, {int maxDaysOffline = 30}) async {
    try {
      final lastOnlineLogin = await getLastOnlineLogin(email);
      if (lastOnlineLogin == null) return false;
      final daysSinceLastOnline = DateTime.now().difference(lastOnlineLogin).inDays;
      return daysSinceLastOnline <= maxDaysOffline;
    } catch (e) {
      return false;
    }
  }

  /// Clear cached credentials for [email] only.
  Future<void> clearCredentials(String email) async {
    try {
      for (final field in [
        'password',
        'user_id',
        'access_token',
        'refresh_token',
        'token_expiry',
        'last_online_login',
      ]) {
        await _storage.delete(key: _userKey(email, field));
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Clear all secure storage (use with caution).
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      rethrow;
    }
  }

  /// Update stored tokens after a successful token refresh for [email].
  Future<void> updateTokens({
    required String email,
    required String accessToken,
    required String refreshToken,
    DateTime? tokenExpiry,
  }) async {
    try {
      await _storage.write(key: _userKey(email, 'access_token'), value: accessToken);
      await _storage.write(key: _userKey(email, 'refresh_token'), value: refreshToken);
      if (tokenExpiry != null) {
        await _storage.write(
          key: _userKey(email, 'token_expiry'),
          value: tokenExpiry.toIso8601String(),
        );
      }
      await _storage.write(
        key: _userKey(email, 'last_online_login'),
        value: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      rethrow;
    }
  }
}
