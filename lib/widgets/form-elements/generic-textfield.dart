import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';

class GenericTextField extends StatefulWidget {
  final String fieldName;
  final Map<String, dynamic> fieldSchema;
  final dynamic value;
  final List<ValidationError> errors;
  final Function(dynamic)? onChanged;

  const GenericTextField({super.key, required this.fieldName, required this.fieldSchema, this.value, this.errors = const [], this.onChanged});

  @override
  State<GenericTextField> createState() => _GenericTextFieldState();
}

class _GenericTextFieldState extends State<GenericTextField> {
  late TextEditingController _controller;
  late bool _boolValue;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  @override
  void didUpdateWidget(GenericTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _initializeControllers();
    }
  }

  void _initializeControllers() {
    final type = widget.fieldSchema['type'];

    if (type == 'boolean') {
      _boolValue = widget.value == true;
    } else {
      _controller = TextEditingController(text: widget.value?.toString() ?? '');
    }
  }

  @override
  void dispose() {
    if (widget.fieldSchema['type'] != 'boolean') {
      _controller.dispose();
    }
    super.dispose();
  }

  String? _getLabel() {
    return widget.fieldSchema['title'] as String? ?? widget.fieldName;
  }

  String? _getDescription() {
    return widget.fieldSchema['description'] as String?;
  }

  String? _getErrorText() {
    if (widget.errors.isEmpty) return null;
    return widget.errors.map((e) => e.message).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.fieldSchema['type'];
    final hasErrors = widget.errors.isNotEmpty;

    // Handle boolean with Switch
    if (type == 'boolean') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_getLabel() ?? '', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: hasErrors ? Colors.red : null)),
                    if (_getDescription() != null) ...[const SizedBox(height: 4), Text(_getDescription()!, style: TextStyle(fontSize: 12, color: Colors.grey[600]))],
                  ],
                ),
              ),
              Switch(
                value: _boolValue,
                onChanged: (value) {
                  setState(() {
                    _boolValue = value;
                  });
                  widget.onChanged?.call(value);
                },
              ),
            ],
          ),
          if (hasErrors) ...[const SizedBox(height: 4), Text(_getErrorText() ?? '', style: const TextStyle(fontSize: 12, color: Colors.red))],
        ],
      );
    }

    // Handle enum with Dialog picker
    final enumValues = widget.fieldSchema['enum'] as List?;
    if (enumValues != null && enumValues.isNotEmpty) {
      // Get the $tfm metadata if available
      final tfmData = widget.fieldSchema['\$tfm'] as Map<String, dynamic>?;
      final nameDe = tfmData?['name_de'] as List?;

      // Get display text for current value
      String getDisplayText(dynamic value) {
        if (value == null) return '';
        final index = enumValues.indexOf(value);
        if (index == -1) return value.toString();

        if (nameDe != null && index < nameDe.length) {
          final germanName = nameDe[index];
          return germanName != null ? '$germanName ($value)' : value.toString();
        }
        return value.toString();
      }

      return TextField(
        readOnly: true,
        decoration: InputDecoration(labelText: _getLabel(), helperText: _getDescription(), errorText: _getErrorText(), border: const OutlineInputBorder(), suffixIcon: const Icon(Icons.arrow_drop_down)),
        controller: TextEditingController(text: getDisplayText(widget.value)),
        onTap: () async {
          final selected = await showDialog<dynamic>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Text(_getLabel() ?? widget.fieldName),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: enumValues.length,
                      itemBuilder: (context, index) {
                        final enumValue = enumValues[index];
                        String displayText;

                        if (nameDe != null && index < nameDe.length) {
                          final germanName = nameDe[index];
                          displayText = germanName != null ? '$germanName ($enumValue)' : enumValue.toString();
                        } else {
                          displayText = enumValue.toString();
                        }

                        final isSelected = widget.value == enumValue;

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
                  actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen'))],
                ),
          );

          if (selected != null) {
            widget.onChanged?.call(selected);
          }
        },
      );
    }

    // Handle number and integer types
    if (type == 'number' || type == 'integer') {
      return TextField(
        controller: _controller,
        decoration: InputDecoration(labelText: _getLabel(), helperText: _getDescription(), errorText: _getErrorText(), border: const OutlineInputBorder()),
        keyboardType: type == 'integer' ? TextInputType.number : const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: type == 'integer' ? [FilteringTextInputFormatter.digitsOnly] : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
        onChanged: (value) {
          if (value.isEmpty) {
            widget.onChanged?.call(null);
            return;
          }

          if (type == 'integer') {
            final intValue = int.tryParse(value);
            widget.onChanged?.call(intValue);
          } else {
            final doubleValue = double.tryParse(value);
            widget.onChanged?.call(doubleValue);
          }
        },
      );
    }

    // Handle string (default)
    return TextField(
      controller: _controller,
      decoration: InputDecoration(labelText: _getLabel(), helperText: _getDescription(), errorText: _getErrorText(), border: const OutlineInputBorder()),
      maxLines: widget.fieldSchema['maxLength'] != null && (widget.fieldSchema['maxLength'] as int) > 100 ? 3 : 1,
      onChanged: (value) {
        widget.onChanged?.call(value.isEmpty ? null : value);
      },
    );
  }
}
