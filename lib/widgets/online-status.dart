import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:get_storage/get_storage.dart';
import 'package:terrestrial_forest_monitor/services/api.dart';

class OnlineStatus extends StatefulWidget {
  const OnlineStatus({super.key});

  @override
  State<OnlineStatus> createState() => _OnlineStatusState();
}

class _OnlineStatusState extends State<OnlineStatus> with SingleTickerProviderStateMixin {
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  bool _isOffline = true;
  bool syncInProgress = false;
  late AnimationController _controller;
  Function? disposeListen;

  Map<String, dynamic>? activeUser;

  @override
  initState() {
    super.initState();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      _setOnlineState(result);
    });
    _getConnectifity();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    GetStorage users = GetStorage('Users');
    disposeListen = users.listen(() async {
      _getCurrentUser();
    });
    _getCurrentUser();
  }

  @override
  dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
    disposeListen!();
  }

  _getCurrentUser() async {
    var user = await ApiService().getLoggedInUser();
    setState(() {
      activeUser = user;
    });
  }

  _getConnectifity() async {
    final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());
    _setOnlineState(connectivityResult);
  }

  _setOnlineState(connectivityResult) {
    setState(() {
      _isOffline = connectivityResult.contains(ConnectivityResult.none);
    });
  }

  _syncData() async {
    // sync data
    if (syncInProgress) {
      _syncDataDone();
      return;
    }

    syncInProgress = true;
    _controller.repeat();

    await ApiService().syncData(context).then((value) {
      _syncDataDone();
      //_getAllClusters();
    }).catchError((error) {
      print(error);
      _syncDataDone();
    });
  }

  _syncDataDone() {
    // sync data
    syncInProgress = false;
    _controller.stop();
    print('sync done');
  }

  _getAllClusters() async {
    await ApiService().getAllClusters();
  }

  @override
  Widget build(BuildContext context) {
    if (activeUser == null) {
      return SizedBox();
    } else {
      return IconButton(
        onPressed: _isOffline ? null : _syncData,
        icon: RotationTransition(
          turns: Tween(begin: 1.0, end: 0.0).animate(_controller),
          child: Icon(_isOffline ? Icons.sync_disabled : Icons.sync),
        ),
      );
    }
  }
}
