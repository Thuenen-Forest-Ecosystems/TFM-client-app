import 'package:flutter/material.dart';

/// Modal bottom sheet for map settings
/// Allows user to toggle basemap layers (OpenCycleMap, DOP/aerial imagery),
/// control tree diameter multiplier, and configure tree labels
class MapSettingsModal extends StatefulWidget {
  final Set<String> selectedBasemaps;
  final double treeDiameterMultiplier;
  final bool showTreeLabels;
  final Set<String> treeLabelFields;
  final Function(Set<String>) onBasemapsChanged;
  final Function(double) onTreeDiameterMultiplierChanged;
  final Function(bool) onShowTreeLabelsChanged;
  final Function(Set<String>) onTreeLabelFieldsChanged;

  const MapSettingsModal({
    super.key,
    required this.selectedBasemaps,
    required this.treeDiameterMultiplier,
    required this.showTreeLabels,
    required this.treeLabelFields,
    required this.onBasemapsChanged,
    required this.onTreeDiameterMultiplierChanged,
    required this.onShowTreeLabelsChanged,
    required this.onTreeLabelFieldsChanged,
  });

  /// Show the map settings modal
  static Future<void> show(
    BuildContext context, {
    required Set<String> selectedBasemaps,
    required double treeDiameterMultiplier,
    required bool showTreeLabels,
    required Set<String> treeLabelFields,
    required Function(Set<String>) onBasemapsChanged,
    required Function(double) onTreeDiameterMultiplierChanged,
    required Function(bool) onShowTreeLabelsChanged,
    required Function(Set<String>) onTreeLabelFieldsChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      builder: (context) => MapSettingsModal(
        selectedBasemaps: selectedBasemaps,
        treeDiameterMultiplier: treeDiameterMultiplier,
        showTreeLabels: showTreeLabels,
        treeLabelFields: treeLabelFields,
        onBasemapsChanged: onBasemapsChanged,
        onTreeDiameterMultiplierChanged: onTreeDiameterMultiplierChanged,
        onShowTreeLabelsChanged: onShowTreeLabelsChanged,
        onTreeLabelFieldsChanged: onTreeLabelFieldsChanged,
      ),
    );
  }

  @override
  State<MapSettingsModal> createState() => _MapSettingsModalState();
}

class _MapSettingsModalState extends State<MapSettingsModal> {
  late Set<String> _selectedBasemaps;
  late double _treeDiameterMultiplier;
  late bool _showTreeLabels;
  late Set<String> _treeLabelFields;

  @override
  void initState() {
    super.initState();
    _selectedBasemaps = Set.from(widget.selectedBasemaps);
    _treeDiameterMultiplier = widget.treeDiameterMultiplier;
    _showTreeLabels = widget.showTreeLabels;
    _treeLabelFields = Set.from(widget.treeLabelFields);
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

  void _toggleLabelField(String field, bool? value) {
    setState(() {
      if (value == true) {
        _treeLabelFields.add(field);
      } else {
        _treeLabelFields.remove(field);
      }
    });
    widget.onTreeLabelFieldsChanged(_treeLabelFields);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
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
                    const Divider(),
                    SwitchListTile(
                      title: const Text('Baumbeschriftungen anzeigen'),
                      value: _showTreeLabels,
                      onChanged: (value) {
                        setState(() {
                          _showTreeLabels = value;
                        });
                        widget.onShowTreeLabelsChanged(value);
                      },
                    ),
                    if (_showTreeLabels) ...[
                      const Padding(
                        padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
                        child: Text(
                          'Anzuzeigende Felder:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                      CheckboxListTile(
                        title: const Text('Baumnummer'),
                        dense: true,
                        value: _treeLabelFields.contains('tree_number'),
                        onChanged: (value) => _toggleLabelField('tree_number', value),
                      ),
                      CheckboxListTile(
                        title: const Text('BHD (Durchmesser)'),
                        dense: true,
                        value: _treeLabelFields.contains('dbh'),
                        onChanged: (value) => _toggleLabelField('dbh', value),
                      ),
                      CheckboxListTile(
                        title: const Text('Baumart'),
                        dense: true,
                        value: _treeLabelFields.contains('tree_species'),
                        onChanged: (value) => _toggleLabelField('tree_species', value),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
