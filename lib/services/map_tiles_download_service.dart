import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrestrial_forest_monitor/services/log_service.dart';
import 'package:terrestrial_forest_monitor/services/map_tiles_download_runner.dart';

// Shared between the UI isolate and the foreground-service isolate. Both run in
// the same process but different engines, so state goes through
// SharedPreferencesAsync (no in-memory cache) and the task data port.
const _jobKey = 'map_tiles_download_job';
const _stateKey = 'map_tiles_download_state';

/// Notice for a run that stopped before finishing; restarting resumes it.
const mapTilesInterruptedNotice = 'Download unterbrochen';

typedef MapTilesDownloadMessage = ({String text, bool important});

enum MapTilesDownloadPhase { running, done, cancelled, failed, interrupted }

/// Owns the offline basemap download independent of any widget, so it keeps
/// running while the user navigates away.
///
/// On Android the download runs inside a foreground service (own engine): it
/// survives the app being backgrounded or swiped away, and shows its progress
/// as a notification. Elsewhere (Windows) it runs in-process; a minimised
/// desktop app keeps running anyway.
class MapTilesDownloadController extends ChangeNotifier {
  MapTilesDownloadController._();
  static final MapTilesDownloadController instance = MapTilesDownloadController._();

  String? activeBasemap;

  /// Downloaded/total tiles per basemap: live for the active download, else
  /// the stored state of the last run against the current records.
  final Map<String, TileCount> counts = {};

  /// Per-basemap hint left behind by a run that ended without the UI watching
  /// (e.g. interrupted by the system).
  final Map<String, String> notices = {};

  /// Why the active download's count stands still, if it does.
  String? statusText;

  final StreamController<MapTilesDownloadMessage> _messages =
      StreamController<MapTilesDownloadMessage>.broadcast();

  /// User-facing messages for snackbars. [MapTilesDownloadMessage.important]
  /// ones (warnings, failures) should stay until dismissed.
  Stream<MapTilesDownloadMessage> get messages => _messages.stream;

  void _info(String text) => _messages.add((text: text, important: false));

  void _warn(String text) {
    LogService().log(text, level: LogLevel.warning);
    _messages.add((text: text, important: true));
  }

  MapTilesDownloadRunner? _localRunner;
  bool _attached = false;
  Map<String, List<List<double>>> _regions = {};

  bool get _useForegroundService => !kIsWeb && Platform.isAndroid;

  /// Sets the download steps for the current records (see
  /// [regionsForBasemap]) and derives total and stored tiles from them.
  Future<void> loadCounts(Map<String, List<List<double>>> regions) async {
    _regions = regions;
    for (final basemap in regions.keys) {
      if (basemap == activeBasemap) continue;
      await _reloadCount(basemap, notify: false);
    }
    notifyListeners();
  }

  Future<void> _reloadCount(String basemapName, {bool notify = true}) async {
    final regions = _regions[basemapName];
    if (regions == null) return;
    counts[basemapName] = (
      done: await countStoredTiles(basemapName, regions),
      total: countBasemapTiles(regions),
    );
    if (notify) notifyListeners();
  }

  /// Restores the state of a download that may still be running in the
  /// service (or ended while the app was closed). Safe to call repeatedly.
  Future<void> attach() async {
    if (!_useForegroundService) return;
    if (!_attached) {
      _attached = true;
      FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    }

    final state = await _readState();
    if (state == null) return;
    final basemap = state['basemap'] as String;
    final phase = MapTilesDownloadPhase.values.byName(state['phase'] as String);
    final serviceRunning = await FlutterForegroundTask.isRunningService;

    if (phase == MapTilesDownloadPhase.running && serviceRunning) {
      activeBasemap = basemap;
      counts[basemap] = (done: state['done'] as int, total: state['total'] as int);
    } else {
      // The run is over; surface its outcome once.
      activeBasemap = null;
      unawaited(_reloadCount(basemap));
      switch (phase) {
        case MapTilesDownloadPhase.done:
          break;
        case MapTilesDownloadPhase.running:
        case MapTilesDownloadPhase.interrupted:
          notices[basemap] = mapTilesInterruptedNotice;
        case MapTilesDownloadPhase.failed:
          notices[basemap] = state['message'] as String? ?? 'Fehler beim Download';
        case MapTilesDownloadPhase.cancelled:
          break;
      }
      await SharedPreferencesAsync().remove(_stateKey);
    }
    notifyListeners();
  }

  Future<void> start(String basemapName, List<List<double>> regions) async {
    if (activeBasemap != null) return;

    activeBasemap = basemapName;
    statusText = null;
    notices.remove(basemapName);
    notifyListeners();

    if (_useForegroundService) {
      await _startService(basemapName, regions);
    } else {
      await _runInProcess(basemapName, regions);
    }
  }

