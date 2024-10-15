import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class GNSSBluetooth extends StatefulWidget {
  const GNSSBluetooth({super.key});

  @override
  State<GNSSBluetooth> createState() => _GNSSBluetoothState();
}

class _GNSSBluetoothState extends State<GNSSBluetooth> {
  //List baudeRates = [9600, 19200, 38400, 57600, 115200];
  List baudeRates = [9600, 19200, 38400, 57600, 115200];
  int? baudeRate;
  List<String> availablePorts = [];
  String selectedPort = '';
  bool scanning = false;
  bool tested = false;
  bool testing = false;
  var serialPort;

  _getAvailablePorts() {
    return FlutterBluePlus.onScanResults.listen(
      (results) {
        print(results);
        if (results.isNotEmpty) {
          ScanResult r = results.last; // the most recently found device
          print('${r.device.remoteId}: "${r.advertisementData.advName}" found!');
          availablePorts.add(r.advertisementData.advName);
          setState(() {
            availablePorts = availablePorts.toSet().toList();
          });
        }
      },
      onError: (e) => print(e),
    );
  }

  _refreshAvailable() async {
    scanning = true;
    await FlutterBluePlus.startScan(timeout: Duration(seconds: 4), androidUsesFineLocation: true);
    scanning = false;
  }

  Future<dynamic> _init() async {
    if (await FlutterBluePlus.isSupported == false) {
      print("Bluetooth not supported by this device");
      return;
    }

    var status = await Permission.bluetoothScan.status;
    if (status.isDenied) {
      print('denied');
    } else {
      print('Permitted');
    }

    // handle bluetooth on & off
    // note: for iOS the initial state is typically BluetoothAdapterState.unknown
    // note: if you have permissions issues you will get stuck at BluetoothAdapterState.unauthorized
    var subscription = FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) async {
      print('BluetoothAdapterState');
      print(state);
      if (state == BluetoothAdapterState.on) {
        // usually start scanning, connecting, etc
        _getAvailablePorts();

        print('start Scanning');
      } else {
        // show an error to the user, etc
        print('ERROR');
      }
    });
    print('START _INiT');
    return;

    // turn on bluetooth ourself if we can
    // for iOS, the user controls bluetooth enable/disable
    if (Platform.isAndroid) {
      await FlutterBluePlus.turnOn();
    }

    // cancel to prevent duplicate listeners
    subscription.cancel();
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _init();
  }

  _testConnection() {}
  _cancelTesting() {}

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
            title: Text('Serial Ports:'),
            subtitle: Text('Get Information from Device...'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  value: selectedPort,
                  onChanged: (String? value) {
                    if (value == null) return;
                    setState(() {
                      selectedPort = value;
                    });
                  },
                  items: availablePorts.map<DropdownMenuItem<String>>((dynamic value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(), // Explicitly specify the type
                ),
                IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: _refreshAvailable,
                ),
              ],
            )),
        ListTile(
          title: Text('Baud Rate: '),
          subtitle: Text('Get Information from Device...'),
          trailing: DropdownButton<int>(
            value: baudeRate,
            onChanged: (int? value) {
              setState(() {
                baudeRate = value;
              });
            },
            items: baudeRates.map<DropdownMenuItem<int>>((dynamic value) {
              return DropdownMenuItem<int>(
                value: value,
                child: Text(value.toString()),
              );
            }).toList(), // Explicitly specify the type
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (testing)
              ElevatedButton(
                onPressed: _cancelTesting,
                child: Text('Cancel testing'),
              )
            else
              ElevatedButton(
                onPressed: baudeRate != null ? _testConnection : null,
                child: Text('TEST connection'),
              ),
          ],
        )
      ],
    );
  }
}
