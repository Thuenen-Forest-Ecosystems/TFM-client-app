import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Wrap any subtree that needs to react to network changes.
///
/// Descendants can read the latest online state via `NetworkWrapper.of(context)`.
class NetworkWrapper extends StatefulWidget {
  final Widget child;
  final Widget offlineChild;
  final ValueChanged<bool>? onStatusChanged;

  const NetworkWrapper({super.key, required this.child, required this.offlineChild, this.onStatusChanged});

  /// Helper to access the current offline flag from any descendant.
  static bool of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_NetworkStatusScope>();
    if (scope == null) {
      throw FlutterError('NetworkWrapper.of() called outside of NetworkWrapper tree');
    }
    return scope.isOffline;
  }

  @override
  State<NetworkWrapper> createState() => _NetworkWrapperState();
}

class _NetworkWrapperState extends State<NetworkWrapper> {
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _isOffline = true;

  @override
  void initState() {
    super.initState();
    _subscription = Connectivity().onConnectivityChanged.listen(_handleConnectivityChange);
    _initializeStatus();
  }

  Future<void> _initializeStatus() async {
    final results = await Connectivity().checkConnectivity();
    _handleConnectivityChange(results);
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final nextOffline = results.contains(ConnectivityResult.none);
    if (!mounted || nextOffline == _isOffline) {
      return;
    }

    setState(() {
      _isOffline = nextOffline;
    });

    widget.onStatusChanged?.call(_isOffline);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeChild = _isOffline ? widget.offlineChild : widget.child;
    return _NetworkStatusScope(isOffline: _isOffline, child: activeChild);
  }
}

class _NetworkStatusScope extends InheritedWidget {
  final bool isOffline;

  const _NetworkStatusScope({required this.isOffline, required super.child});

  @override
  bool updateShouldNotify(_NetworkStatusScope oldWidget) => isOffline != oldWidget.isOffline;
}