  Future<void> cancel() async {
    if (activeBasemap == null) return;
    _info('Download wird abgebrochen...');

    if (_useForegroundService) {
      if (await FlutterForegroundTask.isRunningService) {
        FlutterForegroundTask.sendDataToTask('cancel');
      } else {
        _setFinished(activeBasemap!, MapTilesDownloadPhase.cancelled);
      }
    } else {
      await _localRunner?.cancel();
    }
  }

  Future<void> _startService(String basemapName, List<List<double>> regions) async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString(_jobKey, jsonEncode({'basemap': basemapName, 'regions': regions}));
    await _writeState(
      prefs,
      basemapName,
      MapTilesDownloadPhase.running,
      counts[basemapName] ?? (done: 0, total: 0),
    );

    // Asked only here, on the first download, not at app start. Optional: if
    // denied, the service still runs on Android 13+, Android just hides the
    // progress notification.
    if (await FlutterForegroundTask.checkNotificationPermission() !=
        NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'map_tiles_download',
        channelName: 'Kartendownload',
        channelDescription: 'Fortschritt des Offline-Kartendownloads',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
        // Keep downloading when the app is swiped away from recents
        stopWithTask: false,
      ),
    );

    final title = offlineBasemaps()[basemapName]?['title'] ?? basemapName;
    final result = await FlutterForegroundTask.startService(
      serviceId: 4711,
      serviceTypes: [ForegroundServiceTypes.dataSync],
      notificationTitle: '$title wird heruntergeladen',
      notificationText: 'Wird vorbereitet…',
      notificationButtons: [const NotificationButton(id: 'cancel', text: 'Abbrechen')],
      callback: mapTilesDownloadStartCallback,
    );

    if (result is ServiceRequestFailure) {
      // Foreground service refused (e.g. OS restriction): fall back to the app process
      await prefs.remove(_jobKey);
      await prefs.remove(_stateKey);
      await _runInProcess(basemapName, regions);
    }
  }

  Future<void> _runInProcess(String basemapName, List<List<double>> regions) async {
    final runner = _localRunner = MapTilesDownloadRunner(
      basemapName: basemapName,
      regions: regions,
      onProgress: (done, total) {
        counts[basemapName] = (done: done, total: total);
        notifyListeners();
      },
      onWarning: _warn,
      onLog: LogService().log,
      onStatus: (status) {
        statusText = status;
        notifyListeners();
      },
    );
    try {
      final ok = await runner.run();
      _setFinished(basemapName, ok ? MapTilesDownloadPhase.done : MapTilesDownloadPhase.cancelled);
    } catch (e) {
      _setFinished(basemapName, MapTilesDownloadPhase.failed, message: e.toString());
    } finally {
      _localRunner = null;
    }
  }

  void _onTaskData(Object data) {
    if (data is! Map) return;
    switch (data['type']) {
      case 'progress':
        final basemap = activeBasemap = data['basemap'] as String;
        counts[basemap] = (done: data['done'] as int, total: data['total'] as int);
        notifyListeners();
      case 'warning':
        _warn(data['message'] as String);
      case 'log':
        LogService().log(data['message'] as String);
      case 'status':
        statusText = data['text'] as String?;
        notifyListeners();
      case 'finished':
        _setFinished(
          data['basemap'] as String,
          MapTilesDownloadPhase.values.byName(data['phase'] as String),
          message: data['message'] as String?,
        );
        // Outcome has been shown live, don't replay it on next attach()
        unawaited(SharedPreferencesAsync().remove(_stateKey));
    }
  }

  void _setFinished(String basemapName, MapTilesDownloadPhase phase, {String? message}) {
    final title = offlineBasemaps()[basemapName]?['title'] ?? basemapName;
    activeBasemap = null;
    statusText = null;
    unawaited(_reloadCount(basemapName));
    switch (phase) {
      case MapTilesDownloadPhase.done:
        // Ran to the end, but tiles that failed (e.g. server errors) are missing
        final count = counts[basemapName];
        final missing = count == null ? 0 : count.total - count.done;
        if (missing > 0) {
          _warn(
            '$title: ${formatTileCount(missing)} Kacheln konnten nicht geladen werden. '
            '„Fortsetzen“ lädt sie nach.',
          );
        } else {
          _info('$title: Download abgeschlossen');
        }
      case MapTilesDownloadPhase.failed:
        notices[basemapName] = message ?? 'Fehler beim Download';
        _warn('$title: Download abgebrochen – ${message ?? 'unbekannter Fehler'}');
      case MapTilesDownloadPhase.interrupted:
        notices[basemapName] = mapTilesInterruptedNotice;
      case MapTilesDownloadPhase.cancelled:
      case MapTilesDownloadPhase.running:
        break;
    }
    notifyListeners();
  }
}

Future<Map<String, dynamic>?> _readState() async {
  final raw = await SharedPreferencesAsync().getString(_stateKey);
  return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
}

