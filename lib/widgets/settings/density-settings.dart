import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    return SwitchListTile(
      secondary: const Icon(Icons.density_small),
      title: Text(l10n.densitySettingsCompactTable),
      subtitle: Text(_dense ? l10n.densitySettingsReducedRowHeight : l10n.densitySettingsStandardRowHeight),
      value: _dense,
      onChanged: (value) async {
        await GridDensityService.setDense(value);
        setState(() => _dense = value);
      },
    );
  }
}
