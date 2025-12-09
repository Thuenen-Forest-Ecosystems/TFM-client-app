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
  final bool compact;

  const GenericTextField({super.key, required this.fieldName, required this.fieldSchema, this.value, this.errors = const [], this.onChanged, this.compact = false});

  @override
  State<GenericTextField> createState() => _GenericTextFieldState();
}

class _GenericTextFieldState extends State<GenericTextField> {
  late TextEditingController _controller;
  late bool _boolValue;

  @override
  void initState() {
    super.initState();
    debugPrint('Errors for field ${widget.fieldName}: ${widget.errors.map((e) => e.message).join(', ')}');
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
      // Handle boolean: if value is null, use schema default if available, otherwise false
      if (widget.value != null) {
        _boolValue = widget.value == true;
      } else {
        final defaultValue = widget.fieldSchema['default'];
        _boolValue = defaultValue == true;
      }
    } else {
      _controller = TextEditingController(text: widget.value?.toString() ?? '');
    }
  }

  void _updateControllers() {
    final type = _getType();
    final newValue = widget.value?.toString() ?? '';

    if (type == 'boolean') {
      // Handle boolean: if value is null, use schema default if available, otherwise false
      if (widget.value != null) {
        _boolValue = widget.value == true;
      } else {
        final defaultValue = widget.fieldSchema['default'];
        _boolValue = defaultValue == true;
      }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final errorBgColor = hasErrors ? (isDark ? const Color(0xFF5A1F1F) : const Color(0xFFFFCDD2)) : null;

    // Check if field is readonly (JSON Schema standard)
    final isReadonly = widget.fieldSchema['readonly'] as bool? ?? false;

    // Handle boolean with Switch
    if (type == 'boolean') {
      return Opacity(
        opacity: isReadonly ? 0.6 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!widget.compact)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getLabel() ?? '',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: hasErrors ? Colors.red : null),
                        ),
                        if (_getDescription() != null) ...[const SizedBox(height: 4), Text(_getDescription()!, style: TextStyle(fontSize: 12, color: Colors.grey[600]))],
                      ],
                    ),
                  ),
                Switch(
                  value: _boolValue,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  activeTrackColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                  inactiveThumbColor: Colors.grey[400],
                  onChanged: isReadonly
                      ? null
                      : (value) {
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
        ),
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

      return Opacity(
        opacity: isReadonly ? 0.6 : 1.0,
        child: TextField(
          readOnly: true,
          decoration: widget.compact
              ? InputDecoration(border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), suffixIcon: const Icon(Icons.arrow_drop_down, size: 20), isDense: true, filled: hasErrors, fillColor: errorBgColor)
              : InputDecoration(
                  labelText: _getLabel(),
                  helperText: _getDescription(),
                  errorText: _getErrorText(),
                  border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(50))),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.1),
                ),
          controller: TextEditingController(text: getDisplayText(widget.value)),
          onTap: isReadonly
              ? null
              : () async {
                  final selected = await GenericEnumDialog.show(context: context, fieldName: widget.fieldName, fieldSchema: widget.fieldSchema, currentValue: widget.value, enumValues: enumValues, nameDe: nameDe, fullscreen: true);

                  // Handle different return values:
                  // - null: dialog was dismissed, don't update
                  // - ClearSelection: user clicked "Leeren", set to null
                  // - other: user selected a value
                  if (selected != null) {
                    if (selected.runtimeType.toString() == 'ClearSelection') {
                      widget.onChanged?.call(null);
                    } else {
                      widget.onChanged?.call(selected);
                    }
                  }
                },
        ),
      );
    }

    // Handle number and integer types
    if (type == 'number' || type == 'integer') {
      final tfmData = widget.fieldSchema['\$tfm'] as Map<String, dynamic>?;
      final unit = tfmData?['unit_short'] as String?;

      return Opacity(
        opacity: isReadonly ? 0.6 : 1.0,
        child: TextField(
          controller: _controller,
          readOnly: isReadonly,
          textAlign: TextAlign.right,
          decoration: widget.compact
              ? InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  suffixText: unit != null && unit.isNotEmpty ? ' $unit' : null,
                  isDense: true,
                  filled: hasErrors,
                  fillColor: errorBgColor,
                )
              : InputDecoration(
                  labelText: _getLabel(),
                  helperText: _getDescription(),
                  errorText: _getErrorText(),
                  border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(50))),
                  filled: true,
                  fillColor: hasErrors ? errorBgColor : Colors.grey.withOpacity(0.1),
                  suffixText: unit != null && unit.isNotEmpty ? ' $unit' : null,
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
        ),
      );
    }

    // Handle string (default)
    return Opacity(
      opacity: isReadonly ? 0.6 : 1.0,
      child: TextField(
        controller: _controller,
        readOnly: isReadonly,
        decoration: widget.compact
            ? InputDecoration(border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), isDense: true, filled: hasErrors, fillColor: errorBgColor)
            : InputDecoration(
                labelText: _getLabel(),
                helperText: _getDescription(),
                errorText: _getErrorText(),
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                filled: true,
                fillColor: hasErrors ? errorBgColor : Colors.white.withOpacity(0.1),
                suffixIcon: SpeechToTextButton(
                  controller: _controller,
                  fieldType: 'string',
                  onTextChanged: () {
                    final value = _controller.text;
                    widget.onChanged?.call(value.isEmpty ? null : value);
                  },
                ),
              ),
        maxLines: widget.fieldSchema['maxLength'] != null && (widget.fieldSchema['maxLength'] as int) > 100 ? 3 : 1,
        onChanged: (value) {
          widget.onChanged?.call(value.isEmpty ? null : value);
        },
      ),
    );
  }
}
