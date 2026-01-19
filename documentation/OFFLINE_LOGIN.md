# Offline Login Implementation

## Overview

The TFM (Terrestrial Forest Monitor) app now supports offline-first authentication, allowing users to log in and use the app without an internet connection after their initial online login.

## Features

### ✅ Implemented Features

1. **Secure Credential Storage**

   - User credentials are encrypted and stored locally using `flutter_secure_storage`
   - Credentials are automatically cached after successful online login
   - Compatible with Android, iOS, Windows, and macOS

2. **Offline Login**

   - Separate "Offline Anmelden" button appears when device is offline
   - Validates credentials against cached data
   - Supports 30-day offline period before requiring online login
   - Auto-fills email from cached credentials

3. **Network Detection**

   - Automatic connectivity monitoring
   - Dynamic UI updates based on connection status
   - Clear visual indicators for offline mode

4. **PowerSync Integration**
   - Local SQLite database remains accessible in offline mode
   - Data sync resumes automatically when connection returns
   - Offline changes are queued and uploaded when online

## Architecture

### New Services

#### 1. `SecureStorageService` (`lib/services/secure_storage_service.dart`)

Handles encrypted storage of user credentials:

- Email, password, user ID
- Access and refresh tokens
- Token expiry timestamps
- Last online login date

**Key Methods:**

- `cacheCredentials()` - Store credentials after online login
- `validateOfflineCredentials()` - Verify credentials for offline login
- `isOfflineLoginAllowed()` - Check if offline period hasn't expired
- `clearCredentials()` - Remove stored credentials on logout

#### 2. `OfflineAuthService` (`lib/services/offline_auth_service.dart`)

Manages offline authentication logic:

- Connectivity checking
- Offline login validation
- Credential lifecycle management

**Key Methods:**

- `loginOffline()` - Perform offline authentication
- `saveOnlineLoginCredentials()` - Cache credentials after online login
- `hasPreviousLogin()` - Check if user has logged in before
- `getCachedEmail()` - Retrieve cached email for UI

### Updated Components

#### 1. `AuthProvider` (`lib/providers/auth.dart`)

Enhanced with offline support:

- New `loginOffline()` method for offline authentication
- `isOfflineMode` flag to track authentication state
- Automatic credential caching on successful online login
- Helper methods: `hasPreviousLogin()`, `getCachedEmail()`, `getLastOnlineLogin()`

#### 2. `Login Screen` (`lib/screens/login.dart`)

Updated UI with offline capabilities:

- Connectivity monitoring
- Dynamic button display based on network status
- Separate offline login button (orange styling)
- Info messages for offline users without cached credentials

## User Flow

### First-Time User

1. User opens app (must be online)
2. Enters email and password
3. Clicks "Anmelden" (online login)
4. Credentials are validated with Supabase
5. Credentials are automatically cached for offline use
6. User is authenticated and can use the app

### Returning User (Online)

1. User opens app (online)
2. Email auto-fills from cache
3. Enters password
4. Clicks "Anmelden"
5. Credentials validated with Supabase
6. Cache is updated with new tokens
7. User is authenticated

### Returning User (Offline)

1. User opens app (offline)
2. Email auto-fills from cache
3. Enters password
4. "Offline Anmelden" button appears (orange)
5. Clicks "Offline Anmelden"
6. Credentials validated against cached data
7. User is authenticated in offline mode
8. Local PowerSync database is accessible
9. Changes are queued for sync when online

## Security Considerations

### Encryption

- `flutter_secure_storage` uses platform-specific secure storage:
  - **Android**: EncryptedSharedPreferences
  - **iOS**: Keychain
  - **Windows**: Credential Manager
  - **macOS**: Keychain

### Offline Period Limit

- Default: 30 days since last online login
- Configurable in `SecureStorageService.isOfflineLoginAllowed()`
- After expiry, user must log in online to continue

### Token Management

- Access tokens stored but not used in offline mode
- Tokens refreshed on next online login
- Credentials cleared completely on logout

## Configuration

### Adjust Offline Period

In `lib/services/secure_storage_service.dart`:

```dart
Future<bool> isOfflineLoginAllowed({int maxDaysOffline = 30})
```

Change `maxDaysOffline` parameter (default: 30 days)

### Customize Error Messages

Error messages are in German. Update in:

- `lib/services/offline_auth_service.dart`
- `lib/screens/login.dart`

## Testing

### Test Online Login

1. Ensure device is online
2. Enter valid credentials
3. Verify successful login
4. Check console for "Credentials saved for offline use"

### Test Offline Login

1. Log out
2. Disable internet connection
3. Open app
4. Verify "Offline Anmelden" button appears
5. Enter same credentials
6. Verify successful offline login

### Test First-Time Offline

1. Clear app data/reinstall
2. Disable internet
3. Open app
4. Verify message: "Bitte stellen Sie eine Internetverbindung her..."

### Test Expired Offline Period

1. Modify cached `last_online_login` timestamp (debug only)
2. Set to >30 days ago
3. Attempt offline login
4. Verify error: "Offline-Anmeldung abgelaufen"

## Dependencies

```yaml
flutter_secure_storage: ^4.2.1 # For encrypted credential storage
connectivity_plus: ^6.0.5 # For network detection
local_auth: ^2.3.0 # Optional: for biometric auth (future)
```

## Known Limitations

1. **Web Platform**: flutter_secure_storage has limited support on web
2. **Biometric Auth**: Not yet implemented (infrastructure in place)
3. **Multi-Account**: Only one account can be cached per device
4. **Token Refresh**: Offline mode doesn't refresh expired tokens

## Future Enhancements

- [ ] Biometric authentication (fingerprint/Face ID)
- [ ] Multiple account support
- [ ] Configurable offline period per user
- [ ] Background token refresh when online
- [ ] Offline login analytics

## Troubleshooting

### Issue: "Keine zwischengespeicherten Anmeldedaten gefunden"

**Solution**: User must log in online at least once before offline login works

### Issue: Offline button not appearing when offline

**Solution**: Check connectivity permission in AndroidManifest.xml/Info.plist

### Issue: Credentials not persisting after app restart

**Solution**: Verify flutter_secure_storage is properly installed for your platform

### Issue: "Offline-Anmeldung abgelaufen"

**Solution**: User must log in online to refresh the 30-day offline period

## Support

For issues or questions, contact the development team or check:

- Main documentation: `/TFM-Documentation`
- Supabase docs: https://supabase.io/docs
- PowerSync docs: https://docs.powersync.com
