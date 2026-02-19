import 'package:flutter/material.dart';

/// Modal bottom sheet for map settings
/// Allows user to toggle basemap layers (OpenCycleMap, DOP/aerial imagery),
/// control tree diameter multiplier, and configure tree labels
class MapSettingsModal extends StatefulWidget {
  final Set<String> selectedBasemaps;
  final double treeDiameterMultiplier;
  final bool showTreeLabels;
  final Set<String> treeLabelFields;
  final bool showEdges;
  final bool showCrownCircles;
  final bool showClusterPolygons;
  final bool showProbekreise;
  final Function(Set<String>) onBasemapsChanged;
  final Function(double) onTreeDiameterMultiplierChanged;
  final Function(bool) onShowTreeLabelsChanged;
  final Function(Set<String>) onTreeLabelFieldsChanged;
  final Function(bool) onShowEdgesChanged;
  final Function(bool) onShowCrownCirclesChanged;
  final Function(bool) onShowClusterPolygonsChanged;
  final Function(bool) onShowProbekreiseChanged;

  const MapSettingsModal({
    super.key,
    required this.selectedBasemaps,
    required this.treeDiameterMultiplier,
    required this.showTreeLabels,
    required this.treeLabelFields,
    required this.showEdges,
    required this.showCrownCircles,
    required this.showClusterPolygons,
    required this.showProbekreise,
    required this.onBasemapsChanged,
    required this.onTreeDiameterMultiplierChanged,
    required this.onShowTreeLabelsChanged,
    required this.onTreeLabelFieldsChanged,
    required this.onShowEdgesChanged,
    required this.onShowCrownCirclesChanged,
    required this.onShowClusterPolygonsChanged,
    required this.onShowProbekreiseChanged,
  });

  /// Show the map settings modal
  static Future<void> show(
    BuildContext context, {
    required Set<String> selectedBasemaps,
    required double treeDiameterMultiplier,
    required bool showTreeLabels,
    required Set<String> treeLabelFields,
    required bool showEdges,
    required bool showCrownCircles,
    required bool showClusterPolygons,
    required bool showProbekreise,
    required Function(Set<String>) onBasemapsChanged,
    required Function(double) onTreeDiameterMultiplierChanged,
    required Function(bool) onShowTreeLabelsChanged,
    required Function(Set<String>) onTreeLabelFieldsChanged,
    required Function(bool) onShowEdgesChanged,
    required Function(bool) onShowCrownCirclesChanged,
    required Function(bool) onShowClusterPolygonsChanged,
    required Function(bool) onShowProbekreiseChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      builder: (context) => MapSettingsModal(
        selectedBasemaps: selectedBasemaps,
        treeDiameterMultiplier: treeDiameterMultiplier,
        showTreeLabels: showTreeLabels,
        treeLabelFields: treeLabelFields,
        showEdges: showEdges,
        showCrownCircles: showCrownCircles,
        showClusterPolygons: showClusterPolygons,
        showProbekreise: showProbekreise,
        onBasemapsChanged: onBasemapsChanged,
        onTreeDiameterMultiplierChanged: onTreeDiameterMultiplierChanged,
        onShowTreeLabelsChanged: onShowTreeLabelsChanged,
        onTreeLabelFieldsChanged: onTreeLabelFieldsChanged,
        onShowEdgesChanged: onShowEdgesChanged,
        onShowCrownCirclesChanged: onShowCrownCirclesChanged,
        onShowClusterPolygonsChanged: onShowClusterPolygonsChanged,
        onShowProbekreiseChanged: onShowProbekreiseChanged,
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
  late bool _showEdges;
  late bool _showCrownCircles;
  late bool _showClusterPolygons;
  late bool _showProbekreise;

  @override
  void initState() {
    super.initState();
    _selectedBasemaps = Set.from(widget.selectedBasemaps);
    _treeDiameterMultiplier = widget.treeDiameterMultiplier;
    _showTreeLabels = widget.showTreeLabels;
    _treeLabelFields = Set.from(widget.treeLabelFields);
    _showEdges = widget.showEdges;
    _showCrownCircles = widget.showCrownCircles;
    _showClusterPolygons = widget.showClusterPolygons;
    _showProbekreise = widget.showProbekreise;
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
            Text('Baumdarstellung', style: Theme.of(context).textTheme.titleMedium),
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
                      title: const Text('Beschriftungen anzeigen'),
                      value: _showTreeLabels,
                      onChanged: (value) {
                        setState(() {
                          _showTreeLabels = value;
                        });
                        widget.onShowTreeLabelsChanged(value);
                      },
                    ),
                    if (_showTreeLabels) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              label: const Text('Baumnummer'),
                              selected: _treeLabelFields.contains('tree_number'),
                              onSelected: (value) => _toggleLabelField('tree_number', value),
                              selectedColor: Theme.of(context).colorScheme.primary,
                            ),
                            FilterChip(
                              label: const Text('BHD'),
                              selected: _treeLabelFields.contains('dbh'),
                              onSelected: (value) => _toggleLabelField('dbh', value),
                              selectedColor: Theme.of(context).colorScheme.primary,
                            ),
                            FilterChip(
                              label: const Text('Baumart (Code)'),
                              selected: _treeLabelFields.contains('tree_species_code'),
                              onSelected: (value) => _toggleLabelField('tree_species_code', value),
                              selectedColor: Theme.of(context).colorScheme.primary,
                            ),
                            FilterChip(
                              label: const Text('Baumart (Name)'),
                              selected: _treeLabelFields.contains('tree_species_name'),
                              onSelected: (value) => _toggleLabelField('tree_species_name', value),
                              selectedColor: Theme.of(context).colorScheme.primary,
                            ),
                            FilterChip(
                              label: const Text('Azimut'),
                              selected: _treeLabelFields.contains('azimuth'),
                              onSelected: (value) => _toggleLabelField('azimuth', value),
                              selectedColor: Theme.of(context).colorScheme.primary,
                            ),
                            FilterChip(
                              label: const Text('Distanz'),
                              selected: _treeLabelFields.contains('distance'),
                              onSelected: (value) => _toggleLabelField('distance', value),
                              selectedColor: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('Ebenen', style: Theme.of(context).textTheme.titleMedium),
            ),
            Card.outlined(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    title: const Text('Ränder'),
                    value: _showEdges,
                    onChanged: (value) {
                      setState(() => _showEdges = value ?? true);
                      widget.onShowEdgesChanged(_showEdges);
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Grenzkreise'),
                    subtitle: const Text('basierend auf BHD'),
                    value: _showCrownCircles,
                    onChanged: (value) {
                      setState(() => _showCrownCircles = value ?? true);
                      widget.onShowCrownCirclesChanged(_showCrownCircles);
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Trakt'),
                    subtitle: const Text('Umrisse der Trakte'),
                    value: _showClusterPolygons,
                    onChanged: (value) {
                      setState(() => _showClusterPolygons = value ?? true);
                      widget.onShowClusterPolygonsChanged(_showClusterPolygons);
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Probekreise'),
                    subtitle: const Text('5 m · 10 m · 25 m Referenzkreise'),
                    value: _showProbekreise,
                    onChanged: (value) {
                      setState(() => _showProbekreise = value ?? true);
                      widget.onShowProbekreiseChanged(_showProbekreise);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
          ],
        ),
      ),
    );
  }
}
