import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart'
    as classic;
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';

// Combined device class to hold both BLE and Classic devices
class CombinedBluetoothDevice {
  final String id;
  final String name;
  final int? rssi;
  final bool isBLE;
  final ble.BluetoothDevice? bleDevice;
  final classic.BluetoothDevice? classicDevice;

  CombinedBluetoothDevice({
    required this.id,
    required this.name,
    this.rssi,
    required this.isBLE,
    this.bleDevice,
    this.classicDevice,
  });
}

class BluetoothIconCombined extends StatefulWidget {
  const BluetoothIconCombined({super.key});

  @override
  State<BluetoothIconCombined> createState() => _BluetoothIconCombinedState();
}

class _BluetoothIconCombinedState extends State<BluetoothIconCombined> {
  void _showDeviceMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const BluetoothDeviceMenuSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if GPS device is connected via GpsPositionProvider
    final gpsProvider = context.watch<GpsPositionProvider>();
    final hasBLEConnection = gpsProvider.connectedDevice != null;
    final hasClassicConnection = gpsProvider.connectedClassicDevice != null;
    final hasGPSConnection = hasBLEConnection || hasClassicConnection;
    final isGPSConnecting = gpsProvider.isConnecting;
    final nmea = gpsProvider.currentNMEA;
    final isMockGPS = gpsProvider.isMockGpsActive;
    final isReceivingMockData = gpsProvider.isReceivingAndroidMockData;
    final isInternalGPS =
        gpsProvider.listeningPosition && !hasGPSConnection && !isMockGPS;
    final isPhoneGpsSource = isInternalGPS || isMockGPS;
    final lastPos = gpsProvider.lastPosition;

    // GPS has valid position if connected AND has valid lat/lon coordinates
    final hasValidPosition =
        (hasGPSConnection &&
            nmea != null &&
            nmea.latitude != null &&
            nmea.longitude != null) ||
        (isPhoneGpsSource && lastPos != null);

    // Choose icon based on GPS source
    //final icon = isInternalGPS ? Icons.smartphone : (hasValidPosition ? Icons.bluetooth_connected : Icons.bluetooth);
    final icon = isMockGPS
        ? Icons.route
        : (isInternalGPS ? Icons.smartphone : Icons.satellite_alt);
    //final icon = Icons.satellite_alt;

