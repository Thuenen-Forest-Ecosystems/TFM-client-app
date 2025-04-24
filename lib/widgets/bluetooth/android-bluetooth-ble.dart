import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';
import 'package:terrestrial_forest_monitor/services/utils.dart';

class AndroidBluetoothBle extends StatefulWidget {
  final bool autoSearch;
  const AndroidBluetoothBle({super.key, this.autoSearch = false});

  @override
  State<AndroidBluetoothBle> createState() => _AndroidBluetoothBleState();
}

class _AndroidBluetoothBleState extends State<AndroidBluetoothBle> {
  String? latestRemoteId;
  List<ScanResult> devices = [];
  StreamSubscription? subscriptionScan;
  StreamSubscription? subscriptionConnection;
  StreamSubscription? subscriptionNotification;
  bool isScanning = false;
  bool isConnected = false;
  BluetoothDevice? connectedDevice;

  void _parseData(List<int> data) {
    print('Parsing data');
    // Convert the byte data to a string
    String rawData = String.fromCharCodes(data);

    try {
      // Split by newlines in case multiple NMEA sentences were received
      List<String> sentences = rawData.split('\n');

      for (String sentence in sentences) {
        // Trim the sentence to remove any whitespace
        sentence = sentence.trim();

        // Skip empty lines
        if (sentence.isEmpty) continue;

        // Check if it's a valid NMEA sentence (starts with $)
        if (sentence.startsWith('\$')) {
          try {
            List<String> fields = sentence.split(',');

            String talkerId = fields[0].substring(1);

            print('$talkerId');

            // https://openrtk.readthedocs.io/en/latest/communication_port/nmea.html
            if (talkerId == 'GNRMC') {
              String time = fields[1];
              String status = fields[2];
              String latitude = fields[3];
              String latitudeDirection = fields[4];
              String longitude = fields[5];
              String longitudeDirection = fields[6];
              String speedOverGround = fields[7];
              String courseOverGround = fields[8];

              print('Time: $time');
              print('Status: $status');
              print('Latitude: ${dmsToDecimal('0' + latitude, latitudeDirection)}°');
              print('Latitude Direction: $latitudeDirection');
              print('Longitude: ${dmsToDecimal(longitude, longitudeDirection)}°');
              print('Longitude Direction: $longitudeDirection');
              print('Speed Over Ground: $speedOverGround');
              print('Course Over Ground: $courseOverGround');
            } else if (talkerId == 'GNGGA') {
              String time = fields[1];
              String latitude = fields[2];
              String latitudeDirection = fields[3];
              String longitude = fields[4];
              String longitudeDirection = fields[5];
              String quality = fields[6];
              String satellites = fields[7];
              String horizontalDilution = fields[8];
              String altitude = fields[9];

              print('Time: $time');
              print('Latitude: $latitude');
              print('Latitude Direction: $latitudeDirection');
              print('Longitude: $longitude');
              print('Longitude Direction: $longitudeDirection');
              print('Quality: $quality');
              print('Satellites: $satellites');
              print('Horizontal Dilution: $horizontalDilution');
              print('Altitude: $altitude');
            } else if (talkerId == 'GNGSA') {
              String mode = fields[1];
              String fixType = fields[2];
              String satelliteIds = fields.sublist(3, 15).join(', ');
              String pdop = fields[15];
              String hdop = fields[16];
              String vdop = fields[17];

              print('Mode: $mode');
              print('Fix Type: $fixType');
              print('Satellite IDs: $satelliteIds');
              print('PDOP: $pdop');
              print('HDOP: $hdop');
              print('VDOP: $vdop');
            } else {
              print('Unknown NMEA sentence: $sentence');
            }
          } catch (e) {
            print('Failed to parse NMEA sentence: $sentence');
            print('Error: $e');
          }
        } else {
          print('Not a valid NMEA sentence: $sentence');
        }
      }
    } catch (e) {
      print('Error processing data: $e');
    }
  }

  void _stopScan() async {
    await FlutterBluePlus.stopScan();
    /*
    if (isScanning ) {
      setState(() {
        isScanning = false;
      });
      await FlutterBluePlus.stopScan();
    }*/
  }

