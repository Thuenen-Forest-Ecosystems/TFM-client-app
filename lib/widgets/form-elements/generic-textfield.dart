import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/generic-enum-dialog.dart';
import 'package:math_expressions/math_expressions.dart';
//import 'package:terrestrial_forest_monitor/widgets/speech_to_text_button.dart';

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
  final Map<String, dynamic>? previousData; // For calculated fields

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
    this.previousData,
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

  String _evaluateExpression() {
    try {
      final expression = widget.fieldSchema['expression'] as String?;
      if (expression == null || expression.isEmpty) {
        return 'No expression';
      }

      // If no previous data, return empty string (tree not in previous inventory)
      if (widget.previousData == null) {
        return '';
      }

      // Find all variable names in the expression
      final variablePattern = RegExp(r'\b[a-zA-Z_][a-zA-Z0-9_]*\b');
      final matches = variablePattern.allMatches(expression);

      // Create a map of variable names to values
      final Map<String, double> variableValues = {};

      for (var match in matches) {
        final varName = match.group(0)!;

        // Remove "previous_" prefix if present
        final fieldKey = varName.startsWith('previous_')
            ? varName.substring(9) // Remove "previous_"
            : varName;

        final value = widget.previousData![fieldKey];

        if (value != null && value is num) {
          variableValues[varName] = value.toDouble();
        } else {
          // If value is null or not a number, bind 0
          variableValues[varName] = 0.0;
        }
      }

      // Parse the expression
      final parser = GrammarParser();
      Expression exp = parser.parse(expression);

      // Create variable context
      final contextModel = ContextModel();
      variableValues.forEach((varName, value) {
        contextModel.bindVariable(Variable(varName), Number(value));
      });

      // Evaluate the expression
      final result = exp.evaluate(EvaluationType.REAL, contextModel);

      // Format result
      if (result is double) {
        // Remove trailing zeros
        return result.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
      }
      return result.toString();
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
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

    // Handle calculated type
    if (type == 'calculated') {
      final calculatedValue = _evaluateExpression();
      final tfmData = widget.fieldSchema['\$tfm'] as Map<String, dynamic>?;
      final unit = tfmData?['unit_short'] as String?;

      final displayValue = unit != null && unit.isNotEmpty
          ? '$calculatedValue $unit'
          : calculatedValue;

      final child = Container(
        padding: widget.compact
            ? const EdgeInsets.symmetric(horizontal: 4, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: widget.compact
            ? null
            : BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
        child: Row(
          children: [
            if (!widget.compact)
              Expanded(
                child: Text(
                  _getLabel() ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            Text(
              displayValue,
              style: TextStyle(
                fontSize: widget.compact ? 14 : 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      );

      return widget.width != null ? SizedBox(width: widget.width, child: child) : child;
    }

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
                  /*suffixIcon: SpeechToTextButton(
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
                  ),*/
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
                /*suffixIcon: SpeechToTextButton(
                  controller: _controller,
                  fieldType: 'string',
                  onTextChanged: () {
                    final value = _controller.text;
                    widget.onChanged?.call(value.isEmpty ? null : value);
                  },
                ),*/
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