    return IconButton(
      icon: Icon(
        icon,
        color: hasValidPosition
            ? Colors.green
            : (hasGPSConnection || isGPSConnecting || isPhoneGpsSource
                  ? Colors.orange
                  : null),
      ),
      tooltip: hasValidPosition
          ? (isMockGPS
                ? 'Mocked GPS (Android): ${lastPos!.accuracy.toStringAsFixed(1)}m (HDOP/PDOP not provided by Android mock-location API)'
                : isInternalGPS
                ? 'Internal GPS: ${lastPos!.accuracy.toStringAsFixed(1)}m (HDOP: ${nmea?.hdop?.toStringAsFixed(1) ?? "N/A"})'
                : hasBLEConnection
                ? 'GPS: ${gpsProvider.connectedDevice?.platformName} (${nmea!.satellites ?? 0} sats)'
                : 'GPS: ${gpsProvider.connectedClassicDevice?.name} (${nmea!.satellites ?? 0} sats)')
          : hasGPSConnection
          ? 'GPS connected - waiting for position...'
          : isGPSConnecting
          ? 'Connecting to GPS...'
          : isMockGPS
          ? (isReceivingMockData
                ? 'Mocked GPS active'
                : 'Waiting for Android mock location (NTRIP/mock app)...')
          : isInternalGPS
          ? 'Internal GPS active'
          : 'Bluetooth GPS',
      onPressed: _showDeviceMenu,
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable sheet: scan for and connect to GNSS/Bluetooth devices.
// Used by BluetoothIconCombined (dismissible) and GnssTestBtn (non-dismissible).
// ---------------------------------------------------------------------------

class BluetoothDeviceMenuSheet extends StatefulWidget {
  /// When [popOnConnect] is true (default), the sheet closes itself after a
  /// device is selected. Set to false to keep the sheet open so the user can
  /// observe the connection result live.
  const BluetoothDeviceMenuSheet({super.key, this.popOnConnect = true});

  final bool popOnConnect;

  @override
  State<BluetoothDeviceMenuSheet> createState() =>
      _BluetoothDeviceMenuSheetState();
}

class _BluetoothDeviceMenuSheetState extends State<BluetoothDeviceMenuSheet> {
  List<CombinedBluetoothDevice> _combinedDevices = [];
  bool _isScanning = false;
  StreamSubscription<List<ble.ScanResult>>? _bleScanSubscription;
  classic.FlutterBluetoothSerial? _flutterBluetoothSerial;
  StreamSubscription<classic.BluetoothDiscoveryResult>?
  _classicScanSubscription;
  Timer? _classicReconnectTimeout;
  late Future<bool> _bluetoothCheckFuture;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      _flutterBluetoothSerial = classic.FlutterBluetoothSerial.instance;
    }
    _bluetoothCheckFuture = _checkBluetoothAvailable();
    // Keep device list in sync with BLE scan results
    _bleScanSubscription = ble.FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      final newDevices = <CombinedBluetoothDevice>[];
      for (final result in results) {
        newDevices.add(
          CombinedBluetoothDevice(
            id: result.device.remoteId.toString(),
            name: result.device.platformName.isEmpty
                ? 'Unknown BLE Device'
                : result.device.platformName,
            rssi: result.rssi,
            isBLE: true,
            bleDevice: result.device,
          ),
        );
      }
      // Preserve Classic devices already found
      newDevices.addAll(_combinedDevices.where((d) => !d.isBLE));
      setState(() => _combinedDevices = newDevices);
    });
  }

  @override
  void dispose() {
    _bleScanSubscription?.cancel();
    _classicScanSubscription?.cancel();
    _classicReconnectTimeout?.cancel();
    ble.FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<bool> _checkBluetoothAvailable() async {
    try {
      if (await ble.FlutterBluePlus.isSupported == false) return false;
      final adapterState = await ble.FlutterBluePlus.adapterState.first;
      return adapterState == ble.BluetoothAdapterState.on;
    } catch (_) {
      return false;
    }
  }

  Future<void> _stopAllScans() async {
    try {
      if (await ble.FlutterBluePlus.isScanning.first) {
        await ble.FlutterBluePlus.stopScan();
      }
      _classicScanSubscription?.cancel();
      _classicScanSubscription = null;
      _classicReconnectTimeout?.cancel();
      _classicReconnectTimeout = null;
      // Explicitly cancel Android Classic discovery so the adapter is free
      // for the next startDiscovery() call.
      await _flutterBluetoothSerial?.cancelDiscovery();
      if (mounted) setState(() => _isScanning = false);
    } catch (e) {}
  }

  Future<void> _startScan() async {
    final gpsProvider = context.read<GpsPositionProvider>();
    final hasActiveGPS =
        gpsProvider.connectedDevice != null ||
        gpsProvider.connectedClassicDevice != null ||
        gpsProvider.listeningPosition;
    if (gpsProvider.isConnecting || hasActiveGPS) return;

    await _stopAllScans();
    setState(() {
      _combinedDevices = [];
      _isScanning = true;
    });

    try {
      // Phase 1: BLE scan (10 s).
      // startScan(timeout:) starts the scan and schedules an auto-stop; it
      // completes almost immediately, so we also await a matching delay so
      // that results can come in via _bleScanSubscription before we move on.
      await ble.FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      await Future.delayed(const Duration(seconds: 10));
      await ble.FlutterBluePlus.stopScan();
      // _isScanning intentionally stays true — Classic scan follows.

      // Phase 2: Classic scan (Android, up to ~14 s).
      // Running both simultaneously interferes with BLE on Android, so we run
      // them sequentially and only clear _isScanning after Classic is done.
      if (Platform.isAndroid && _flutterBluetoothSerial != null) {
        // Cancel any lingering discovery on the Android side, then give the
        // adapter a moment to settle before starting a new inquiry.
        await _flutterBluetoothSerial!.cancelDiscovery();
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        _classicScanSubscription = _flutterBluetoothSerial!
            .startDiscovery()
            .listen(
              (result) {
                if (!mounted) return;
                setState(() {
                  final exists = _combinedDevices.any(
                    (d) => d.id == result.device.address,
                  );
                  if (!exists) {
                    _combinedDevices.add(
                      CombinedBluetoothDevice(
                        id: result.device.address,
                        name: result.device.name ?? 'Unknown Classic Device',
                        rssi: result.rssi,
                        isBLE: false,
                        classicDevice: result.device,
                      ),
                    );
                  }
                });
              },
              onError: (e) => debugPrint('Classic scan error: $e'),
              onDone: () {
                _classicReconnectTimeout?.cancel();
                _classicReconnectTimeout = null;
                if (mounted) setState(() => _isScanning = false);
              },
            );
        // Safety-net timer in case onDone never fires.
        _classicReconnectTimeout = Timer(const Duration(seconds: 14), () {
          _classicScanSubscription?.cancel();
          _classicScanSubscription = null;
          if (mounted) setState(() => _isScanning = false);
        });
      } else {
        if (mounted) setState(() => _isScanning = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _connectToBLEDevice(ble.BluetoothDevice device) async {
    await _stopAllScans();
    if (!mounted) return;
    final gpsProvider = context.read<GpsPositionProvider>();
    gpsProvider.stopAll();
    gpsProvider.connectDevice(
      ble.BluetoothDevice.fromId(device.remoteId.toString()),
    );
    if (widget.popOnConnect && mounted) Navigator.pop(context);
  }

  Future<void> _connectToClassicDevice(classic.BluetoothDevice device) async {
    if (!device.isBonded) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Nicht gekoppelt'),
            content: Text(
              'Gerät "${device.name ?? device.address}" ist nicht gekoppelt.\n\n'
              'Bitte zuerst in den Bluetooth-Einstellungen koppeln.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }
    await _stopAllScans();
    if (!mounted) return;
    final gpsProvider = context.read<GpsPositionProvider>();
    gpsProvider.stopAll();
    await gpsProvider.connectClassicDevice(device);
    if (widget.popOnConnect && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'erreichbare GNSS Geräte',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (_isScanning)
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: _stopAllScans,
                ),
              if (!_isScanning)
                Consumer<GpsPositionProvider>(
                  builder: (context, gpsProvider, child) {
                    final hasActiveGPS =
                        gpsProvider.connectedDevice != null ||
                        gpsProvider.connectedClassicDevice != null ||
                        gpsProvider.listeningPosition;
                    return FutureBuilder<bool>(
                      future: _bluetoothCheckFuture,
                      builder: (context, snapshot) {
                        final isAvailable = snapshot.data ?? false;
                        if (!isAvailable) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              'Bluetooth Off',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        return IconButton(
                          icon: Icon(
                            Icons.refresh,
                            color: hasActiveGPS ? Colors.grey : null,
                          ),
                          onPressed: hasActiveGPS ? null : _startScan,
                        );
                      },
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          Consumer<GpsPositionProvider>(
            builder: (context, gpsProvider, child) {
              final isMockGpsActive = gpsProvider.isMockGpsActive;
              final isReceivingMockData =
                  gpsProvider.isReceivingAndroidMockData;
              if (gpsProvider.connectedDevice != null) {
                final device = gpsProvider.connectedDevice!;
                final nmea = gpsProvider.currentNMEA;
                final hasValidPosition =
                    nmea != null &&
                    nmea.latitude != null &&
                    nmea.longitude != null;
                return Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.gps_fixed,
                        color: hasValidPosition ? Colors.green : Colors.orange,
                      ),
                      title: Text(
                        device.platformName.isEmpty
                            ? 'GPS Device'
                            : device.platformName,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${device.remoteId}'),
                          if (hasValidPosition) ...[
                            Text(
                              'Sats: ${nmea.satellites ?? "N/A"} | HDOP: ${nmea.hdop?.toStringAsFixed(1) ?? "N/A"} | PDOP: ${nmea.pdop?.toStringAsFixed(1) ?? "N/A"}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              'Lat: ${nmea.latitude!.toStringAsFixed(6)}, Lon: ${nmea.longitude!.toStringAsFixed(6)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ] else
                            const Text(
                              'Waiting for GPS position...',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange,
                              ),
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          gpsProvider.stopAll();
                          _startScan();
                        },
                      ),
                    ),
                    const Divider(),
                  ],
                );
              } else if (gpsProvider.connectedClassicDevice != null) {
                final device = gpsProvider.connectedClassicDevice!;
                final nmea = gpsProvider.currentNMEA;
                final hasValidPosition =
                    nmea != null &&
                    nmea.latitude != null &&
                    nmea.longitude != null;
                return Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.gps_fixed,
                        color: hasValidPosition ? Colors.green : Colors.orange,
                      ),
                      title: Text(device.name ?? 'Classic GPS Device'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(device.address),
                          if (hasValidPosition) ...[
                            Text(
                              'Sats: ${nmea.satellites ?? "N/A"} | HDOP: ${nmea.hdop?.toStringAsFixed(1) ?? "N/A"} | PDOP: ${nmea.pdop?.toStringAsFixed(1) ?? "N/A"}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              'Lat: ${nmea.latitude!.toStringAsFixed(6)}, Lon: ${nmea.longitude!.toStringAsFixed(6)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ] else
                            const Text(
                              'Waiting for GPS position...',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange,
                              ),
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          gpsProvider.stopAll();
                          _startScan();
                        },
                      ),
                    ),
                    const Divider(),
                  ],
                );
              } else if (isMockGpsActive) {
                final lastPos = gpsProvider.lastPosition;
                final extras = gpsProvider.lastAndroidLocationExtras;
                final extrasSatellites =
                    gpsProvider.lastAndroidExtrasSatellites;
                final extrasHdop = gpsProvider.lastAndroidExtrasHdop;
                final extrasPdop = gpsProvider.lastAndroidExtrasPdop;
                final hasExtrasQuality =
                    extrasSatellites != null ||
                    extrasHdop != null ||
                    extrasPdop != null;
                final extraKeysText = extras != null && extras.isNotEmpty
                    ? extras.keys.take(6).join(', ')
                    : null;
                return Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.route,
                        color: lastPos != null ? Colors.green : Colors.orange,
                      ),
                      title: const Text('Mocked GPS (Android/NTRIP)'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Uses Android mock-location provider'),
                          const Text(
                            'Satellites/PDOP from the NTRIP app may not be exposed by Android location API.',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          const Text(
                            'Small coordinate differences can occur due to Android location filtering/timing.',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          if (hasExtrasQuality)
                            Text(
                              'Location extras -> Sats: ${extrasSatellites ?? "N/A"} | HDOP: ${extrasHdop?.toStringAsFixed(2) ?? "N/A"} | PDOP: ${extrasPdop?.toStringAsFixed(2) ?? "N/A"}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          if (extraKeysText != null)
                            Text(
                              'Extras keys: $extraKeysText${extras!.length > 6 ? ', ...' : ''}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          if (!isReceivingMockData)
                            const Text(
                              'No mocked location received yet. Start your NTRIP/mock-location app and set it as mock location app in Android Developer Options.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange,
                              ),
                            ),
                          if (lastPos != null) ...[
                            Text(
                              'Accuracy: ${lastPos.accuracy.toStringAsFixed(1)}m | HDOP: ${extrasHdop?.toStringAsFixed(2) ?? "N/A"} | PDOP: ${extrasPdop?.toStringAsFixed(2) ?? "N/A"}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              'Lat: ${lastPos.latitude.toStringAsFixed(8)}, Lon: ${lastPos.longitude.toStringAsFixed(8)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ] else
                            const Text(
                              'Waiting for Android mocked position...',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange,
                              ),
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          gpsProvider.stopAll();
                          _startScan();
                        },
                      ),
                    ),
                    const Divider(),
                  ],
                );
              } else if (gpsProvider.listeningPosition) {
                final lastPos = gpsProvider.lastPosition;
                final nmea = gpsProvider.currentNMEA;
                return Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.smartphone,
                        color: lastPos != null ? Colors.green : Colors.orange,
                      ),
                      title: const Text('Internal GPS'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Device internal GPS sensor'),
                          if (lastPos != null) ...[
                            Text(
                              'Accuracy: ${lastPos.accuracy.toStringAsFixed(1)}m | HDOP: ${nmea?.hdop?.toStringAsFixed(1) ?? "N/A"}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              'Lat: ${lastPos.latitude.toStringAsFixed(6)}, Lon: ${lastPos.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ] else
                            const Text(
                              'Waiting for GPS position...',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange,
                              ),
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          gpsProvider.stopAll();
                          _startScan();
                        },
                      ),
                    ),
                    const Divider(),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _combinedDevices.length + (Platform.isAndroid ? 2 : 1),
              itemBuilder: (context, index) {
                final gpsProvider = context.watch<GpsPositionProvider>();
                final isMockGPS =
                    gpsProvider.isMockGpsActive &&
                    gpsProvider.connectedDevice == null &&
                    gpsProvider.connectedClassicDevice == null;
                final isInternalGPS =
                    gpsProvider.listeningPosition &&
                    gpsProvider.connectedDevice == null &&
                    gpsProvider.connectedClassicDevice == null &&
                    !gpsProvider.isMockGpsActive;

                if (index == 0) {
                  return ListTile(
                    leading: Icon(
                      Icons.smartphone,
                      color: isInternalGPS ? Colors.green : Colors.grey,
                    ),
                    title: const Text('Internal GPS'),
                    subtitle: const Text('Device internal GPS sensor'),
                    trailing: isInternalGPS
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () {
                      gpsProvider.stopAll();
                      gpsProvider.startInternalGps();
                      if (widget.popOnConnect) Navigator.pop(context);
                    },
                  );
                }

                if (Platform.isAndroid && index == 1) {
                  return ListTile(
                    leading: Icon(
                      Icons.route,
                      color: isMockGPS ? Colors.green : Colors.grey,
                    ),
                    title: const Text('Mocked GPS (Android/NTRIP)'),
                    subtitle: const Text('Uses Android mock-location provider'),
                    trailing: isMockGPS
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () {
                      gpsProvider.stopAll();
                      gpsProvider.startMockGps();
                      if (widget.popOnConnect) Navigator.pop(context);
                    },
                  );
                }

                final deviceIndex = index - (Platform.isAndroid ? 2 : 1);
                if (deviceIndex >= _combinedDevices.length)
                  return const SizedBox.shrink();
                final device = _combinedDevices[deviceIndex];
                return ListTile(
                  leading: Icon(
                    device.isBLE ? Icons.bluetooth : Icons.bluetooth_audio,
                    color: device.isBLE ? Colors.blue[700] : Colors.orange[700],
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(device.name)),
                      if (!device.isBLE &&
                          device.classicDevice != null &&
                          !device.classicDevice!.isBonded)
                        const Padding(
                          padding: EdgeInsets.only(left: 4.0),
                          child: Icon(
                            Icons.lock_open,
                            size: 16,
                            color: Colors.orange,
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    '${device.isBLE ? "BLE" : "Classic"} - ${device.id}',
                  ),
                  trailing: device.rssi != null
                      ? Text('${device.rssi} dBm')
                      : null,
                  onTap: () {
                    if (device.isBLE && device.bleDevice != null) {
                      _connectToBLEDevice(device.bleDevice!);
                    } else if (device.classicDevice != null) {
                      _connectToClassicDevice(device.classicDevice!);
                    }
                  },
                  selected: (device.isBLE
                      ? context
                                .watch<GpsPositionProvider>()
                                .connectedDevice
                                ?.remoteId
                                .toString() ==
                            device.id
                      : context
                                .watch<GpsPositionProvider>()
                                .connectedClassicDevice
                                ?.address ==
                            device.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
