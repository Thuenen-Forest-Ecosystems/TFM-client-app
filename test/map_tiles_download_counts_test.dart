import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:terrestrial_forest_monitor/services/map_tiles_download_runner.dart';

/// Stored-tile counts must follow the records assigned to the device, not a
/// count stored for an earlier assignment (swapped records used to show
/// "Vollständig" although their tiles were never downloaded).
void main() {
  // Records ~1 km apart, so their DOP areas don't share tiles. Records >= 100
  // are records 0.. moved east by exactly three zoom-15 tiles: same position
  // relative to the tile grid at zoom 15 and 19, hence the same tile count.
  const tileShift = 3 * 360 / (1 << 15);
  Map<String, double> record(int i) => {
    'latitude': 51.0 + (i % 100) * 0.01,
    'longitude': 10.5 + (i >= 100 ? tileShift : 0),
  };
  List<List<double>> dopSteps(Iterable<int> records) =>
      regionsForBasemap('DOP', records.map(record));

  /// Marks all steps of [records] as completely downloaded.
  Future<void> download(Iterable<int> records) =>
      saveCompletedSteps('DOP', dopSteps(records).map(stepKey).toSet());

  setUp(() {
    dotenv.testLoad(fileInput: 'DMZ_KEY=test');
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
  });

  test('all assigned records downloaded: complete', () async {
    await download(range(0, 10));
    final steps = dopSteps(range(0, 10));
    expect(await countStoredTiles('DOP', steps), countBasemapTiles(steps));
  });

  test('records swapped, same total: only the kept ones count', () async {
    await download(range(0, 10));
    final kept = dopSteps(range(0, 5));
    final swapped = dopSteps([...range(0, 5), ...range(105, 110)]);
    expect(countBasemapTiles(swapped), countBasemapTiles(dopSteps(range(0, 10))));
    expect(await countStoredTiles('DOP', swapped), countBasemapTiles(kept));
  });

  test('fewer records, one of them new: not complete', () async {
    await download(range(0, 10));
    final steps = dopSteps([...range(0, 3), 130]);
    expect(await countStoredTiles('DOP', steps), countBasemapTiles(dopSteps(range(0, 3))));
    expect(await countStoredTiles('DOP', steps), lessThan(countBasemapTiles(steps)));
  });

  test('records removed only: still complete', () async {
    await download(range(0, 10));
    final steps = dopSteps(range(0, 4));
    expect(await countStoredTiles('DOP', steps), countBasemapTiles(steps));
  });

  test('more records: the new ones are missing', () async {
    await download(range(0, 10));
    final steps = dopSteps(range(0, 15));
    expect(await countStoredTiles('DOP', steps), countBasemapTiles(dopSteps(range(0, 10))));
  });

  group('before any step was recorded (first run after the update)', () {
    test('stored count for the same total is used', () async {
      final steps = dopSteps(range(0, 10));
      await saveTileCount('DOP', (done: 123, total: countBasemapTiles(steps)));
      expect(await countStoredTiles('DOP', steps), 123);
    });

    test('stored count for a different total is ignored', () async {
      await saveTileCount('DOP', (done: 123, total: 999999));
      expect(await countStoredTiles('DOP', dopSteps(range(0, 10))), 0);
    });
  });
}

Iterable<int> range(int from, int to) => [for (var i = from; i < to; i++) i];
