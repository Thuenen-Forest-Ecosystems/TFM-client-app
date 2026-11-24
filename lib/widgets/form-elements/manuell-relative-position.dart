import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';
import 'package:terrestrial_forest_monitor/providers/map_controller_provider.dart';
import 'package:terrestrial_forest_monitor/l10n/app_localizations.dart';

class ManuellRelativePosition extends StatefulWidget {
  final Map<String, dynamic>? formData;
  final Function(String, dynamic)? onFieldChanged;

  const ManuellRelativePosition({super.key, this.formData, this.onFieldChanged});

  @override
  State<ManuellRelativePosition> createState() => _ManuellRelativePositionState();
}

class _ManuellRelativePositionState extends State<ManuellRelativePosition> {
  final List<NavigationStep> _steps = [];
  final _azimuthController = TextEditingController();
  final _distanceController = TextEditingController();

  LatLng? _startPosition;
  LatLng? _currentCalculatedPosition;
  LatLng? _destinationPosition;
  double? _remainingAzimuth;
  double? _remainingDistance;

  @override
  void initState() {
    super.initState();
    _loadStepsFromFormData();
    _updatePositions();
  }

  @override
  void didUpdateWidget(ManuellRelativePosition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.formData != oldWidget.formData) {
      _loadStepsFromFormData();
    }
    _updatePositions();
  }

  void _loadStepsFromFormData() {
    final data = widget.formData;
    if (data != null && data['navigation_steps'] is List) {
      _steps.clear();
      for (var step in data['navigation_steps']) {
        if (step is Map) {
          _steps.add(
            NavigationStep(
              azimuth: (step['azimuth'] as num?)?.toDouble(),
              distance: (step['distance'] as num?)?.toDouble(),
            ),
          );
        }
      }
      setState(() {});
    }
  }

  void _saveStepsToFormData() {
    /*final stepsData = _steps.map((step) {
      return {'azimuth': step.azimuth, 'distance': step.distance};
    }).toList();
    widget.onFieldChanged?.call('navigation_steps', stepsData);*/
  }

  void _updatePositions() {
    final gpsProvider = Provider.of<GpsPositionProvider>(context, listen: false);
    final mapProvider = Provider.of<MapControllerProvider>(context, listen: false);

    // Get start position from navigation start (set by previous-positions-navigation)
    // or fall back to latest GPS measurement
    if (mapProvider.navigationStart != null) {
      _startPosition = mapProvider.navigationStart;
    } else if (gpsProvider.lastPosition != null) {
      _startPosition = LatLng(
        gpsProvider.lastPosition!.latitude,
        gpsProvider.lastPosition!.longitude,
      );
    } else {
      _startPosition = null;
    }

    // Get destination from navigation target (set by previous-positions-navigation)
    _destinationPosition = mapProvider.navigationTarget;

    // Calculate current position based on navigation steps
    if (_startPosition != null && _steps.isNotEmpty) {
      _currentCalculatedPosition = _calculatePositionFromSteps(_startPosition!, _steps);
    } else {
      _currentCalculatedPosition = _startPosition;
    }

    // Calculate remaining azimuth and distance to destination
    if (_currentCalculatedPosition != null && _destinationPosition != null) {
      final result = _calculateAzimuthDistance(_currentCalculatedPosition!, _destinationPosition!);
      _remainingAzimuth = result['azimuth'];
      _remainingDistance = result['distance'];
    } else {
      _remainingAzimuth = null;
      _remainingDistance = null;
    }

    if (mounted) {
      setState(() {});
    }
  }

  LatLng _calculatePositionFromSteps(LatLng start, List<NavigationStep> steps) {
    LatLng current = start;
    final distance = Distance();

    for (var step in steps) {
      if (step.azimuth != null && step.distance != null) {
        // Calculate new position using azimuth and distance
        current = distance.offset(current, step.distance!, step.azimuth!);
      }
    }

    return current;
  }

  Map<String, double> _calculateAzimuthDistance(LatLng from, LatLng to) {
    final distance = Distance();
    final distanceMeters = distance.as(LengthUnit.Meter, from, to);
    final azimuth = distance.bearing(from, to);

    return {'azimuth': azimuth < 0 ? azimuth + 360 : azimuth, 'distance': distanceMeters};
  }

  void _addNavigationStep() {
    final azimuth = double.tryParse(_azimuthController.text);
    final distanceValue = double.tryParse(_distanceController.text);

    if (azimuth == null || distanceValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.manuellRelativePositionInvalidValues)),
      );
      return;
    }

    if (azimuth < 0 || azimuth >= 400) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.manuellRelativePositionAzimuthRange)));
      return;
    }

    setState(() {
      _steps.add(NavigationStep(azimuth: azimuth, distance: distanceValue));
      _azimuthController.clear();
      _distanceController.clear();
    });

    _saveStepsToFormData();
    _updatePositions();
  }

  void _removeNavigationStep(int index) {
    setState(() {
      _steps.removeAt(index);
    });
    _saveStepsToFormData();
    _updatePositions();
  }

  /*void _clearAllSteps() {
    setState(() {
      _steps.clear();
    });
    _saveStepsToFormData();
    _updatePositions();
  }*/

  void _focusLocation(LatLng? position, String positionLabel) {
    if (position == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.manuellRelativePositionNothingToFocus(positionLabel))));
      return;
    }

    final mapProvider = Provider.of<MapControllerProvider>(context, listen: false);
    mapProvider.moveToLocation(position, zoom: 18.0, animate: true);
  }

  @override
  void dispose() {
    _azimuthController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<GpsPositionProvider, MapControllerProvider>(
      builder: (context, gpsProvider, mapProvider, child) {
        // Update positions when providers change
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updatePositions();
        });

        return Card(
          margin: const EdgeInsets.all(8.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Start position
                _buildStartPositionSection(gpsProvider),
                const SizedBox(height: 16),

                // List of navigation steps
                if (_steps.isNotEmpty) _buildStepsList(),
                const SizedBox(height: 16),

                // Input fields for new step
                _buildInputSection(),
                const SizedBox(height: 16),

                // Remaining distance display
                if (_remainingAzimuth != null && _remainingDistance != null) ...[
                  _buildRemainingDistanceCard(),
                  const SizedBox(height: 16),
                ],

                // Destination position
                _buildDestinationSection(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStartPositionSection(GpsPositionProvider gpsProvider) {
    final mapProvider = Provider.of<MapControllerProvider>(context, listen: false);
    final hasNavigationStart = mapProvider.navigationStart != null;
    final l10n = AppLocalizations.of(context)!;
    final startLabel = hasNavigationStart
        ? mapProvider.navigationStartLabel ?? l10n.manuellRelativePositionSelectedPosition
        : l10n.manuellRelativePositionGpsPosition;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_startPosition != null ? Icons.check_circle : Icons.warning, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.manuellRelativePositionStartPosition(_startPosition != null ? startLabel : l10n.manuellRelativePositionNoData),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Spacer(),
              IconButton(
                onPressed: () => _focusLocation(_currentCalculatedPosition, l10n.manuellRelativePositionPosition),
                icon: const Icon(Icons.my_location, size: 20),
              ),
            ],
          ),
          if (_startPosition != null) ...[
            const SizedBox(height: 4),
            Text(
              'Lat: ${_startPosition!.latitude.toStringAsFixed(6)}, '
              'Lon: ${_startPosition!.longitude.toStringAsFixed(6)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDestinationSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_destinationPosition != null ? Icons.check_circle : Icons.warning, size: 20),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.manuellRelativePositionDestination, style: const TextStyle(fontWeight: FontWeight.bold)),
              Spacer(),
              _destinationPosition == null
                  ? Chip(label: Text(AppLocalizations.of(context)!.manuellRelativePositionSetDestination))
                  : IconButton(
                      onPressed: () => _focusLocation(_destinationPosition, AppLocalizations.of(context)!.manuellRelativePositionDestination),
                      icon: const Icon(Icons.my_location, size: 20),
                    ),
            ],
          ),
          if (_destinationPosition != null) ...[
            const SizedBox(height: 4),
            Text(
              'Lat: ${_destinationPosition!.latitude.toStringAsFixed(6)}, '
              'Lon: ${_destinationPosition!.longitude.toStringAsFixed(6)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRemainingDistanceCard() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildMetricColumn(
          label: AppLocalizations.of(context)!.manuellRelativePositionAzimuth,
          value: '${_remainingAzimuth!.round()} gon',
        ),
        Container(width: 1, height: 40, color: Colors.green.shade300),
        _buildMetricColumn(
          label: AppLocalizations.of(context)!.manuellRelativePositionDistance,
          value: '${_remainingDistance!.toStringAsFixed(1)} m',
        ),
      ],
    );
  }

  Widget _buildMetricColumn({required String label, required String value}) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /*const Text(
          'Neue Navigationsstufe hinzufügen',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),*/
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _azimuthController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: AppLocalizations.of(context)!.manuellRelativePositionAzimuthGon,
                  hintText: '0-400',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _distanceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: AppLocalizations.of(context)!.manuellRelativePositionDistanceMeters,
                  hintText: AppLocalizations.of(context)!.manuellRelativePositionMetersHint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(onPressed: _addNavigationStep, icon: const Icon(Icons.add_circle, size: 32)),
          ],
        ),
      ],
    );
  }

  Widget _buildStepsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /*Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Navigationsstufen (${_steps.length})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            if (_steps.isNotEmpty)
              TextButton.icon(
                onPressed: _clearAllSteps,
                icon: const Icon(Icons.delete_sweep, size: 18),
                label: const Text('Alle löschen'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
          ],
        ),
        const SizedBox(height: 8),*/
        Container(
          decoration: BoxDecoration(
            //border: Border.all(color: Colors.grey.shade300),
            //borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _steps.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade300),
            itemBuilder: (context, index) {
              final step = _steps[index];
              return ListTile(
                leading: CircleAvatar(radius: 20, child: Text('${index + 1}')),
                title: Row(
                  children: [
                    Text('${step.azimuth?.round() ?? "?"} gon'),
                    const SizedBox(width: 16),
                    Text('${step.distance?.toStringAsFixed(1) ?? "?"} m'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _focusLocation(
                        _calculatePositionFromSteps(_startPosition!, _steps.sublist(0, index + 1)),
                        AppLocalizations.of(context)!.manuellRelativePositionAfterStep(index + 1),
                      ),
                      icon: const Icon(Icons.my_location, size: 20),
                    ),
                    IconButton(
                      onPressed: () => _removeNavigationStep(index),
                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        /*const SizedBox(height: 8),
        if (_currentCalculatedPosition != null && _startPosition != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.my_location, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text(
                      'Aktuelle berechnete Position',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Lat ${_currentCalculatedPosition!.latitude.toStringAsFixed(6)}, '
                  'Lon ${_currentCalculatedPosition!.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(fontSize: 11),
                ),
                if (_destinationPosition != null &&
                    _remainingAzimuth != null &&
                    _remainingDistance != null) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.explore, size: 14, color: Colors.blue.shade700),
                          const SizedBox(width: 4),
                          Text(
                            '${_remainingAzimuth!.round()} gon',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.straighten, size: 14, color: Colors.orange.shade700),
                          const SizedBox(width: 4),
                          Text(
                            '${_remainingDistance!.toStringAsFixed(1)} m',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),*/
      ],
    );
  }
}

class NavigationStep {
  final double? azimuth;
  final double? distance;

  NavigationStep({this.azimuth, this.distance});
}
