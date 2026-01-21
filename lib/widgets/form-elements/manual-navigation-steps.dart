import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/providers/map_controller_provider.dart';

class ManualNavigationSteps extends StatefulWidget {
  final LatLng? startPosition;
  final LatLng? targetPosition;
  final ValueChanged<Map<String, double>?>? onNavigationCalculated;
  final ValueChanged<List<LatLng>?>? onStepPositionsCalculated;

  const ManualNavigationSteps({
    super.key,
    this.startPosition,
    this.targetPosition,
    this.onNavigationCalculated,
    this.onStepPositionsCalculated,
  });

  @override
  State<ManualNavigationSteps> createState() => _ManualNavigationStepsState();
}

class _ManualNavigationStepsState extends State<ManualNavigationSteps> {
  final List<NavigationStep> _steps = [];
  final _azimuthController = TextEditingController();
  final _distanceController = TextEditingController();
  final _azimuthFocusNode = FocusNode();
  bool _isExpanded = false;

  @override
  void dispose() {
    _azimuthController.dispose();
    _distanceController.dispose();
    _azimuthFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ManualNavigationSteps oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If start or target position changed, recalculate step positions
    if (oldWidget.startPosition != widget.startPosition ||
        oldWidget.targetPosition != widget.targetPosition) {
      // Recalculate and notify parent if we have steps
      if (_steps.isNotEmpty) {
        _notifyNavigationCalculated();
      }
    }
  }

  LatLng? _calculateCurrentPosition() {
    if (widget.startPosition == null || _steps.isEmpty) {
      return widget.startPosition;
    }

    LatLng current = widget.startPosition!;
    final distance = Distance();

    for (var step in _steps) {
      if (step.azimuth != null && step.distance != null) {
        // Convert gon to degrees (gon * 360/400)
        final azimuthDegrees = step.azimuth! * (360 / 400);
        current = distance.offset(current, step.distance!, azimuthDegrees);
      }
    }

    return current;
  }

  Map<String, double>? _calculateRemainingToTarget() {
    final currentPos = _calculateCurrentPosition();
    if (currentPos == null || widget.targetPosition == null) {
      return null;
    }

    final distance = Distance();
    final distanceMeters = distance.as(LengthUnit.Meter, currentPos, widget.targetPosition!);
    final azimuthDegrees = distance.bearing(currentPos, widget.targetPosition!);

    // Convert degrees to gon (degrees * 400/360)
    final azimuthGon = (azimuthDegrees < 0 ? azimuthDegrees + 360 : azimuthDegrees) * (400 / 360);

    return {'azimuth': azimuthGon, 'distance': distanceMeters};
  }

  Map<String, double>? _calculateTotalNavigation() {
    if (widget.startPosition == null || widget.targetPosition == null) {
      return null;
    }

    // Calculate total distance from all steps
    double totalDistance = 0.0;
    for (var step in _steps) {
      if (step.distance != null) {
        totalDistance += step.distance!;
      }
    }

    // Get remaining distance and bearing from current position to target
    final remaining = _calculateRemainingToTarget();
    if (remaining != null) {
      totalDistance += remaining['distance']!;
      return {'azimuth': remaining['azimuth']!, 'distance': totalDistance};
    }

    return null;
  }

  void _notifyNavigationCalculated() {
    if (widget.onNavigationCalculated != null) {
      widget.onNavigationCalculated!(_calculateTotalNavigation());
    }
    if (widget.onStepPositionsCalculated != null) {
      widget.onStepPositionsCalculated!(_calculateAllStepPositions());
    }
  }

  List<LatLng>? _calculateAllStepPositions() {
    if (widget.startPosition == null || _steps.isEmpty) {
      return null;
    }

    final List<LatLng> positions = [widget.startPosition!];
    LatLng current = widget.startPosition!;
    final distance = Distance();

    for (var step in _steps) {
      if (step.azimuth != null && step.distance != null) {
        // Convert gon to degrees (gon * 360/400)
        final azimuthDegrees = step.azimuth! * (360 / 400);
        current = distance.offset(current, step.distance!, azimuthDegrees);
        positions.add(current);
      }
    }

    return positions;
  }

  void _addNavigationStep() {
    final azimuth = double.tryParse(_azimuthController.text);
    final distanceValue = double.tryParse(_distanceController.text);

    if (azimuth == null || distanceValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte gültige Werte für Azimut und Entfernung eingeben')),
      );
      return;
    }

