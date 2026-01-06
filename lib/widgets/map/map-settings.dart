import 'package:flutter/material.dart';

/// Modal bottom sheet for map settings
/// Allows user to toggle basemap layers (OpenCycleMap, DOP/aerial imagery)
/// and control tree diameter multiplier
class MapSettingsModal extends StatefulWidget {
  final Set<String> selectedBasemaps;
  final double treeDiameterMultiplier;
  final Function(Set<String>) onBasemapsChanged;
  final Function(double) onTreeDiameterMultiplierChanged;

  const MapSettingsModal({
    super.key,
    required this.selectedBasemaps,
    required this.treeDiameterMultiplier,
    required this.onBasemapsChanged,
    required this.onTreeDiameterMultiplierChanged,
  });

  /// Show the map settings modal
  static Future<void> show(
    BuildContext context, {
    required Set<String> selectedBasemaps,
    required double treeDiameterMultiplier,
    required Function(Set<String>) onBasemapsChanged,
    required Function(double) onTreeDiameterMultiplierChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      builder: (context) => MapSettingsModal(
        selectedBasemaps: selectedBasemaps,
        treeDiameterMultiplier: treeDiameterMultiplier,
        onBasemapsChanged: onBasemapsChanged,
        onTreeDiameterMultiplierChanged: onTreeDiameterMultiplierChanged,
      ),
    );
  }

  @override
  State<MapSettingsModal> createState() => _MapSettingsModalState();
}

class _MapSettingsModalState extends State<MapSettingsModal> {
  late Set<String> _selectedBasemaps;
  late double _treeDiameterMultiplier;

  @override
  void initState() {
    super.initState();
    _selectedBasemaps = Set.from(widget.selectedBasemaps);
    _treeDiameterMultiplier = widget.treeDiameterMultiplier;
  }

  void _toggleBasemap(String basemap, bool? value) {
    setState(() {
      if (value == true) {
        _selectedBasemaps.add(basemap);
      } else {
        _selectedBasemaps.remove(basemap);
      }
    });
    widget.onBasemapsChanged(_selectedBasemaps);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Basiskarten', style: Theme.of(context).textTheme.titleMedium),
          Card.outlined(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  title: const Text('OpenCycleMap (offline)'),
                  subtitle: const Text('Mittlere Zoomstufen'),
                  value: _selectedBasemaps.contains('opencycle'),
                  onChanged: (value) => _toggleBasemap('opencycle', value),
                ),
                CheckboxListTile(
                  title: const Text('Luftbilder (offline)'),
                  subtitle: const Text('nur höchste Zoomstufen'),
                  value: _selectedBasemaps.contains('dop'),
                  onChanged: (value) => _toggleBasemap('dop', value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Bäume', style: Theme.of(context).textTheme.titleMedium),
          Card.outlined(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Durchmesser-Multiplikator: ${_treeDiameterMultiplier.toStringAsFixed(1)}x',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _treeDiameterMultiplier,
                    min: 1.0,
                    max: 5.0,
                    divisions: 4,
                    label: '${_treeDiameterMultiplier.toStringAsFixed(1)}x',
                    onChanged: (value) {
                      setState(() {
                        _treeDiameterMultiplier = value;
                      });
                      widget.onTreeDiameterMultiplierChanged(value);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
