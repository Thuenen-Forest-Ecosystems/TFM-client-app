# GNSS Satellite Data Support

This implementation provides access to detailed GPS/GNSS satellite information on Android and Windows platforms.

## Features

### Android 📱

- **Real satellite count** - Actual number of satellites in use
- **Constellation information** - GPS, GLONASS, Galileo, BeiDou, etc.
- **Signal strength (CN0)** - Carrier-to-noise density for each satellite
- **Estimated HDOP/PDOP** - Calculated from satellite geometry
- **Satellite elevation/azimuth** - Position of each satellite in the sky

### Windows 💻

- **Full NMEA data** - Via USB serial GPS devices
- All standard NMEA metrics including PDOP, HDOP, VDOP, satellite count

## How It Works

### Platform-Specific Implementation

#### Android

Uses native Android GNSS API via method channels:

1. **GnssService** (Dart) - Flutter service that communicates with native Android
2. **GnssChannelHandler** (Kotlin) - Native Android handler using `GnssStatus` API
3. **MainActivity** - Registers the method and event channels

#### Windows

Uses existing `flutter_libserialport` for USB GPS devices:

- `processSerialPortData()` method already parses NMEA sentences
- Provides full GNSS metrics directly from device

### Data Flow

```
┌─────────────────┐
│  External GPS   │──► Full NMEA data (all platforms)
│  (Bluetooth)    │    ✓ Satellites, PDOP, HDOP, VDOP
└─────────────────┘

┌─────────────────┐
│  Internal GPS   │
│   (Android)     │──► Geolocator (lat/lon/accuracy)
└─────────────────┘    +
                       GNSS API (satellites/signal strength)
                       = Combined enhanced data

┌─────────────────┐
│  USB GPS        │──► Full NMEA data via serial port
│  (Windows)      │    ✓ Satellites, PDOP, HDOP, VDOP
└─────────────────┘
```

## Available Data by Source

| Metric        | External BT GPS | Android Internal | Windows USB | iOS Internal |
| ------------- | :-------------: | :--------------: | :---------: | :----------: |
| Latitude      |       ✅        |        ✅        |     ✅      |      ✅      |
| Longitude     |       ✅        |        ✅        |     ✅      |      ✅      |
| Altitude      |       ✅        |        ✅        |     ✅      |      ✅      |
| Heading       |       ✅        |        ✅        |     ✅      |      ✅      |
| Speed         |       ✅        |        ✅        |     ✅      |      ✅      |
| Satellites    |       ✅        |        ✅        |     ✅      |      ❌      |
| HDOP          |       ✅        | ~✅ (estimated)  |     ✅      |      ❌      |
| PDOP          |       ✅        | ~✅ (estimated)  |     ✅      |      ❌      |
| VDOP          |       ✅        |        ❌        |     ✅      |      ❌      |
| Fix Quality   |       ✅        |       ~✅        |     ✅      |      ❌      |
| Constellation |       ✅        |        ✅        |     ✅      |      ❌      |

✅ = Available  
~✅ = Estimated from available data  
❌ = Not available (platform limitation)

## Requirements

### Android

- **Minimum API Level**: Android 7.0 (API 24) - for GnssStatus API
- **Permissions**: `ACCESS_FINE_LOCATION` (already required)
- No additional dependencies

### Windows

- **Package**: `flutter_libserialport` (already in pubspec.yaml)
- USB GPS device connected via serial port
- No additional dependencies

## Usage in Code

The GNSS data is automatically integrated into the `CurrentNMEA` object when using internal GPS:

```dart
final gpsProvider = context.watch<GpsPositionProvider>();
final nmea = gpsProvider.currentNMEA;

// Access satellite data (available on Android internal GPS and all external GPS)
print('Satellites in use: ${nmea?.satellites ?? "N/A"}');
print('HDOP: ${nmea?.hdop?.toStringAsFixed(1) ?? "N/A"}');
print('PDOP: ${nmea?.pdop?.toStringAsFixed(1) ?? "N/A"}');
```

## Testing

### Android

1. Enable developer options and "Mock locations" on your device
2. Or use actual device GPS outdoors with clear sky view
3. Check logcat for GNSS status messages
4. Satellite data should appear in the UI when using internal GPS

### Windows

1. Connect USB GPS device
2. Device should output NMEA sentences via serial port
3. Satellite data parsed from NMEA is displayed

## Limitations

### iOS

Apple's CoreLocation framework **does not expose**:

- Satellite count
- PDOP, HDOP, VDOP values
- Individual satellite information
- Fix quality indicators

iOS only provides horizontal/vertical accuracy values. This is a platform limitation, not a Flutter issue.

### Accuracy Notes

#### Android HDOP/PDOP Estimation

The Android GnssStatus API provides satellite count and signal strength but **not** actual DOP values. We estimate HDOP based on:

- Number of satellites used in fix
- Typical DOP values for satellite counts
- This is an approximation, not as accurate as real NMEA DOP values

For highest accuracy, use external Bluetooth GPS devices which provide true NMEA DOP values.

## Files Modified/Created

### New Files

- `lib/services/gnss_service.dart` - Dart service for GNSS communication
- `android/.../GnssChannelHandler.kt` - Kotlin native GNSS handler

### Modified Files

- `lib/providers/gps-position.dart` - Integrated GNSS service
- `android/.../MainActivity.kt` - Registered GNSS channels

## Troubleshooting

### Android: No satellite data appearing

1. Check location permissions are granted
2. Ensure GPS is enabled in device settings
3. Go outdoors or near window for better satellite visibility
4. Check Android version (requires API 24+)
5. Look for errors in logcat: `adb logcat | grep -i gnss`

### Windows: USB GPS not working

1. Check device is connected and recognized by Windows
2. Verify correct COM port in device manager
3. Ensure no other app is using the serial port
4. Check NMEA output with a serial terminal first

## Future Enhancements

Possible improvements:

- Sky plot showing satellite positions
- Signal strength indicators per satellite
- Constellation filtering (GPS only, multi-GNSS, etc.)
- DOP quality indicators with color coding
- Historical DOP graphs
