import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';
import 'dart:async';

// Conditional import: use real serial port on native platforms (Windows/Linux/macOS), stub on web
import 'package:flutter_libserialport/flutter_libserialport.dart'
    if (dart.library.html) 'package:terrestrial_forest_monitor/services/serial_port_stub.dart';

class SerialPortDevice {
  final String name;
  final String description;

  SerialPortDevice({required this.name, required this.description});
}

class SerialPortGpsIcon extends StatefulWidget {
  const SerialPortGpsIcon({super.key});

  @override
  State<SerialPortGpsIcon> createState() => _SerialPortGpsIconState();
}

class _SerialPortGpsIconState extends State<SerialPortGpsIcon> {
  List<SerialPortDevice> _availablePorts = [];
  bool _isScanning = false;
  String? _connectedPort;
  SerialPort? _activePort;
  SerialPortReader? _reader;
  StreamSubscription? _readerSubscription;
  String? _serialPortError; // Track serial port error messages

  @override
  void initState() {
    super.initState();
    // DO NOT scan ports on init - this causes Semaphore timeout on Windows
    // Ports will be scanned only when user opens the device menu
  }

  Future<void> _scanPorts() async {
    setState(() {
      _availablePorts = [];
      _isScanning = true;
      _serialPortError = null;
    });

    try {
      // Add timeout to prevent hanging
      final ports =
          await Future.delayed(
            const Duration(milliseconds: 100),
            () => SerialPort.availablePorts,
          ).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('Serial port scan timeout - this is common on Windows with VPN/Bluetooth');
              throw TimeoutException('Serial port scan timed out');
            },
          );

      final devices = <SerialPortDevice>[];

      for (final portName in ports) {
        try {
          final port = SerialPort(portName);
          final description = port.description ?? 'Unknown Device';
          devices.add(
            SerialPortDevice(
              name: portName,
              description: description.isEmpty ? 'Serial Device' : description,
            ),
          );
          port.dispose();
        } catch (e) {
          debugPrint('Error reading port $portName: $e');
        }
      }

