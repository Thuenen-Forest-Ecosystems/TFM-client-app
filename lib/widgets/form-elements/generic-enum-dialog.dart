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
  String get _recentKey => 'enum_recent_${widget.fieldName}';
  List<String> _recentValues = [];
  List<int> _recentIndices = [];

  @override
  void initState() {
    super.initState();
    _loadViewPreference();
    _loadRecentData();
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

  Future<void> _loadRecentData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_recentKey);
    if (jsonStr != null && mounted) {
      setState(() {
        _recentValues = List<String>.from(json.decode(jsonStr) as List);
        _updateRecentIndices();
      });
    }
  }

  Future<void> _addToRecent(dynamic enumValue) async {
    final key = enumValue.toString();
    _recentValues.remove(key);
    _recentValues.insert(0, key);
    if (_recentValues.length > 10) _recentValues = _recentValues.sublist(0, 10);
    _updateRecentIndices();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recentKey, json.encode(_recentValues));
  }

  void _updateRecentIndices() {
    // Map recent value keys back to their indices in enumValues, preserving recency order
    final indexMap = <String, int>{};
    for (int i = 0; i < widget.enumValues.length; i++) {
      final val = widget.enumValues[i];
      if (val != null) indexMap[val.toString()] = i;
    }
    _recentIndices = _recentValues.map((key) => indexMap[key]).whereType<int>().toList();
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

  /// Returns true if the value at [index] is enabled for the current interval.
  /// When no interval data is provided, all values are enabled.
  bool _isIndexEnabled(int index) {
    if (widget.interval == null || index >= widget.interval!.length) return true;
    final intervalValue = widget.interval![index];
    return intervalValue is List && intervalValue.contains('ci2027');
  }

  List<int> _getFilteredIndices() {
    final indices = <int>[];

    for (int i = 0; i < widget.enumValues.length; i++) {
      final enumValue = widget.enumValues[i];

      // Skip null values
      if (enumValue == null) continue;

      // Apply text filter if active (only filter enabled values when searching)
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
            if (_recentIndices.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      'Zuletzt genutzt',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _recentIndices.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final index = _recentIndices[i];
                        final enumValue = widget.enumValues[index];
                        final displayText = _getDisplayText(enumValue, index);
                        final isSelected = widget.currentValue == enumValue;
                        final isEnabled = _isIndexEnabled(index);

                        return Opacity(
                          opacity: isEnabled ? 1.0 : 0.4,
                          child: ChoiceChip(
                            label: Text(displayText),
                            selected: isSelected,
                            onSelected: isEnabled
                                ? (_) {
                                    _addToRecent(enumValue);
                                    Navigator.of(context).pop(enumValue);
                                  }
                                : null,
                          ),
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
                            final isEnabled = _isIndexEnabled(index);

                            return Opacity(
                              opacity: isEnabled ? 1.0 : 0.4,
                              child: ChoiceChip(
                                label: Text(displayText),
                                selected: isSelected,
                                onSelected: isEnabled
                                    ? (_) {
                                        _addToRecent(enumValue);
                                        Navigator.of(context).pop(enumValue);
                                      }
                                    : null,
                              ),
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
                        final isEnabled = _isIndexEnabled(index);

                        return ListTile(
                          contentPadding: const EdgeInsets.all(5),
                          title: Text(
                            displayText,
                            style: isEnabled
                                ? null
                                : TextStyle(color: Theme.of(context).disabledColor),
                          ),
                          selected: isSelected,
                          trailing: isSelected ? const Icon(Icons.check) : null,
                          enabled: isEnabled,
                          onTap: isEnabled
                              ? () {
                                  _addToRecent(enumValue);
                                  Navigator.of(context).pop(enumValue);
                                }
                              : null,
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
