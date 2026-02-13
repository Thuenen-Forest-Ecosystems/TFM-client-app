# GPS Quality Criteria Configuration

## Overview

The app uses configurable quality criteria to assess GPS measurement quality in real-time and after position aggregation.

## Quality Levels

Three quality levels are defined:

- **Good** (Gut) - Green indicator ✓
- **OK** (Akzeptabel) - Orange indicator ⚠
- **Not Acceptable** (Nicht akzeptabel) - Red indicator ✗

## Evaluated Parameters

### HDOP (Horizontal Dilution of Precision)

**Lower is better**

- Measures geometric quality of GPS satellite configuration for horizontal positioning
- Default thresholds:
  - Good: ≤ 2.0
  - OK: ≤ 5.0
  - Not Acceptable: > 5.0

### PDOP (Position Dilution of Precision)

**Lower is better**

- Measures overall geometric quality including vertical positioning
- Default thresholds:
  - Good: ≤ 3.0
  - OK: ≤ 6.0
  - Not Acceptable: > 6.0

### Satellite Count

**Higher is better**

- Number of satellites used in position fix
- Default thresholds:
  - Good: ≥ 9 satellites
  - OK: ≥ 6 satellites
  - Not Acceptable: < 6 satellites

### Accuracy (meters)

**Lower is better**

- Estimated horizontal accuracy in meters
- Default thresholds:
  - Good: ≤ 3.0 m
  - OK: ≤ 10.0 m
  - Not Acceptable: > 10.0 m

## How Quality is Evaluated

The system evaluates all four parameters and assigns the **worst quality level** found across any parameter. For example:

- If HDOP is "Good" but Satellites is "OK", overall quality = "OK"
- If any parameter is "Not Acceptable", overall quality = "Not Acceptable"

## Configuration

### Default Configuration Location

`lib/models/gps_quality_criteria.dart` - Contains hardcoded default values

### JSON Configuration (for admins)

Edit the file: `assets/gps_quality_criteria.json`

```json
{
  "name": "Custom Forestry Criteria",
  "hdop": {
    "good": 2.0,
    "ok": 5.0,
    "notAcceptable": 10.0
  },
  "pdop": {
    "good": 3.0,
    "ok": 6.0,
    "notAcceptable": 10.0
  },
  "satellites": {
    "good": 9,
    "ok": 6,
    "notAcceptable": 4
  },
  "accuracy": {
    "good": 3.0,
    "ok": 10.0,
    "notAcceptable": 20.0
  }
}
```

### To Enable JSON Loading

Uncomment the code in `record-position.dart`:

```dart
final String jsonString = await rootBundle.loadString('assets/gps_quality_criteria.json');
_qualityCriteria = GpsQualityCriteria.fromJsonString(jsonString);
```

And add to `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/gps_quality_criteria.json
```

### To Modify Hardcoded Defaults

Edit `lib/models/gps_quality_criteria.dart`:

```dart
static GpsQualityCriteria get defaultCriteria => GpsQualityCriteria(
  name: 'Default Forestry Criteria',
  hdop: HdopCriteria(
    good: 2.0,    // Change these values
    ok: 5.0,
    notAcceptable: 10.0,
  ),
  // ... etc
);
```

## User Experience

### During Measurement

- Real-time quality indicator shows current GPS quality
- Color-coded border around quality status
- Individual parameter quality chips (HDOP, PDOP, satellites, accuracy)
- Warning colors guide user to wait for better GPS conditions

### After Measurement

- Aggregated data shows overall quality assessment
- Quality badge next to aggregated data header
- Detailed quality breakdown stored in measurement data

## Recommended Values by Use Case

### High Precision Forestry (RTK GPS)

```json
{
  "hdop": { "good": 1.0, "ok": 2.0, "notAcceptable": 3.0 },
  "pdop": { "good": 2.0, "ok": 3.0, "notAcceptable": 5.0 },
  "satellites": { "good": 12, "ok": 9, "notAcceptable": 6 },
  "accuracy": { "good": 1.0, "ok": 3.0, "notAcceptable": 5.0 }
}
```

### Standard Forestry (Consumer GPS)

```json
{
  "hdop": { "good": 2.0, "ok": 5.0, "notAcceptable": 10.0 },
  "pdop": { "good": 3.0, "ok": 6.0, "notAcceptable": 10.0 },
  "satellites": { "good": 9, "ok": 6, "notAcceptable": 4 },
  "accuracy": { "good": 3.0, "ok": 10.0, "notAcceptable": 20.0 }
}
```

### Relaxed (Forest Canopy)

```json
{
  "hdop": { "good": 5.0, "ok": 10.0, "notAcceptable": 15.0 },
  "pdop": { "good": 6.0, "ok": 10.0, "notAcceptable": 15.0 },
  "satellites": { "good": 6, "ok": 4, "notAcceptable": 3 },
  "accuracy": { "good": 10.0, "ok": 20.0, "notAcceptable": 30.0 }
}
```

## Implementation Details

### Data Stored in Measurement

Each completed measurement includes:

- `overall_quality`: "good", "ok", or "notAcceptable"
- `detailed_quality`: Object with quality level for each parameter
- All standard metrics (HDOP, PDOP, satellites, accuracy)

### Quality Check Workflow

1. User opens position recording widget
2. Current GPS quality displayed in real-time
3. User sees if conditions are "good", "ok", or "not acceptable"
4. Recording proceeds with continuous quality monitoring
5. Quality warnings appear if conditions degrade during recording
6. Final aggregated measurement includes quality assessment
7. Form data saved with quality metadata

## Troubleshooting

### All measurements show "Not Acceptable"

- Check if criteria thresholds are too strict for your GPS hardware
- Verify GPS device is getting clear sky view
- Consider relaxing criteria for forest canopy conditions

### No quality indicator shown

- Ensure GPS device is connected and providing NMEA data
- Check that HDOP/PDOP values are being parsed from NMEA sentences
- Verify GpsPositionProvider is streaming position updates

## Future Enhancements

- Settings UI for admins to adjust criteria without code editing
- Multiple preset configurations (High Precision, Standard, Relaxed)
- Export/Import criteria configurations
- Historical quality tracking and analytics
