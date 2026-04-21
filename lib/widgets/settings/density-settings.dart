import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/grid_density_service.dart';

/// Settings card for grid density (normal vs. dense row height).
/// Dense mode reduces row height and cell padding, optimised for pen/stylus use on tablets.
class DensitySettings extends StatefulWidget {
  const DensitySettings({super.key});

  @override
  State<DensitySettings> createState() => _DensitySettingsState();
}

class _DensitySettingsState extends State<DensitySettings> {
  bool _dense = GridDensityService.isDense;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: const Icon(Icons.density_small),
      title: const Text('Kompakter Tabellenmodus'),
      subtitle: Text(_dense ? 'Reduzierte Zeilenhöhe (für Stift/Tablet)' : 'Standard-Zeilenhöhe'),
      value: _dense,
      onChanged: (value) async {
        await GridDensityService.setDense(value);
        setState(() => _dense = value);
      },
    );
  }
}
