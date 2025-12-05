import 'package:flutter/material.dart';

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
  final bool fullscreen;

  const _GenericEnumDialogWidget({
    super.key,
    required this.fieldName,
    required this.fieldSchema,
    this.currentValue,
    required this.enumValues,
    this.nameDe,
    this.fullscreen = false,
  });

  @override
  State<_GenericEnumDialogWidget> createState() => _GenericEnumDialogState();
}

class _GenericEnumDialogState extends State<_GenericEnumDialogWidget> {
  final TextEditingController _filterController = TextEditingController();
  String _filterText = '';
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
    final indices = <int>[];

    for (int i = 0; i < widget.enumValues.length; i++) {
      final enumValue = widget.enumValues[i];

      // Skip null values
      if (enumValue == null) continue;

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

    return AlertDialog(
      insetPadding: widget.fullscreen
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            /*Text(_getLabel(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (_getDescription().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _getDescription(),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
              ),
            ],*/
            const SizedBox(height: 10),
            TextField(
              controller: _filterController,
              focusNode: _searchFocusNode,
              autofocus: true,
              decoration: InputDecoration(
                labelText: _getLabel(),
                helperText: _getDescription(),
                hintText: 'Suchen...',
                border: const OutlineInputBorder(),
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
          ],
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: filteredIndices.isEmpty
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
                          contentPadding: const EdgeInsets.all(10),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(const ClearSelection()),
                child: const Text('Leeren'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Schließen'),
              ),
            ],
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
    bool fullscreen = false,
  }) {
    return showDialog<dynamic>(
      context: context,
      builder: (context) => _GenericEnumDialogWidget(
        fieldName: fieldName,
        fieldSchema: fieldSchema,
        currentValue: currentValue,
        enumValues: enumValues,
        nameDe: nameDe,
        fullscreen: fullscreen,
      ),
    );
  }
}
