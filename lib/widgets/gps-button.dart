import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/services/utils.dart';
import 'package:terrestrial_forest_monitor/widgets/bluetooth/android-bluetooth-ble.dart';

class GpsButton extends StatefulWidget {
  const GpsButton({super.key});
  @override
  State<GpsButton> createState() => _GpsButtonState();
}

class _GpsButtonState extends State<GpsButton> {
  // Store the raw device data fetched from settings
  Map<String, dynamic> _savedDeviceSettings = {};
  bool _isLoadingSettings = true;

  @override
  void initState() {
    super.initState();
    _loadDeviceSettings();
  }

  // Fetch settings once and store the result
  Future<void> _loadDeviceSettings() async {
    try {
      final value = await getSettings('GNSSDevice');
      if (mounted && value != null) {
        setState(() {
          _savedDeviceSettings = jsonDecode(value['value']) as Map<String, dynamic>? ?? {};
          _isLoadingSettings = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoadingSettings = false; // Stop loading even if null/error
        });
      }
    } catch (e) {
      print("Error loading GNSS settings: $e");
      if (mounted) {
        setState(() {
          _isLoadingSettings = false; // Stop loading on error
        });
      }
    }
  }

  // Function to build menu items dynamically based on current provider state
  List<PopupMenuEntry> _buildMenuItems(BluetoothDevice? connectedDevice, bool listeningPosition) {
    List<PopupMenuEntry> items = [];
    List<PopupMenuEntry> savedDeviceItems = [];

    // Only include Bluetooth options if not on web
    if (!kIsWeb) {
      // Add Bluetooth header
      items.add(
        PopupMenuItem(
          value: 'bluetooth_header',
          enabled: false,
          child: ListTile(
            title: Text('BLUETOOTH'),
            trailing: IconButton(
              onPressed: () {
                _openGNSSDialog(context);
              },
              icon: Icon(Icons.add),
            ),
          ),
        ),
      );

      // Add saved Bluetooth devices
      if (_savedDeviceSettings.isNotEmpty) {
        for (var entry in _savedDeviceSettings.entries) {
          final deviceKey = entry.key;
          final deviceData = entry.value as Map<String, dynamic>; // Cast value to Map
          final platformName = deviceData['platformName'] ?? deviceKey;

          // Check if this saved device is the currently connected one
          if (connectedDevice != null && connectedDevice.remoteId.toString() == deviceKey) {
            savedDeviceItems.add(
              PopupMenuItem(
                value: deviceKey,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Icon(Icons.bluetooth), // Change color based on connection status
                  ), // Indicate connected
                  title: Text(platformName),
                  subtitle: Text('Verbunden'),
                ),
              ),
            );
          } else {
            // Item for a saved device that is NOT currently connected
            savedDeviceItems.add(
              PopupMenuItem(
                value: deviceKey, // Value is the device ID (key) to connect
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.bluetooth), // Change color based on connection status
                  ),
                  title: Text(platformName),
                ),
              ),
            );
          }
        }
      }

      items.addAll(savedDeviceItems);

      // Add divider if we have any Bluetooth items
      if (items.isNotEmpty) {
        items.add(PopupMenuDivider());
      }
    }

    // Internal GPS is always available
    items.add(PopupMenuItem(value: 'gps', child: ListTile(leading: CircleAvatar(backgroundColor: listeningPosition ? Theme.of(context).colorScheme.primary : Colors.grey, child: const Icon(Icons.gps_fixed)), title: Text('Internal GPS'))));

    return items;
  }

  Future<void> _openGNSSDialog(BuildContext context) {
    // Original dialog for non-web platforms
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(content: SingleChildScrollView(child: SizedBox(width: 400, child: AndroidBluetoothBle(autoSearch: true))));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 20),
      child: Consumer<GpsPositionProvider>(
        builder: (context, GpsPositionProvider gps, child) {
          // Build the menu items here using the latest provider state (gps.connectedDevice)
          final List<PopupMenuEntry> currentMenuItems =
              _isLoadingSettings
                  ? [PopupMenuItem(enabled: false, child: Text('Loading devices...'))] // Show loading state
                  : _buildMenuItems(gps.connectedDevice, gps.listeningPosition); // Pass current connected device

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Display connection status or NMEA data if available
              PopupMenuButton(
                tooltip: 'GPS Selection',
                offset: Offset(0, 40.0),
                // Use the dynamically built menu items
                itemBuilder: (context) => currentMenuItems,
                onSelected: (value) {
                  // Defer actions slightly to avoid issues during build/event handling
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    if (value == 'gps') {
                      context.read<GpsPositionProvider>().startInternalGps();
                    } else if (value == 'stop_all') {
                      context.read<GpsPositionProvider>().stopAll();
                    } else if (value != 'bluetooth_header') {
                      context.read<GpsPositionProvider>().toggleDeviceFromId(value as String);
                    }
                  });
                },

                // Change icon based on state
                icon:
                    gps.isConnecting
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.0))
                        : Icon(
                          gps.connectedDevice != null
                              ? Icons.bluetooth
                              : gps.listeningPosition
                              ? Icons.gps_fixed
                              : Icons.satellite_alt, // Default/Idle icon
                          color: gps.connectedDevice == null && !gps.listeningPosition ? Colors.grey : Colors.black, // Change color based on connection status
                        ),
              ),
            ],
          );
        },
      ),
    );
  }
}
