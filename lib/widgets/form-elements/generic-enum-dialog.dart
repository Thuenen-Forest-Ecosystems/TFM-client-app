import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Wrapper class to indicate explicit null selection (clearing the field)
class ClearSelection {
  const ClearSelection();
}

class _GenericEnumDialogWidget extends StatefulWidget {
  final String fieldName;
  final Map<String, dynamic> fieldSchema;
  final dynamic currentValue;
  final List enumValues;
  final List? nameDe;
  final List? interval;
  final bool fullscreen;

  const _GenericEnumDialogWidget({
    super.key,
    required this.fieldName,
    required this.fieldSchema,
    this.currentValue,
    required this.enumValues,
    this.nameDe,
    this.interval,
    this.fullscreen = true,
  });

  @override
  State<_GenericEnumDialogWidget> createState() => _GenericEnumDialogState();
}

class _GenericEnumDialogState extends State<_GenericEnumDialogWidget> {
  final TextEditingController _filterController = TextEditingController();
  String _filterText = '';
  bool _useChipsView = false;
  final FocusNode _searchFocusNode = FocusNode();

  String get _prefsKey => 'enum_chips_view_${widget.fieldName}';
  String get _freqKey => 'enum_freq_${widget.fieldName}';
  Map<String, int> _frequencyMap = {};
  List<int> _topIndices = [];

  @override
  void initState() {
    super.initState();
    _loadViewPreference();
    _loadFrequencyData();
  }