      if (mounted) {
        setState(() {
          _availablePorts = devices;
          _isScanning = false;
        });
      }
    } catch (e) {
      debugPrint('Error scanning ports: $e');
      final errorMessage = e.toString().contains('TimeoutException')
          ? 'Serial port scan timed out. Try disabling VPN or closing other apps that use COM ports.'
          : 'Failed to scan serial ports: $e';

      if (mounted) {
        setState(() {
          _isScanning = false;
          _serialPortError = errorMessage;
        });
      }
    }
  }

  Future<void> _connectToSerialPort(String portName, BuildContext context) async {
    try {
      final gpsProvider = context.read<GpsPositionProvider>();

      // Stop any existing connections
      gpsProvider.stopAll();
      await _disconnectSerialPort();

      // Open serial port
      _activePort = SerialPort(portName);

      if (!_activePort!.openReadWrite()) {
        throw Exception('Failed to open port: ${SerialPort.lastError}');
      }

      // Configure port for GPS (typical settings: 9600 baud, 8N1)
      final config = SerialPortConfig();
      config.baudRate = 9600;
      config.bits = 8;
      config.stopBits = 1;
      config.parity = SerialPortParity.none;
      _activePort!.config = config;

      // Start reading NMEA data
      _reader = SerialPortReader(_activePort!);

      _readerSubscription = _reader!.stream.listen(
        (data) {
          // Process NMEA data using GPS provider's serial port method
          gpsProvider.processSerialPortData(data);
        },
        onError: (error) {
          debugPrint('Serial port read error: $error');
          _showErrorDialog('GPS connection lost: $error');
          _disconnectSerialPort();
        },
        onDone: () {
          debugPrint('Serial port connection closed');
          _disconnectSerialPort();
        },
      );

      setState(() {
        _connectedPort = portName;
      });

      if (mounted && context.mounted) {
        try {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Connecting to GPS on $portName...')));
        } catch (e) {
          debugPrint('Could not show snackbar: $e');
        }
      }
    } catch (e) {
      debugPrint('Error connecting to serial port: $e');
      _disconnectSerialPort();
      if (mounted && context.mounted) {
        _showErrorDialog('Failed to connect to GPS: $e');
      }
    }
  }

  Future<void> _disconnectSerialPort() async {
    await _readerSubscription?.cancel();
    _readerSubscription = null;

    _reader = null;

    _activePort?.close();
    _activePort?.dispose();
    _activePort = null;

    if (mounted) {
      setState(() {
        _connectedPort = null;
      });
    }
  }

  void _showDeviceMenu() async {
    // Auto-start scan when opening modal if not already scanning
    // Use try-catch to prevent modal from crashing if scan fails
    final gpsProvider = context.read<GpsPositionProvider>();
    if (!_isScanning && _connectedPort == null && gpsProvider.connectedDevice == null) {
      // Delay scan slightly to allow modal to open first
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _scanPorts();
        }
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'GPS Devices',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    if (_isScanning)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    if (!_isScanning)
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () {
                          _scanPorts();
                          setModalState(() {});
                        },
                        tooltip: 'Scan for serial ports',
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Show connected serial GPS or internal GPS
                Consumer<GpsPositionProvider>(
                  builder: (context, gpsProvider, child) {
                    final nmea = gpsProvider.currentNMEA;
                    final isInternalGPS = gpsProvider.listeningPosition && _connectedPort == null;
                    final lastPos = gpsProvider.lastPosition;

                    if (_connectedPort != null) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.usb, color: Colors.green),
                          title: Text(_connectedPort!),
                          subtitle: nmea != null && nmea.latitude != null
                              ? Text(
                                  'Position: ${nmea.latitude!.toStringAsFixed(6)}, ${nmea.longitude!.toStringAsFixed(6)}\n'
                                  'Satellites: ${nmea.satellites ?? 0}',
                                )
                              : const Text('Waiting for GPS signal...'),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () async {
                              await _disconnectSerialPort();
                              gpsProvider.stopAll();
                              setModalState(() {});
                            },
                            tooltip: 'Disconnect',
                          ),
                        ),
                      );
                    } else if (isInternalGPS) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.smartphone),
                          title: const Text('Internal GPS'),
                          subtitle: lastPos != null
                              ? Text(
                                  'Position: ${lastPos.latitude.toStringAsFixed(6)}, ${lastPos.longitude.toStringAsFixed(6)}\n'
                                  'Accuracy: ${lastPos.accuracy.toStringAsFixed(1)}m',
                                )
                              : const Text('Acquiring position...'),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              gpsProvider.stopAll();
                              setModalState(() {});
                            },
                            tooltip: 'Stop GPS',
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                const SizedBox(height: 16),
                const Text(
                  'Available Serial Ports',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),

                // Show error message if serial port scan failed
                if (_serialPortError != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _serialPortError!,
                            style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Device list
                Expanded(
                  child: _availablePorts.isEmpty
                      ? Center(
                          child: _isScanning
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text('Scanning serial ports...'),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _serialPortError != null
                                          ? Icons.error_outline
                                          : Icons.info_outline,
                                      size: 48,
                                      color: _serialPortError != null ? Colors.orange : Colors.grey,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _serialPortError != null
                                          ? 'Unable to scan serial ports'
                                          : 'No serial ports found',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    if (_serialPortError == null)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Text(
                                          'Click refresh to scan',
                                          style: TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ),
                                  ],
                                ),
                        )
                      : ListView.builder(
                          itemCount: _availablePorts.length,
                          itemBuilder: (context, index) {
                            final device = _availablePorts[index];
                            final isConnected = device.name == _connectedPort;

                            return Card(
                              child: ListTile(
                                leading: Icon(Icons.usb, color: isConnected ? Colors.green : null),
                                title: Text(device.name),
                                subtitle: Text(device.description),
                                trailing: isConnected
                                    ? const Icon(Icons.check_circle, color: Colors.green)
                                    : ElevatedButton(
                                        onPressed: () {
                                          _connectToSerialPort(device.name, context);
                                          setModalState(() {});
                                        },
                                        child: const Text('Connect'),
                                      ),
                              ),
                            );
                          },
                        ),
                ),

                const SizedBox(height: 16),

                // Use internal GPS button
                Consumer<GpsPositionProvider>(
                  builder: (context, gpsProvider, child) {
                    final isInternalGPS = gpsProvider.listeningPosition && _connectedPort == null;

                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _connectedPort == null && !isInternalGPS
                            ? () {
                                gpsProvider.startInternalGps();
                                setModalState(() {});
                              }
                            : null,
                        icon: const Icon(Icons.smartphone),
                        label: const Text('Use Internal GPS'),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      // Cleanup when modal is closed
    });
  }

  void _showErrorDialog(String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _disconnectSerialPort();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gpsProvider = context.watch<GpsPositionProvider>();
    final nmea = gpsProvider.currentNMEA;
    final isInternalGPS = gpsProvider.listeningPosition && _connectedPort == null;
    final lastPos = gpsProvider.lastPosition;

    // GPS has valid position if connected AND has valid lat/lon coordinates
    final hasValidPosition =
        (_connectedPort != null &&
            nmea != null &&
            nmea.latitude != null &&
            nmea.longitude != null) ||
        (isInternalGPS && lastPos != null);

    // Choose icon based on GPS source
    final icon = isInternalGPS ? Icons.smartphone : Icons.usb;

    return IconButton(
      icon: Icon(
        icon,
        color: hasValidPosition
            ? Colors.green
            : (_connectedPort != null || isInternalGPS ? Colors.orange : null),
      ),
      tooltip: hasValidPosition
          ? (isInternalGPS
                ? 'Internal GPS: ${lastPos!.accuracy.toStringAsFixed(1)}m'
                : 'GPS: $_connectedPort (${nmea!.satellites ?? 0} sats)')
          : _connectedPort != null
          ? 'GPS connected - waiting for position...'
          : isInternalGPS
          ? 'Internal GPS active'
          : 'Serial Port GPS',
      onPressed: _showDeviceMenu,
    );
  }
}