  void _startScan() async {
    if (isScanning) {
      _stopScan();
    }
    setState(() {
      isScanning = true;
    });
    subscriptionScan = FlutterBluePlus.onScanResults.listen((results) {
      if (results.isNotEmpty) {
        setState(() {
          devices = results;
        });
      }
    }, onError: (e) => print(e));

    if (subscriptionScan != null) {
      FlutterBluePlus.cancelWhenScanComplete(subscriptionScan!);
    }

    await FlutterBluePlus.startScan(androidUsesFineLocation: true);
  }

  void _saveConnectedDevice(BluetoothDevice device) async {
    String deviceId = device.remoteId.toString();
    Map deviceMap = {'remoteId': deviceId, 'platformName': device.platformName};

    await getSettings('GNSSDevice').then((value) {
      if (value != null) {
        dynamic devices = jsonDecode(value['value']);
        if (devices is Map) {
          devices[deviceId] = deviceMap;
          setSettings('GNSSDevice', jsonEncode(devices));
        } else {
          setSettings('GNSSDevice', jsonEncode({deviceId: deviceMap}));
        }
      } else {
        setSettings('GNSSDevice', jsonEncode({deviceId: deviceMap}));
      }
    });
    //await setSettings('language', newSelection.first);
  }

  void _getConnectedDevice() async {
    await getSettings('GNSSDevice').then((value) {
      if (value != null) {
        dynamic devices = jsonDecode(value['value']);
        if (devices is Map) {
          if (devices.isNotEmpty) {
            print('Found connected devices: $devices');
            // autoConnect First
            for (var deviceId in devices.keys) {
              var device = BluetoothDevice.fromId(deviceId);
              if (device != null) {
                _connectDevice(device);
                break; // Connect to the first found device
              }
            }
          }
        }
      } else {
        print('No connected devices found');
      }
    });
  }

  void _connectDeviceFromId(String remoteId) async {
    if (remoteId.isEmpty) {
      print('No remote ID provided');
      return;
    }
    var device = BluetoothDevice.fromId(remoteId);
    if (device == null) {
      print('Device not found');
      return;
    }
    _connectDevice(device);
  }

  void _connectDevice(BluetoothDevice device) async {
    // Cancel any existing connection subscription first
    await subscriptionConnection?.cancel();

    // listen for disconnection
    subscriptionConnection = device.connectionState.listen((BluetoothConnectionState state) async {
      if (state == BluetoothConnectionState.disconnected) {
        print("disconnected: ${device.platformName}");
      } else if (state == BluetoothConnectionState.connected) {
        print('connected: ${device.platformName}');
        setState(() {
          connectedDevice = device;
        });
        _saveConnectedDevice(device);
        _stopScan();
        _discoverServices(device);
        //latestRemoteId = device.remoteId.toString();
        //_autoConnect(latestRemoteId);
      }
    });

    // cleanup: cancel subscription when disconnected
    device.cancelWhenDisconnected(subscriptionConnection!, delayed: true, next: true);

    // Connect to the device
    await device.connect(autoConnect: true, mtu: null);
  }

  // Add this new method to discover and interact with services
  Future<void> _discoverServices(BluetoothDevice device) async {
    try {
      print('Discovering services...');
      List<BluetoothService> services = await device.discoverServices();
      print('Found ${services.length} services');

      for (var service in services) {
        print('Service: ${service.uuid}');

        // Get characteristics for this service
        for (var characteristic in service.characteristics) {
          print('Characteristic: ${characteristic.uuid}');

          // Check if characteristic is readable
          if (characteristic.properties.read) {
            // Read value
            List<int> value = await characteristic.read();
            print('Read value: ${value}');

            // You can process the data here
            // Example: String stringValue = String.fromCharCodes(value);
          }

          // Check if characteristic supports notifications
          if (characteristic.properties.notify) {
            // Subscribe to notifications
            await characteristic.setNotifyValue(true);
            subscriptionNotification = characteristic.onValueReceived.listen((value) {
              //print('Notification received: ${value}');
              _parseData(value);
              // Process notification data here
            });
          }
        }
      }
    } catch (e) {
      print('Error discovering services: $e');
    }
  }