    if (azimuth < 0 || azimuth >= 400) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Azimut muss zwischen 0 und 400 Gon liegen')));
      return;
    }

    setState(() {
      _steps.add(NavigationStep(azimuth: azimuth, distance: distanceValue));
      _azimuthController.clear();
      _distanceController.clear();
    });

    // Update map line to show current calculated position
    _updateMapLine();

    // Notify parent of navigation calculation
    _notifyNavigationCalculated();

    // Focus back on azimuth field
    _azimuthFocusNode.requestFocus();
  }

  void _removeNavigationStep(int index) {
    setState(() {
      _steps.removeAt(index);
    });
    _updateMapLine();
    _notifyNavigationCalculated();
  }

  void _updateMapLine() {
    final currentPos = _calculateCurrentPosition();
    if (currentPos != null && widget.targetPosition != null) {
      final mapProvider = context.read<MapControllerProvider>();
      mapProvider.showDistanceLine(currentPos, widget.targetPosition!);
    }
  }

  void _focusLocation(LatLng? position) {
    if (position == null) return;
    final mapProvider = context.read<MapControllerProvider>();
    mapProvider.moveToLocation(position, zoom: 18.0, animate: true);
  }

  @override
  Widget build(BuildContext context) {
    final canNavigate = widget.startPosition != null && widget.targetPosition != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(height: 10.0, width: 1, color: Colors.grey),

        // Steps list cards
        if (_steps.isNotEmpty) ...[
          ...List.generate(_steps.length, (index) {
            final step = _steps[index];
            return Column(
              children: [
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      child: Text('${index + 1}', style: const TextStyle(fontSize: 12)),
                    ),
                    title: Row(
                      children: [
                        Text('${step.azimuth?.toStringAsFixed(1) ?? "?"} gon'),
                        const SizedBox(width: 16),
                        Text('${step.distance?.toStringAsFixed(1) ?? "?"} m'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () {
                            if (widget.startPosition != null) {
                              final pos = _calculatePositionFromSteps(
                                widget.startPosition!,
                                _steps.sublist(0, index + 1),
                              );
                              _focusLocation(pos);
                            }
                          },
                          icon: const Icon(Icons.my_location, size: 18),
                        ),
                        IconButton(
                          onPressed: () => _removeNavigationStep(index),
                          icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(height: 10.0, width: 1, color: Colors.grey),
              ],
            );
          }),
        ],

        // Toggle button
        Center(
          child: IconButton.outlined(
            onPressed: canNavigate ? () => setState(() => _isExpanded = !_isExpanded) : null,
            icon: Icon(
              _isExpanded ? Icons.expand_less : Icons.add_outlined,
              color: canNavigate ? null : Colors.grey,
            ),
            tooltip: canNavigate ? 'Manuelle Navigation' : 'Start und Ziel auswählen',
          ),
        ),

        if (_isExpanded && canNavigate) ...[
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  /*Row(
                    children: [
                      const Icon(Icons.route, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Manuelle Navigation',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const Spacer(),
                      if (_steps.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _steps.clear();
                            _updateMapLine();
                          }),
                          icon: const Icon(Icons.clear_all, size: 16),
                          label: const Text('Löschen'),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),*/

                  // Input fields
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _azimuthController,
                          focusNode: _azimuthFocusNode,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.right,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Azimut',
                            //hintText: '0-400',
                            suffix: Text('Gon'),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(40)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _distanceController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.right,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Entfernung',
                            //hintText: 'Meter',
                            suffix: Text('m'),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(40)),
                            ),
                          ),
                        ),
                      ),
                      /*const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addNavigationStep,
                        icon: const Icon(Icons.add_circle, size: 28),
                        color: Theme.of(context).primaryColor,
                      ),*/
                    ],
                  ),
                  // Add Button
                  ElevatedButton.icon(
                    onPressed: _addNavigationStep,
                    label: const Text('Hinzufügen'),
                    icon: const Icon(Icons.add_circle),
                  ),

                  // Remaining distance info
                  /*if (remaining != null) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              Text(
                                'Verbleibend',
                                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${remaining['azimuth']!.toStringAsFixed(1)} gon',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Container(width: 1, height: 30, color: Colors.grey.shade300),
                          Column(
                            children: [
                              Text(
                                'Distanz',
                                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${remaining['distance']!.toStringAsFixed(1)} m',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],*/
                ],
              ),
            ),
          ),
        ],

        Container(height: 10.0, width: 1, color: Colors.grey),
      ],
    );
  }

  LatLng _calculatePositionFromSteps(LatLng start, List<NavigationStep> steps) {
    LatLng current = start;
    final distance = Distance();

    for (var step in steps) {
      if (step.azimuth != null && step.distance != null) {
        // Convert gon to degrees (gon * 360/400)
        final azimuthDegrees = step.azimuth! * (360 / 400);
        current = distance.offset(current, step.distance!, azimuthDegrees);
      }
    }

    return current;
  }
}

class NavigationStep {
  final double? azimuth;
  final double? distance;

  NavigationStep({this.azimuth, this.distance});
}
