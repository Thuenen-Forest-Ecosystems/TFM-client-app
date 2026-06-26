import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// App-wide single owner of the `connectivity_plus` platform subscription.
///
/// Previously 6+ widgets/providers each opened their own
/// `onConnectivityChanged` listener. On Windows every listener spins up its own
/// native network-adapter poll (the source of the DLL-stability note in
/// pubspec) — wasteful CPU/energy and a stability risk. This funnels them all
/// through one underlying subscription and re-broadcasts a single online/offline
/// bool, so additional consumers cost nothing at the platform layer.
///
/// "Online" == at least one active (non-`none`) transport, matching the
/// semantics every call site used before (`any(r != none)` / `!contains(none)`).
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _isOnline = true;
  bool _initialized = false;

  /// Latest known connectivity. Read this for the initial state; subscribe to
  /// [onStatusChanged] for subsequent changes.
  bool get isOnline => _isOnline;

  /// Broadcast of online/offline transitions (`true` == online). Does not
  /// replay the current value to new listeners — read [isOnline] for that.
  Stream<bool> get onStatusChanged => _controller.stream;

  /// Idempotent. Opens the single platform subscription and seeds [isOnline]
  /// from a one-shot `checkConnectivity()`. Call once early in `main()`; other
  /// callers can `await` it safely (later calls are no-ops).
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _sub = Connectivity().onConnectivityChanged.listen(_handle);
    try {
      _handle(await Connectivity().checkConnectivity());
    } catch (_) {
      // Windows can throw before the platform channel is ready; the stream
      // subscription will still deliver the first real change.
    }
  }

  /// Convenience for one-shot callers: ensures the service is initialized and
  /// returns the current online state.
  Future<bool> checkOnline() async {
    await initialize();
    return _isOnline;
  }

  void _handle(List<ConnectivityResult> results) {
    final next = results.any((r) => r != ConnectivityResult.none);
    if (next == _isOnline) return;
    _isOnline = next;
    if (!_controller.isClosed) _controller.add(next);
  }

  /// Tears down the platform subscription. Not normally called (app-lifetime
  /// singleton); present for completeness/tests.
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _initialized = false;
    await _controller.close();
  }
}