  void _autoConnect(remoteId) async {
    if (remoteId == null) {
      print('No remote ID provided for auto-connect');
      return;
    }
    var device = BluetoothDevice.fromId(remoteId);

    await device.connect(autoConnect: true);

    await device.connectionState.where((val) {
      if (val == BluetoothConnectionState.connected) {
        print('Connected to device: ${device.platformName}');
        _discoverServices(device);
      } else if (val == BluetoothConnectionState.disconnected) {
        print('Disconnected from device: ${device.platformName}');
      }
      return val == BluetoothConnectionState.connected || val == BluetoothConnectionState.disconnected;
    }).first;
  }

  Future<void> _checkConnectedDevices() async {
    List<BluetoothDevice> connected = await FlutterBluePlus.connectedDevices;
    if (connected.isNotEmpty) {
      print('Already connected devices:');
      for (var device in connected) {
        print('${device.platformName} (${device.remoteId})');
        setState(() {
          connectedDevice = device;
        });
        // Optionally: _discoverServices(device);
      }
    } else {
      print('No devices currently connected');
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.autoSearch) {
      _startScan();
    }
    //_checkConnectedDevices();
    //_getConnectedDevice();
    //_autoConnect('7E:FA:D6:7D:06:69');
  }

  @override
  void dispose() {
    print('dispose');
    // Make sure to stop scanning when disposing the widget
    _stopScan();
    //if (mounted) {
    if (subscriptionScan != null) {
      subscriptionScan!.cancel();
    }
    if (subscriptionConnection != null) {
      subscriptionConnection!.cancel();
    }
    if (subscriptionNotification != null) {
      subscriptionNotification!.cancel();
    }
    //}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: [
        if (connectedDevice != null)
          ListTile(
            leading: const Icon(Icons.bluetooth_connected, color: Colors.green),
            title: Text('Connected: ${connectedDevice!.platformName.isEmpty ? 'Unknown' : connectedDevice!.platformName}'),
            subtitle: Text(connectedDevice!.remoteId.toString()),
            trailing: IconButton(
              icon: const Icon(Icons.bluetooth_disabled),
              onPressed: () {
                connectedDevice!.disconnect();
                setState(() {
                  connectedDevice = null;
                });
              },
            ),
          ),
        if (connectedDevice == null)
          ListTile(
            title: const Text('Nearby Devices (BLE)'),
            //subtitle: Text(isScanning ? 'Found ${devices.length} devices' : ''),
            trailing: StreamBuilder(
              stream: FlutterBluePlus.isScanning,
              builder: (_, snapshot) {
                if (snapshot.hasData && snapshot.data == true) {
                  return IconButton(
                    icon: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    onPressed: () {
                      _stopScan();
                    },
                  );
                } else {
                  return IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      _startScan();
                    },
                  );
                }
              },
            ),
          ),
        /*StreamBuilder(
          stream: FlutterBluePlus.adapterState,
          builder: (_, snapshot) {
            if (snapshot.hasData) {
              final state = snapshot.data;
              if (state == BluetoothAdapterState.on) {
                return const Text('Bluetooth is ON');
              } else if (state == BluetoothAdapterState.off) {
                return const Text('Bluetooth is OFF');
              } else {
                return const Text('Bluetooth state unknown');
              }
            }
            return const Text('Loading Bluetooth state...');
          },
        ),*/
        StreamBuilder(
          stream: FlutterBluePlus.isScanning,
          builder: (_, snapshot) {
            if (snapshot.hasData && snapshot.data == true) {
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  ScanResult scanResult = devices[index];
                  return ListTile(
                    title: Text(scanResult.device.platformName.isEmpty ? 'Unknown' : scanResult.device.platformName),
                    subtitle: Text(scanResult.device.remoteId.toString()),
                    onTap: () {
                      // Connect to the device
                      context.read<GpsPositionProvider>().connectDevice(scanResult.device);
                      //_connectDevice(scanResult.device);
                    },
                  );
                },
              );
            } else {
              return SizedBox();
            }
          },
        ),
      ],
    );
  }
}