Future<void> _writeState(
  SharedPreferencesAsync prefs,
  String basemap,
  MapTilesDownloadPhase phase,
  TileCount count, {
  String? message,
}) => prefs.setString(
  _stateKey,
  jsonEncode({
    'basemap': basemap,
    'phase': phase.name,
    'done': count.done,
    'total': count.total,
    'message': message,
  }),
);

/// Entry point of the foreground-service engine
@pragma('vm:entry-point')
void mapTilesDownloadStartCallback() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.setTaskHandler(_MapTilesDownloadTaskHandler());
}

class _MapTilesDownloadTaskHandler extends TaskHandler {
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();
  MapTilesDownloadRunner? _runner;
  String? _basemap;
  TileCount _count = (done: 0, total: 0);
  String? _status;
  bool _finished = false;
  bool _cancelRequested = false;
  DateTime _lastReport = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Not awaited: onStart has to return for the service to process events
    // (cancel button, data from the UI) while the download runs.
    unawaited(_run());
  }

  Future<void> _run() async {
    try {
      try {
        await dotenv.load(fileName: '.env');
      } catch (_) {}
      // Attaches to the ObjectBox store if the app engine already opened it
      await FMTCObjectBoxBackend().initialise();

      final raw = await _prefs.getString(_jobKey);
      // No job, or one written by an older app version (basemap no longer
      // offered, steps without zoom level)
      final stale =
          raw == null ||
          () {
            final job = jsonDecode(raw) as Map<String, dynamic>;
            return !offlineBasemaps().containsKey(job['basemap']) ||
                (job['regions'] as List).any((r) => (r as List).length != 5);
          }();
      if (stale) {
        await _prefs.remove(_jobKey);
        _finished = true;
        await FlutterForegroundTask.stopService();
        return;
      }
      final job = jsonDecode(raw) as Map<String, dynamic>;
      final basemap = _basemap = job['basemap'] as String;
      final regions = (job['regions'] as List)
          .map((r) => (r as List).map((v) => (v as num).toDouble()).toList())
          .toList();

      final runner = _runner = MapTilesDownloadRunner(
        basemapName: basemap,
        regions: regions,
        onProgress: _report,
        onWarning: (message) =>
            FlutterForegroundTask.sendDataToMain({'type': 'warning', 'message': message}),
        onLog: (message) =>
            FlutterForegroundTask.sendDataToMain({'type': 'log', 'message': message}),
        onStatus: (status) {
          _status = status;
          FlutterForegroundTask.sendDataToMain({'type': 'status', 'text': status});
          _updateNotification();
        },
      );
      // Cancel pressed while the engine was still initialising
      if (_cancelRequested) await runner.cancel();
      final ok = await runner.run();
      await _finish(ok ? MapTilesDownloadPhase.done : MapTilesDownloadPhase.cancelled);
    } catch (e) {
      await _finish(MapTilesDownloadPhase.failed, message: e.toString());
    }
  }

  void _report(int done, int total) {
    _count = (done: done, total: total);
    FlutterForegroundTask.sendDataToMain({
      'type': 'progress',
      'basemap': _basemap,
      'done': done,
      'total': total,
    });

    // Notification and persisted state are throttled; the UI port is cheap
    final now = DateTime.now();
    if (now.difference(_lastReport) < const Duration(seconds: 2)) return;
    _lastReport = now;
    _updateNotification();
    unawaited(_writeState(_prefs, _basemap!, MapTilesDownloadPhase.running, _count));
  }

  void _updateNotification() {
    final (:done, :total) = _count;
    final percent = total > 0 ? done * 100 ~/ total : 0;
    final counts = '$percent % · ${formatTileCount(done)} / ${formatTileCount(total)} Kacheln';
    FlutterForegroundTask.updateService(
      notificationText: _status == null ? counts : '$counts\n$_status',
    );
  }

  Future<void> _finish(MapTilesDownloadPhase phase, {String? message}) async {
    _finished = true;
    await _prefs.remove(_jobKey);
    if (_basemap != null) {
      await _writeState(_prefs, _basemap!, phase, _count, message: message);
    }
    FlutterForegroundTask.sendDataToMain({
      'type': 'finished',
      'basemap': _basemap,
      'phase': phase.name,
      'message': message,
    });
    await FlutterForegroundTask.stopService();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  void _cancel() {
    _cancelRequested = true;
    unawaited(_runner?.cancel());
  }

  @override
  void onReceiveData(Object data) {
    if (data == 'cancel') _cancel();
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'cancel') _cancel();
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    if (_finished) return;
    // Killed by the system (e.g. Android 15 dataSync limit). The job stays in
    // prefs; restarting the download skips tiles that are already stored.
    await _runner?.cancel();
    if (_basemap != null) {
      await _writeState(_prefs, _basemap!, MapTilesDownloadPhase.interrupted, _count);
    }
  }
}