  Future<void> _loadViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_prefsKey);
    if (saved != null && mounted) {
      setState(() {
        _useChipsView = saved;
      });
    }
  }

  Future<void> _saveViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, _useChipsView);
  }

  Future<void> _loadFrequencyData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_freqKey);
    if (jsonStr != null && mounted) {
      setState(() {
        _frequencyMap = Map<String, int>.from(json.decode(jsonStr) as Map);
        _updateTopIndices();
      });
    }
  }

  Future<void> _incrementFrequency(dynamic enumValue) async {
    final key = enumValue.toString();
    _frequencyMap[key] = (_frequencyMap[key] ?? 0) + 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_freqKey, json.encode(_frequencyMap));
  }

  void _updateTopIndices() {
    // Build a list of (index, count) for enum values that have been selected at least once
    final entries = <MapEntry<int, int>>[];
    for (int i = 0; i < widget.enumValues.length; i++) {
      final val = widget.enumValues[i];
      if (val == null) continue;
      final count = _frequencyMap[val.toString()] ?? 0;
      if (count > 0) {
        entries.add(MapEntry(i, count));
      }
    }
    // Sort descending by count, take top 10
    entries.sort((a, b) => b.value.compareTo(a.value));
    _topIndices = entries.take(10).map((e) => e.key).toList();
  }

  @override
  void dispose() {
    _filterController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  String _getLabel() {
    return widget.fieldSchema['title'] as String? ?? widget.fieldName;
  }

  String _getDescription() {
    return widget.fieldSchema['description'] as String? ?? '';
  }

  String _getDisplayText(dynamic enumValue, int index) {
    if (widget.nameDe != null && index < widget.nameDe!.length) {
      final germanName = widget.nameDe![index];
      return germanName != null ? '$enumValue | $germanName' : enumValue.toString();
    }
    return enumValue.toString();
  }

  List<int> _getFilteredIndices() {
    final indices = <int>[];

    // Debug: Check if interval data is provided
    if (widget.interval != null) {
      debugPrint(
        'GenericEnumDialog: Filtering with interval data (${widget.interval!.length} entries)',
      );
    } else {
      debugPrint('GenericEnumDialog: No interval data provided - showing all values');
    }

    for (int i = 0; i < widget.enumValues.length; i++) {
      final enumValue = widget.enumValues[i];

      // Skip null values
      if (enumValue == null) continue;

      // Apply interval filter if provided
      // Only show values where interval[i] is null, empty, or contains "ci2027"
      if (widget.interval != null && i < widget.interval!.length) {
        final intervalValue = widget.interval![i];
        debugPrint('  Enum[$i] = $enumValue, interval = $intervalValue');

        // If intervalValue is a non-empty list, check if it contains "ci2027"
        if (intervalValue != null && intervalValue is List && intervalValue.isNotEmpty) {
          if (!intervalValue.contains('ci2027')) {
            // Skip this value - it's restricted to other inventory periods
            debugPrint('    -> FILTERED OUT (no ci2027)');
            continue;
          } else {
            debugPrint('    -> SHOWN (contains ci2027)');
          }
        } else {
          debugPrint('    -> SHOWN (unrestricted)');
        }
        // If intervalValue is null or empty list, show it (unrestricted)
      }

      // Apply text filter if active
      if (_filterText.isNotEmpty) {
        final filterLower = _filterText.toLowerCase();
        final displayText = _getDisplayText(enumValue, i);

        if (displayText.toLowerCase().contains(filterLower) ||
            enumValue.toString().toLowerCase().contains(filterLower)) {
          indices.add(i);
        }
      } else {
        indices.add(i);
      }
    }

    return indices;
  }

  @override
  Widget build(BuildContext context) {
    final filteredIndices = _getFilteredIndices();

    // Move selected value to the top
    if (widget.currentValue != null) {
      final selectedIdx = filteredIndices.indexWhere(
        (i) => widget.enumValues[i] == widget.currentValue,
      );
      if (selectedIdx > 0) {
        final idx = filteredIndices.removeAt(selectedIdx);
        filteredIndices.insert(0, idx);
      }
    }

    return AlertDialog(
      /*insetPadding: widget.fullscreen
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),*/
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: TextField(
                controller: _filterController,
                focusNode: _searchFocusNode,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: _getLabel(),
                  helperText: _getDescription(),
                  hintText: 'Suchen...',
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(50)),
                  ),
                  suffixIcon: _filterText.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _filterController.clear();
                              _filterText = '';
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _filterText = value;
                  });
                },
              ),
            ),
            IconButton(
              icon: Icon(_useChipsView ? Icons.list : Icons.grid_view),
              onPressed: () {
                setState(() {
                  _useChipsView = !_useChipsView;
                });
                _saveViewPreference();
              },
              tooltip: _useChipsView ? 'Listenansicht' : 'Chips-Ansicht',
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Schließen',
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top 10 most frequently selected values
            if (_topIndices.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      'Häufig verwendet',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _topIndices.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final index = _topIndices[i];
                        final enumValue = widget.enumValues[index];
                        final displayText = _getDisplayText(enumValue, index);
                        final isSelected = widget.currentValue == enumValue;

                        return ChoiceChip(
                          label: Text(displayText),
                          selected: isSelected,
                          onSelected: (_) {
                            _incrementFrequency(enumValue);
                            Navigator.of(context).pop(enumValue);
                          },
                        );
                      },
                    ),
                  ),
                  const Divider(),
                ],
              ),
            Expanded(
              child: filteredIndices.isEmpty
                  ? const Center(child: Text('Keine Ergebnisse gefunden'))
                  : _useChipsView
                  ? SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: filteredIndices.map((index) {
                            final enumValue = widget.enumValues[index];
                            final displayText = _getDisplayText(enumValue, index);
                            final isSelected = widget.currentValue == enumValue;

                            return ChoiceChip(
                              label: Text(displayText),
                              selected: isSelected,
                              onSelected: (_) {
                                _incrementFrequency(enumValue);
                                Navigator.of(context).pop(enumValue);
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredIndices.length,
                      itemBuilder: (context, listIndex) {
                        final index = filteredIndices[listIndex];
                        final enumValue = widget.enumValues[index];
                        final displayText = _getDisplayText(enumValue, index);
                        final isSelected = widget.currentValue == enumValue;

                        return ListTile(
                          contentPadding: const EdgeInsets.all(5),
                          title: Text(displayText),
                          selected: isSelected,
                          trailing: isSelected ? const Icon(Icons.check) : null,
                          onTap: () {
                            _incrementFrequency(enumValue);
                            Navigator.of(context).pop(enumValue);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actionsPadding: EdgeInsets.zero,
      actions: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.1),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(const ClearSelection()),
            child: const Text('Inhalt des Feldes löschen'),
          ),
        ),
      ],
    );
  }
}

class GenericEnumDialog {
  static Future<dynamic> show({
    required BuildContext context,
    required String fieldName,
    required Map<String, dynamic> fieldSchema,
    dynamic currentValue,
    required List enumValues,
    List? nameDe,
    List? interval,
    bool fullscreen = true,
  }) {
    return showDialog<dynamic>(
      context: context,
      builder: (context) => _GenericEnumDialogWidget(
        fieldName: fieldName,
        fieldSchema: fieldSchema,
        currentValue: currentValue,
        enumValues: enumValues,
        nameDe: nameDe,
        interval: interval,
        fullscreen: fullscreen,
      ),
    );
  }
}
