import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:libserialport/libserialport.dart';
//import 'package:terrestrial_forest_monitor/polyfill/libserial.dart' if (dart.library.html) 'package:terrestrial_forest_monitor/polyfill/libserial.dart' if (dart.library.io) 'package:flutter_libserialport/flutter_libserialport.dart';

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
  List<String> nmeaSentences = [];
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
      serialPort.close();
      serialPort.dispose();
      print('CLOSE');
    }
  }

  _getAvailablePorts() {
    try {
      availablePorts = SerialPort.availablePorts;
      setState(() {
        // make unique
        availablePorts = availablePorts.toSet().toList();
        // Make sure to set the selected port to the first available port
        if (availablePorts.isNotEmpty) {
          selectedPort = availablePorts[0].toString();
        }
      });
    } catch (e) {
      if (e is SerialPortError) {
        // TODO: Show error
        print('availablePorts: $e');
        // Handle the error, e.g., show a dialog or a snackbar
      } else {
        print('Error Get Ports: $e');
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

  void _getLatLonFromGNRMC(String line) {
    // Step 5: Split the line by commas
    List<String> parts = line.split(',');

    // Step 6: Check if the line has enough parts
    if (parts.length < 7) {
      return;
    }

    // Step 7: Get the latitude and longitude
    String lat = parts[3];
    String lon = parts[5];

    // Lat and Lon to double
    //double latD = double.parse(lat);
    //double lonD = double.parse(lon);

    // Step 8: Print the latitude and longitude
    print('Latitude: $lat, Longitude: $lon');
    /*return Position(
      latitude: double.parse(lat),
      longitude: double.parse(lon),
    );*/
  }

  Future<void> _testConnection() async {
    _closePort();
    nmeaSentences = [];

    if (selectedPort.isEmpty) {
      return;
    }

    serialPort = SerialPort(selectedPort);

    if (serialPort == null || baudeRate == null) {
      print('Serial port is null');
      return;
    }

    setState(() {
      testing = true;
    });

    try {
      var config = serialPort!.config;
      print(baudeRate);
      config.baudRate = baudeRate!;
      serialPort!.config = config;

      if (serialPort.openRead()) {
        print('Port opened');
        tested = true;
      } else {
        print('Port not opened');
        setState(() {
          testing = false;
        });
        return;
      }
      var reader = SerialPortReader(serialPort!);
      reader!.stream.listen(
        (data) {
          String nmeaSentence = String.fromCharCodes(data);

          // split nmeaSentances in Lines
          List<String> lines = nmeaSentence.split('\$');

          // Clear empty lines
          lines.removeWhere((element) => element.isEmpty);

          setState(() {
            nmeaSentences.addAll(lines);
          });

          // Step 2: Iterate through each line
          for (String line in lines) {
            // Step 3: Check if the line starts with "GNRMC"
            if (line.startsWith('GNRMC')) {
              print(line);
              // Step 4: Parse the line
              _getLatLonFromGNRMC(line);
            }
          }
        },
        onDone: () {
          print('Done');
        },
        onError: (e) {
          print('$e');
          setState(() {
            testing = false;
          });
        },
      );
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
                  if (value == null || testing) return;
                  setState(() {
                    selectedPort = value;
                  });
                },
                items:
                    availablePorts.map<DropdownMenuItem<String>>((dynamic value) {
                      return DropdownMenuItem<String>(value: value.toString(), child: Text(value.toString()));
                    }).toList(), // Explicitly specify the type
              ),
              IconButton(icon: Icon(Icons.refresh), onPressed: _getAvailablePorts),
            ],
          ),
        ),
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
            items:
                baudeRates.map<DropdownMenuItem<int>>((dynamic value) {
                  return DropdownMenuItem<int>(value: value, child: Text(value.toString()));
                }).toList(), // Explicitly specify the type
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (testing) ElevatedButton(onPressed: _cancelTesting, child: Text('Cancel testing')) else ElevatedButton(onPressed: baudeRate != null ? _testConnection : null, child: Text('TEST connection')),
            ElevatedButton(onPressed: tested ? _saveDevice : null, child: Text('SAVE')),
          ],
        ),
        Divider(),
        // nmeaSentences
        if (nmeaSentences.isNotEmpty)
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: nmeaSentences.length,
              itemBuilder: (context, index) {
                return ListTile(title: Text(nmeaSentences[index].toString()));
              },
            ),
          ),
      ],
    );
  }
}
