import 'package:flutter/material.dart';

class _GenericEnumDialogWidget extends StatefulWidget {
  final String fieldName;
  final Map<String, dynamic> fieldSchema;
  final dynamic currentValue;
  final List enumValues;
  final List? nameDe;

  const _GenericEnumDialogWidget({
    super.key,
    required this.fieldName,
    required this.fieldSchema,
    this.currentValue,
    required this.enumValues,
    this.nameDe,
  });

  @override
  State<_GenericEnumDialogWidget> createState() => _GenericEnumDialogState();
}

class _GenericEnumDialogState extends State<_GenericEnumDialogWidget> {
  final TextEditingController _filterController = TextEditingController();
  String _filterText = '';
  bool _showSearchField = false;
  final FocusNode _searchFocusNode = FocusNode();

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
    if (_filterText.isEmpty) {
      return List.generate(widget.enumValues.length, (index) => index);
    }

    final filterLower = _filterText.toLowerCase();
    final filteredIndices = <int>[];

    for (int i = 0; i < widget.enumValues.length; i++) {
      final enumValue = widget.enumValues[i];
      final displayText = _getDisplayText(enumValue, i);

      if (displayText.toLowerCase().contains(filterLower) ||
          enumValue.toString().toLowerCase().contains(filterLower)) {
        filteredIndices.add(i);
      }
    }

    return filteredIndices;
  }

  @override
  Widget build(BuildContext context) {
    final filteredIndices = _getFilteredIndices();

    return AlertDialog(
      title:
          _showSearchField
              ? TextField(
                controller: _filterController,
                focusNode: _searchFocusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Suchen...',
                  border: InputBorder.none,
                  suffixIcon:
                      _filterText.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _filterController.clear();
                                _filterText = '';
                              });
                            },
                          )
                          : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _showSearchField = false;
                                _filterController.clear();
                                _filterText = '';
                              });
                            },
                          ),
                ),
                onChanged: (value) {
                  setState(() {
                    _filterText = value;
                  });
                },
              )
              : ListTile(
                contentPadding: const EdgeInsets.all(0),
                title: Text(_getLabel()),
                subtitle: Text(_getDescription()),
                trailing: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      _showSearchField = true;
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _searchFocusNode.requestFocus();
                    });
                  },
                ),
              ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child:
                  filteredIndices.isEmpty
                      ? const Center(child: Text('Keine Ergebnisse gefunden'))
                      : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredIndices.length,
                        itemBuilder: (context, listIndex) {
                          final index = filteredIndices[listIndex];
                          final enumValue = widget.enumValues[index];
                          final displayText = _getDisplayText(enumValue, index);
                          final isSelected = widget.currentValue == enumValue;

                          return ListTile(
                            title: Text(displayText),
                            selected: isSelected,
                            trailing: isSelected ? const Icon(Icons.check) : null,
                            onTap: () {
                              Navigator.of(context).pop(enumValue);
                            },
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Schließen')),
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
  }) {
    return showDialog<dynamic>(
      context: context,
      builder:
          (context) => _GenericEnumDialogWidget(
            fieldName: fieldName,
            fieldSchema: fieldSchema,
            currentValue: currentValue,
            enumValues: enumValues,
            nameDe: nameDe,
          ),
    );
  }
}
