import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrestrial_forest_monitor/services/utils.dart';

/// Replay a captured NMEA log file from the field team and print the parsed
/// state after every sentence.  Drop the .txt file from the device into
/// test/fixtures/ and update [logFile] below, then run:
///
///   flutter test test/nmea_replay_test.dart --reporter expanded
///
void main() {
  const logFile = 'test/fixtures/nmea_survey_esa2.txt'; // <-- path to captured log

  test('replays captured NMEA log and checks for valid fix', () {
    final file = File(logFile);
    if (!file.existsSync()) {
      // Skip gracefully if the field log has not been provided yet.
      markTestSkipped('Log file not found: $logFile — drop the file from the field team here.');
      return;
    }

    final lines = file.readAsLinesSync();
    CurrentNMEA? state;
    int sentenceCount = 0;
    int fixCount = 0;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue; // skip comments / blank lines

      state = parseData(line.codeUnits, state);
      sentenceCount++;

      if (state?.latitude != null && state?.longitude != null) {
        fixCount++;
      }
    }

    // Print a summary so you can inspect the results in the test output.
    print('--- NMEA replay summary ---');
    print('Sentences processed : $sentenceCount');
    print('Sentences with fix  : $fixCount');
    print('Final state         : $state');
    print('---------------------------');

    // At least some sentences should have yielded a position.
    expect(
      fixCount,
      greaterThan(0),
      reason:
          'No valid position was parsed from the log file. '
          'Check sentence types and fix quality field.',
    );
    expect(
      state?.hdop,
      isNotNull,
      reason: 'HDOP was never set — GSA/GGA sentences may be missing or malformed.',
    );
  });
}
