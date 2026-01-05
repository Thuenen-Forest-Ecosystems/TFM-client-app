import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart' as repo;

/// Widget for selecting from previous position measurements
/// Displays a list of previous positions from previous_properties and allows
/// selecting one to copy its coordinates to the current position data
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
      _selectedPositions = List.generate(_positionKeys.length, (_) => false);
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
    // Check if we have position data
    print('RAW RECORD: ');
    print(widget.rawRecord);
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
