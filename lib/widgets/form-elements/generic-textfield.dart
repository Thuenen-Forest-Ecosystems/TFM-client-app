import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-enum-dialog.dart';
import 'package:terrestrial_forest_monitor/widgets/speech_to_text_button.dart';

class GenericTextField extends StatefulWidget {
  final String fieldName;
  final Map<String, dynamic> fieldSchema;
  final dynamic value;
  final List<ValidationError> errors;
  final Function(dynamic)? onChanged;

  const GenericTextField({
    super.key,
    required this.fieldName,
    required this.fieldSchema,
    this.value,
    this.errors = const [],
    this.onChanged,
  });

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
      _updateControllers();
    }
  }

  String? _getType() {
    final typeValue = widget.fieldSchema['type'];
    if (typeValue is String) {
      return typeValue;
    } else if (typeValue is List) {
      // Get the first non-null type from the list
      return typeValue.firstWhere((t) => t != 'null' && t != null, orElse: () => null) as String?;
    }
    return null;
  }

  void _initializeControllers() {
    final type = _getType();

    if (type == 'boolean') {
      _boolValue = widget.value == true;
    } else {
      _controller = TextEditingController(text: widget.value?.toString() ?? '');
    }
  }

  void _updateControllers() {
    final type = _getType();
    final newValue = widget.value?.toString() ?? '';

    if (type == 'boolean') {
      _boolValue = widget.value == true;
    } else {
      // Only update controller text if it's different to avoid cursor position reset
      if (_controller.text != newValue) {
        _controller.text = newValue;
      }
    }
  }

  @override
  void dispose() {
    if (_getType() != 'boolean') {
      _controller.dispose();
    }
    super.dispose();
  }

  String? _getLabel() {
    final title = widget.fieldSchema['title'] as String? ?? widget.fieldName;
    final tfmData = widget.fieldSchema['\$tfm'] as Map<String, dynamic>?;
    final unit = tfmData?['unit_short'] as String?;

    if (unit != null && unit.isNotEmpty) {
      return '$title [$unit]';
    }
    return title;
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
    final type = _getType();
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
                    Text(
                      _getLabel() ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: hasErrors ? Colors.red : null,
                      ),
                    ),
                    if (_getDescription() != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _getDescription()!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
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
          if (hasErrors) ...[
            const SizedBox(height: 4),
            Text(_getErrorText() ?? '', style: const TextStyle(fontSize: 12, color: Colors.red)),
          ],
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
          return germanName != null ? '$value | $germanName' : value.toString();
        }
        return value.toString();
      }

      return TextField(
        readOnly: true,
        decoration: InputDecoration(
          labelText: _getLabel(),
          helperText: _getDescription(),
          errorText: _getErrorText(),
          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        controller: TextEditingController(text: getDisplayText(widget.value)),
        onTap: () async {
          final selected = await GenericEnumDialog.show(
            context: context,
            fieldName: widget.fieldName,
            fieldSchema: widget.fieldSchema,
            currentValue: widget.value,
            enumValues: enumValues,
            nameDe: nameDe,
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
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          labelText: _getLabel(),
          helperText: _getDescription(),
          errorText: _getErrorText(),
          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          suffixIcon: SpeechToTextButton(
            controller: _controller,
            fieldType: type,
            onTextChanged: () {
              final value = _controller.text;
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
          ),
        ),
        keyboardType:
            type == 'integer'
                ? TextInputType.number
                : const TextInputType.numberWithOptions(decimal: true),
        inputFormatters:
            type == 'integer'
                ? [FilteringTextInputFormatter.digitsOnly]
                : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
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
      decoration: InputDecoration(
        labelText: _getLabel(),
        helperText: _getDescription(),
        errorText: _getErrorText(),
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        suffixIcon: SpeechToTextButton(
          controller: _controller,
          fieldType: 'string',
          onTextChanged: () {
            final value = _controller.text;
            widget.onChanged?.call(value.isEmpty ? null : value);
          },
        ),
      ),
      maxLines:
          widget.fieldSchema['maxLength'] != null && (widget.fieldSchema['maxLength'] as int) > 100
              ? 3
              : 1,
      onChanged: (value) {
        widget.onChanged?.call(value.isEmpty ? null : value);
      },
    );
  }
}
