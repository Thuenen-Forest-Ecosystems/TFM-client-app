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
  final bool dense;
  final bool autofocus;
  final double? width; // Optional width constraint from layout

  const GenericTextField({
    super.key,
    required this.fieldName,
    required this.fieldSchema,
    this.value,
    this.errors = const [],
    this.onChanged,
    this.compact = false,
    this.dense = false,
    this.autofocus = false,
    this.width,
  });

  @override
  State<GenericTextField> createState() => _GenericTextFieldState();
}

class _GenericTextFieldState extends State<GenericTextField> {
  late TextEditingController _controller;
  late bool _boolValue;
  late FocusNode _focusNode;
  bool _hasRequestedInitialFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    debugPrint(
      'Errors for field ${widget.fieldName}: ${widget.errors.map((e) => e.message).join(', ')}',
    );
    _initializeControllers();

    if (widget.autofocus && !_hasRequestedInitialFocus) {
      _hasRequestedInitialFocus = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      });
    }
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
    dynamic effectiveValue = widget.value;

    // If value is null, use schema default if available
    if (effectiveValue == null && widget.fieldSchema.containsKey('default')) {
      effectiveValue = widget.fieldSchema['default'];
      // Notify parent immediately about the default value
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onChanged?.call(effectiveValue);
      });
    }

    if (type == 'boolean') {
      _boolValue = effectiveValue == true;
      debugPrint('Initialized boolean field ${widget.fieldName} with value $_boolValue');
    } else {
      _controller = TextEditingController(text: effectiveValue?.toString() ?? '');
      if (widget.autofocus) {
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      }
    }
  }

  void _updateControllers() {
    final type = _getType();
    dynamic effectiveValue = widget.value;

    // If value is null, use schema default if available
    if (effectiveValue == null && widget.fieldSchema.containsKey('default')) {
      effectiveValue = widget.fieldSchema['default'];
      // Notify parent immediately about the default value
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onChanged?.call(effectiveValue);
      });
    }

    final newValue = effectiveValue?.toString() ?? '';

    if (type == 'boolean') {
      _boolValue = effectiveValue == true;
    } else {
      // Only update controller text if it's different to avoid cursor position reset
      if (_controller.text != newValue) {
        _controller.text = newValue;
      }
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
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
    final errorBgColor = hasErrors
        ? (isDark ? const Color(0xFF5A1F1F) : const Color(0xFFFFCDD2))
        : null;

    // Check if field is readonly (JSON Schema standard)
    final isReadonly = widget.fieldSchema['readonly'] as bool? ?? false;

    // Handle boolean with Switch
    if (type == 'boolean') {
      final child = Opacity(
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
                  focusNode: _focusNode,
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
            if (hasErrors) ...[
              const SizedBox(height: 4),
              Text(_getErrorText() ?? '', style: const TextStyle(fontSize: 12, color: Colors.red)),
            ],
          ],
        ),
      );
      return widget.width != null ? SizedBox(width: widget.width, child: child) : child;
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

      final child = Opacity(
        opacity: isReadonly ? 0.6 : 1.0,
        child: TextField(
          focusNode: _focusNode,
          readOnly: true,
          decoration: widget.compact
              ? InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  suffixIcon: const Icon(Icons.arrow_drop_down, size: 20),
                  isDense: true,
                  filled: hasErrors,
                  fillColor: errorBgColor,
                )
              : InputDecoration(
                  labelText: _getLabel(),
                  helperText: _getDescription(),
                  errorText: _getErrorText(),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(50)),
                  ),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                  filled: true,
                  isDense: widget.dense,
                  fillColor: Colors.grey.withOpacity(0.1),
                ),
          controller: TextEditingController(text: getDisplayText(widget.value)),
          onTap: isReadonly
              ? null
              : () async {
                  final selected = await GenericEnumDialog.show(
                    context: context,
                    fieldName: widget.fieldName,
                    fieldSchema: widget.fieldSchema,
                    currentValue: widget.value,
                    enumValues: enumValues,
                    nameDe: nameDe,
                    fullscreen: true,
                  );

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

      return widget.width != null ? SizedBox(width: widget.width, child: child) : child;
    }

    // Handle number and integer types
    if (type == 'number' || type == 'integer') {
      final tfmData = widget.fieldSchema['\$tfm'] as Map<String, dynamic>?;
      final unit = tfmData?['unit_short'] as String?;

      final child = Opacity(
        opacity: isReadonly ? 0.6 : 1.0,
        child: TextField(
          focusNode: _focusNode,
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
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(50)),
                  ),
                  filled: true,
                  isDense: widget.dense,
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
          keyboardType: type == 'integer'
              ? TextInputType.number
              : const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: type == 'integer'
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
        ),
      );

      return widget.width != null ? SizedBox(width: widget.width, child: child) : child;
    }

    // Handle string (default)
    final child = Opacity(
      opacity: isReadonly ? 0.6 : 1.0,
      child: TextField(
        focusNode: _focusNode,
        controller: _controller,
        readOnly: isReadonly,
        decoration: widget.compact
            ? InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                isDense: true,
                filled: hasErrors,
                fillColor: errorBgColor,
              )
            : InputDecoration(
                labelText: _getLabel(),
                helperText: _getDescription(),
                errorText: _getErrorText(),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                filled: true,
                isDense: widget.dense,
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
        maxLines:
            widget.fieldSchema['maxLength'] != null &&
                (widget.fieldSchema['maxLength'] as int) > 100
            ? 3
            : 1,
        onChanged: (value) {
          widget.onChanged?.call(value.isEmpty ? null : value);
        },
      ),
    );

    return widget.width != null ? SizedBox(width: widget.width, child: child) : child;
  }
}
