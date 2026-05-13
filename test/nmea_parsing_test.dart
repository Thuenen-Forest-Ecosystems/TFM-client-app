import 'package:flutter_test/flutter_test.dart';
import 'package:terrestrial_forest_monitor/services/utils.dart';

/// Realistic NMEA sentences from a SURVEY-ESA2 with NTRIP/RTK active.
///
/// Fix quality codes used below:
///   1 = GPS fix, 2 = DGPS fix, 4 = RTK fixed, 5 = RTK float
///
/// Run with:
///   flutter test test/nmea_parsing_test.dart
void main() {
  // Helper to convert a plain string into the List<int> that parseData expects.
  List<int> bytes(String s) => s.codeUnits;

  group('NMEA checksum stripping', () {
    test('parses VDOP correctly when checksum is present', () {
      // Fields: 0=$GNGSA 1=A 2=3 3-8=SVIDs 9-14=empty(6) 15=PDOP 16=HDOP 17=VDOP
      // 7 commas between last SVID and PDOP = 6 empty fields (slots 9-14)
      const sentence = '\$GNGSA,A,3,05,13,23,29,15,18,,,,,,,1.52,0.86,1.25*15\r\n';
      final result = parseData(bytes(sentence), null);
      expect(result?.vdop, closeTo(1.25, 0.001));
      expect(result?.pdop, closeTo(1.52, 0.001));
      expect(result?.hdop, closeTo(0.86, 0.001));
    });
  });

  group('GGA sentence', () {
    test('parses standard GPS fix (quality=1)', () {
      const sentence = '\$GNGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47\r\n';
      final result = parseData(bytes(sentence), null);
      expect(result?.latitude, isNotNull);
      expect(result?.latitude, closeTo(48.1173, 0.0001));
      expect(result?.longitude, closeTo(11.5167, 0.0001));
      expect(result?.altitude, closeTo(545.4, 0.01));
      expect(result?.satellites, equals(8));
      expect(result?.hdop, closeTo(0.9, 0.01));
      expect(result?.fixQuality, equals('1'));
    });

    test('parses RTK fixed position (quality=4)', () {
      const sentence =
          '\$GNGGA,120000.00,5230.12345,N,01345.67890,E,4,14,0.6,123.4,M,40.0,M,1.0,0000*XX\r\n';
      final result = parseData(bytes(sentence), null);
      expect(result?.fixQuality, equals('4'));
      expect(result?.latitude, isNotNull);
      expect(result?.hdop, closeTo(0.6, 0.01));
    });

    test('ignores GGA with no fix (quality=0)', () {
      const sentence =
          '\$GNGGA,120000.00,0000.00000,N,00000.00000,E,0,00,99.9,0.0,M,0.0,M,,*XX\r\n';
      final result = parseData(bytes(sentence), null);
      expect(result?.latitude, isNull);
      expect(result?.fixQuality, equals('0'));
    });
  });

  group('RMC sentence', () {
    test('parses heading and speed when status is A (active)', () {
      const sentence = '\$GNRMC,120000.00,A,5230.12345,N,01345.67890,E,0.5,045.0,130526,,,A*XX\r\n';
      final result = parseData(bytes(sentence), null);
      expect(result?.heading, closeTo(45.0, 0.1));
      expect(result?.speedKnots, closeTo(0.5, 0.01));
    });

    test('ignores position data when status is V (void)', () {
      const sentence = '\$GNRMC,120000.00,V,0000.00000,N,00000.00000,E,0.0,0.0,130526,,,N*XX\r\n';
      final result = parseData(bytes(sentence), null);
      expect(result?.latitude, isNull);
    });
  });

  group('GSA sentence', () {
    test('parses all three DOP values without checksum corruption', () {
      const sentence = '\$GNGSA,A,3,01,02,03,04,05,06,07,08,09,10,11,12,2.10,1.20,1.70*3F\r\n';
      final result = parseData(bytes(sentence), null);
      expect(result?.pdop, closeTo(2.10, 0.001));
      expect(result?.hdop, closeTo(1.20, 0.001));
      expect(result?.vdop, closeTo(1.70, 0.001));
      expect(result?.fixType, equals(3));
    });

    test('handles GPGSA (single-constellation) prefix', () {
      const sentence = '\$GPGSA,A,3,,,,,,,,,,,,,3.00,2.00,2.20*04\r\n';
      final result = parseData(bytes(sentence), null);
      expect(result?.pdop, closeTo(3.0, 0.001));
      expect(result?.hdop, closeTo(2.0, 0.001));
      expect(result?.vdop, closeTo(2.2, 0.001));
    });
  });

  group('Multiple sentences in one chunk', () {
    test('combines GGA and GSA data from a single chunk', () {
      // GSA: all 12 SVID slots filled → no empty slots between SVIDs and DOPs
      const chunk =
          '\$GNGGA,123519,4807.038,N,01131.000,E,4,12,0.7,312.0,M,46.9,M,,*XX\r\n'
          '\$GNGSA,A,3,01,02,03,04,05,06,07,08,09,10,11,12,1.80,0.70,1.65*XX\r\n'
          '\$GNRMC,123519,A,4807.038,N,01131.000,E,1.2,275.0,130526,,,A*XX\r\n';
      final result = parseData(bytes(chunk), null);
      expect(result?.fixQuality, equals('4'));
      expect(result?.pdop, closeTo(1.80, 0.001));
      expect(result?.hdop, closeTo(0.70, 0.001));
      expect(result?.vdop, closeTo(1.65, 0.001));
      expect(result?.heading, closeTo(275.0, 0.1));
      expect(result?.latitude, isNotNull);
    });
  });

  group('dmsToDecimal', () {
    test('converts latitude DDMM.MMMM correctly', () {
      expect(dmsToDecimal('4807.0380', 'N'), closeTo(48.1173, 0.0001));
      expect(dmsToDecimal('4807.0380', 'S'), closeTo(-48.1173, 0.0001));
    });

    test('converts longitude DDDMM.MMMM correctly', () {
      expect(dmsToDecimal('01131.0000', 'E'), closeTo(11.5167, 0.0001));
      expect(dmsToDecimal('01131.0000', 'W'), closeTo(-11.5167, 0.0001));
    });

    test('returns null for empty input', () {
      expect(dmsToDecimal('', 'N'), isNull);
    });
  });
}
