// Stub implementation for platforms that don't support serial port
// This file is used when flutter_libserialport is not available (Android, iOS, Web)

class SerialPort {
  SerialPort(String portName);

  static List<String> get availablePorts => [];
  static dynamic get lastError => null;

  String? get description => null;

  bool openReadWrite() => false;

  SerialPortConfig get config => SerialPortConfig();
  set config(SerialPortConfig value) {}

  void close() {}
  void dispose() {}
}

class SerialPortConfig {
  int baudRate = 9600;
  int bits = 8;
  int stopBits = 1;
  SerialPortParity parity = SerialPortParity.none;
}

enum SerialPortParity { none, odd, even }

class SerialPortReader {
  SerialPortReader(SerialPort port);

  Stream<List<int>> get stream => const Stream.empty();
}
