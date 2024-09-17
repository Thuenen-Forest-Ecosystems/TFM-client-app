import 'dart:ffi';

import 'package:flutter/material.dart';
import 'dart:convert'; // Import for UTF-8 decoding
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:nmea/nmea.dart' as nmea;

class LibSerial extends StatefulWidget {
  @override
  _LibSerialState createState() => _LibSerialState();
}

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

class _LibSerialState extends State<LibSerial> {
  var availablePorts = [];

  @override
  void initState() {
    super.initState();
    initPorts();
  }

  void initPorts() {
    setState(() => availablePorts = SerialPort.availablePorts);
  }

  double ConvertDegreeAngleToDouble(double degrees, double minutes, double seconds) {
    //Decimal degrees =
    //   whole number of degrees,
    //   plus minutes divided by 60,
    //   plus seconds divided by 3600
    return degrees + (minutes / 60) + (seconds / 3600);
  }

  void read() {
    print(availablePorts[2]);

    SerialPort serialPort = SerialPort(availablePorts[2]);
    try {
      SerialPortConfig config = serialPort.config;
      config.baudRate = 9600;
      serialPort.config = config;

      if (serialPort.openRead()) {
        print('Port opened');
      } else {
        print('Port not opened');
      }
      SerialPortReader reader = SerialPortReader(serialPort, timeout: 10000);

      reader.stream.listen((data) {
        final decodedData = utf8.decode(data);
        List<String> lines = decodedData.split("\n");
        lines.forEach((line) {
          if (line.startsWith('\$GNRMC')) {
            List<String> decodedDataArray = line.split(',');
            if (decodedDataArray.length < 6) {
              print(line);
              return;
            }
            String latitude = decodedDataArray[3]; // latl
            //String quadrant = decodedDataArray[4]; // quadrant

            int position = latitude.indexOf('.');

            double hours = double.parse(latitude.substring(0, position - 2));
            double minutes = double.parse(latitude.substring(position - 2));

            print(line);

            double dec = ConvertDegreeAngleToDouble(hours, minutes, 0);
            print('Latitude:$dec');

            //--- Longitude
            String longitude = decodedDataArray[5]; // latl
            int positionLong = longitude.indexOf('.');
            double hoursLong = double.parse(longitude.substring(0, positionLong - 2));
            double minutesLong = double.parse(longitude.substring(positionLong - 2));
            double longDec = ConvertDegreeAngleToDouble(hoursLong, minutesLong, 0);
            print('Long: $longDec');
          }
        });
      });
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter Serial Port example'),
        ),
        body: Scrollbar(
          child: ListView(
            children: [
              for (final address in availablePorts)
                Builder(builder: (context) {
                  final port = SerialPort(address);
                  return ExpansionTile(
                    title: Text(address),
                    children: [
                      CardListTile('Description', port.description),
                      CardListTile('Transport', port.transport.toTransport()),
                      CardListTile('USB Bus', port.busNumber?.toPadded()),
                      CardListTile('USB Device', port.deviceNumber?.toPadded()),
                      CardListTile('Vendor ID', port.vendorId?.toHex()),
                      CardListTile('Product ID', port.productId?.toHex()),
                      CardListTile('Manufacturer', port.manufacturer),
                      CardListTile('Product Name', port.productName),
                      CardListTile('Serial Number', port.serialNumber),
                      CardListTile('MAC Address', port.macAddress),
                    ],
                  );
                }),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: read,
          child: Icon(Icons.refresh), //initPorts,
        ),
      ),
    );
  }
}

class CardListTile extends StatelessWidget {
  final String name;
  final String? value;

  CardListTile(this.name, this.value);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(value ?? 'N/A'),
        subtitle: Text(name),
      ),
    );
  }
}
