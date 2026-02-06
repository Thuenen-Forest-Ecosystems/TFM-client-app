# Version 1.0.68 - Windows Semaphore Timeout Fix

## 🔧 Critical Bug Fix: Windows Startup Issue

### Problem

Users on Windows experienced "Das Zeitlimit für die Semaphore wurde erreicht" (Semaphore timeout) error when starting the app, particularly when:

- VPN is active
- Bluetooth is enabled
- Virtual COM ports are present

### Root Cause

The `flutter_libserialport` library was being initialized and scanning COM ports during app startup, causing the main thread to block and trigger a semaphore timeout.

### Solution Implemented

#### 1. Lazy Loading of Serial Port Scanning

- ❌ Before: Serial ports scanned automatically on app start
- ✅ Now: Ports are scanned **only when user opens GPS device menu**

#### 2. Timeout Protection

- All `SerialPort.availablePorts` calls now have **5-second timeout**
- Prevents indefinite hanging on problematic COM ports
- Graceful fallback with error message

#### 3. Delayed Initialization

- Serial port widget initialization delayed by 300-500ms
- Allows app UI to fully load before accessing native libraries
- Reduces startup time and improves reliability

#### 4. Better Error Handling

- Clear error messages for users when serial port scanning fails
- Visual feedback in GPS device menu
- Suggestions for troubleshooting (disable VPN, check COM ports)

### Changes Made

**Files Modified:**

- `lib/widgets/serial-port-gps-icon.dart` - Main serial GPS icon widget
- `lib/widgets/gnss-serial-selection.dart` - GNSS serial port selection
- `lib/widgets/gps-connection-button.dart` - GPS connection button
- `pubspec.yaml` - Version bump to 1.0.68

**New Documentation:**

- `WINDOWS_TROUBLESHOOTING.md` - Comprehensive troubleshooting guide
- Updated `README.md` with link to troubleshooting guide

### User Impact

**Before:**

1. User starts app with VPN enabled
2. App tries to scan COM ports immediately
3. **App hangs** with semaphore timeout
4. User forced to disable Bluetooth or VPN

**After:**

1. User starts app with VPN enabled
2. App starts **immediately** without scanning ports
3. User opens GPS menu (if needed)
4. Port scanning happens **on-demand** with timeout protection
5. If timeout occurs, user gets **clear error message** with suggestions

### Workarounds (if issue persists)

For users who still experience issues:

1. **Temporary VPN Disable** (Recommended)
   - Disable VPN during first app start
   - Re-enable after app is running
   - Only needed for first launch

2. **Check COM Ports**
   - Open Device Manager → Ports (COM & LPT)
   - Disable unused/problematic COM ports

3. **See Troubleshooting Guide**
   - Full guide: `WINDOWS_TROUBLESHOOTING.md`
   - Covers VPN, Bluetooth, Antivirus, and more

### Testing

Tested on:

- ✅ Windows 11 with FortiClient VPN
- ✅ Windows 10 with Bluetooth enabled
- ✅ Windows with virtual COM ports (Arduino IDE)
- ✅ Clean install without VPN

### Migration Notes

No breaking changes. Existing installations will update seamlessly.

### Related Issues

- Fixes: Windows semaphore timeout on startup
- Related: VPN connectivity issues
- Related: Bluetooth interference with COM port scanning

---

**Full Changelog**: v1.0.67...v1.0.68
