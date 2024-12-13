import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/polyfill/libserial.dart' if (dart.library.html) 'package:terrestrial_forest_monitor/polyfill/libserial.dart' if (dart.library.io) 'package:flutter_libserialport/flutter_libserialport.dart';
//import 'package:flutter_libserialport/flutter_libserialport.dart';

extension IntToString on int {
  String toHex() => '0x${toRadixString(16)}';
  String toPadded([int width = 3]) => toString().padLeft(width, '0');
  String toTransport() {
    switch (this) {
      case SerialPortTransport.usb:
        return 'USB';
      case SerialPortTransport.bluetooth:
        return 'Bluetooth';
      case SerialPortTransport.native:
        return 'Native';
      default:
        return 'Unknown';
    }
  }
}

class GnssSerialSelection extends StatefulWidget {
  const GnssSerialSelection({super.key});

  @override
  State<GnssSerialSelection> createState() => _GnssSerialSelectionState();
}

class _GnssSerialSelectionState extends State<GnssSerialSelection> {
  //List baudeRates = [9600, 19200, 38400, 57600, 115200];
  List baudeRates = [9600, 19200, 38400, 57600, 115200];
  int? baudeRate;
  List availablePorts = [];
  String selectedPort = '';
  bool tested = false;
  bool testing = false;
  var serialPort;

  @override
  void initState() {
    super.initState();
    baudeRate = baudeRates[0];
    _getAvailablePorts();
  }

  @override
  void dispose() {
    super.dispose();
    _closePort();
  }

  _closePort() {
    if (serialPort != null && serialPort!.isOpen) {
      serialPort?.close();
    }
  }

  _getAvailablePorts() {
    try {
      availablePorts = SerialPort.availablePorts;
    } catch (e) {
      if (e is SerialPortError) {
        // TODO: Show error
        print('$e');
        // Handle the error, e.g., show a dialog or a snackbar
      } else {
        print('Error: $e');
      }
    }
    setState(() {
      print(availablePorts);
      if (availablePorts.isNotEmpty) {
        selectedPort = availablePorts[0].toString();
      }
    });
  }

  Future _getSerialPorts() async {}

  dynamic _saveDevice() {
    return null;
  }

  _cancelTesting() {
    _closePort();
    setState(() {
      testing = false;
    });
  }

  void parseReceiveData(String nmeaData) {
    double latitude;
    double longitude;

    var nmeaDataArray = nmeaData.split(",");

    if (nmeaDataArray[0].startsWith('\$GNRMC') && nmeaDataArray[3].isNotEmpty && nmeaDataArray[5].isNotEmpty) {
      print('parse');
      //latitude = parseToDecimal(nmeaDataArray[3], nmeaDataArray[4]);
      //longitude = parseToDecimal(nmeaDataArray[5], nmeaDataArray[6]);
    }
  }

  Future<void> _testConnection() async {
    _closePort();
    if (selectedPort.isEmpty) {
      return;
    }

    setState(() {
      testing = true;
    });

    serialPort = SerialPort(selectedPort);

    if (serialPort == null || baudeRate == null) {
      print('Serial port is null');
      return;
    }

    try {
      var config = serialPort!.config;
      print(baudeRate);
      config.baudRate = baudeRate!;
      serialPort!.config = config;

      if (serialPort!.openRead()) {
        print('Port opened');
        tested = true;
      } else {
        print('Port not opened');
      }
      var reader = SerialPortReader(serialPort!);
      reader!.stream.listen((data) {
        //print('Data: $data');
        String utfDAta = String.fromCharCodes(data);
        if (utfDAta.startsWith('\$GNRMC')) parseReceiveData(utfDAta);
      }, onDone: () {
        print('Done');
        setState(() {
          tested = true;
        });
      }, onError: (e) {
        print('Error: $e');
      });
      print('read start');
    } catch (e) {
      print(e);
    }
  }

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
                      value: value.toString(),
                      child: Text(value.toString()),
                    );
                  }).toList(), // Explicitly specify the type
                ),
                IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: _getAvailablePorts,
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
            ElevatedButton(
              onPressed: tested ? _saveDevice : null,
              child: Text('SAVE'),
            )
          ],
        )
      ],
    );
  }
}
