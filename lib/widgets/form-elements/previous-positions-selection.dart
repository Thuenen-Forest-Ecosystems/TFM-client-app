import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart' as repo;
import 'package:terrestrial_forest_monitor/providers/map_controller_provider.dart';

/// Widget for selecting from previous position measurements
/// Displays a list of previous positions from previous_properties and allows
/// selecting one to copy its coordinates to the current position data
/// Also controls visibility of previous position rectangles on the map
class PreviousPositionsSelection extends StatefulWidget {
  final repo.Record? rawRecord;

  const PreviousPositionsSelection({super.key, this.rawRecord});

  @override
  State<PreviousPositionsSelection> createState() => _PreviousPositionsSelectionState();
}

class _PreviousPositionsSelectionState extends State<PreviousPositionsSelection> {
  List<bool> _selectedPositions = [];
  List<String> _positionKeys = [];

  @override
  void initState() {
    super.initState();
    _loadPositionData();
  }

  void _loadPositionData() {
    if (widget.rawRecord?.previousPositionData != null) {
      _positionKeys = widget.rawRecord!.previousPositionData!.keys.toList();

      // Check if provider has visibility state, otherwise default to all visible
      if (mounted) {
        final recordId = widget.rawRecord?.id;
        if (recordId != null) {
          final mapProvider = context.read<MapControllerProvider>();
          final visiblePositions = mapProvider.getVisiblePreviousPositions(recordId);

          if (visiblePositions != null) {
            // Use saved state from provider
            _selectedPositions = _positionKeys
                .map((key) => visiblePositions.contains(key))
                .toList();
          } else {
            // Default: all visible
            _selectedPositions = List.generate(_positionKeys.length, (_) => true);
            // Save initial state to provider
            mapProvider.setVisiblePreviousPositions(recordId, _positionKeys.toSet());
          }
        } else {
          _selectedPositions = List.generate(_positionKeys.length, (_) => true);
        }
      } else {
        _selectedPositions = List.generate(_positionKeys.length, (_) => true);
      }
    }
  }

  @override
  void didUpdateWidget(PreviousPositionsSelection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rawRecord?.previousPositionData != oldWidget.rawRecord?.previousPositionData) {
      _loadPositionData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rawRecord?.previousPositionData == null || _positionKeys.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(16.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Keine vorherigen Positionsdaten verfügbar',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vorherige Positionsmessungen', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16.0),
            ToggleButtons(
              isSelected: _selectedPositions,
              onPressed: (int index) {
                setState(() {
                  _selectedPositions[index] = !_selectedPositions[index];
                });

                // Update provider to control map visibility
                final recordId = widget.rawRecord?.id;
                if (recordId != null) {
                  final mapProvider = context.read<MapControllerProvider>();
                  final visibleKeys = <String>{};
                  for (int i = 0; i < _positionKeys.length; i++) {
                    if (_selectedPositions[i]) {
                      visibleKeys.add(_positionKeys[i]);
                    }
                  }
                  mapProvider.setVisiblePreviousPositions(recordId, visibleKeys);
                }
              },
              children: _positionKeys
                  .map(
                    (key) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(key),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
