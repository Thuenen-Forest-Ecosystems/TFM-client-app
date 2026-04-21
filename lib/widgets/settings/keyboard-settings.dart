import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/floating_num_keyboard.dart';

/// Settings card that lets the user choose between the system keyboard and the
/// custom floating numeric keyboard for integer/number fields.
///
/// Only rendered on Android, iOS, and Windows – the platforms where the
/// floating keyboard is available.
class KeyboardSettings extends StatefulWidget {
  const KeyboardSettings({super.key});

  @override
  State<KeyboardSettings> createState() => _KeyboardSettingsState();
}

class _KeyboardSettingsState extends State<KeyboardSettings> {
  bool _enabled = FloatingNumKeyboard.userEnabled;

  bool get _platformSupported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS || Platform.isWindows;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_platformSupported) {
      return const ListTile(
        leading: Icon(Icons.keyboard_hide),
        title: Text('Schwimmendes Nummernfeld'),
        subtitle: Text('Nicht verfügbar auf dieser Plattform.'),
        enabled: false,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.dialpad),
          title: const Text('Schwimmendes Nummernfeld'),
          subtitle: Text(
            _enabled ? 'Zahlentastatur bei Zahlenfeldern' : 'System-Tastatur bei Zahlenfeldern',
          ),
          value: _enabled,
          onChanged: (value) async {
            await FloatingNumKeyboard.setEnabled(value);
            setState(() => _enabled = value);
          },
        ),
      ],
    );
  }
}
