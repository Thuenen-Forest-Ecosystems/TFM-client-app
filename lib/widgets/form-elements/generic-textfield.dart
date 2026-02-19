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
  final Map<String, dynamic>? currentData; // For calculated fields
  final Map<String, dynamic>? fieldOptions; // Layout configuration (upDownBtn, etc.)

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
    this.currentData,
    this.fieldOptions,
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
      // Check if calculatedFunction is specified (takes precedence over expression)
      // Look in both fieldSchema and fieldOptions
      final calculatedFunction =
          widget.fieldSchema['calculatedFunction'] as String? ??
          widget.fieldOptions?['calculatedFunction'] as String?;
      if (calculatedFunction != null && calculatedFunction.isNotEmpty) {
        return _evaluateCalculatedFunction(calculatedFunction);
      }

      final expression =
          widget.fieldSchema['expression'] as String? ??
          widget.fieldOptions?['expression'] as String?;
      if (expression == null || expression.isEmpty) {
        return 'No expression';
      }

      // Get variables configuration from schema or options
      final variables =
          widget.fieldSchema['variables'] as List? ?? widget.fieldOptions?['variables'] as List?;

      // Create a map of variable names to values
      final Map<String, double> variableValues = {};

      if (variables != null && variables.isNotEmpty) {
        // New approach: Use variables array with source specification
        for (var variable in variables) {
          if (variable is! Map<String, dynamic>) continue;

          final varName = variable['name'] as String?;
          final source = variable['source'] as String?;

          if (varName == null || source == null) continue;

          // Determine which data source to use
          Map<String, dynamic>? dataSource;
          if (source == 'previousData') {
            dataSource = widget.previousData;
          } else if (source == 'currentData') {
            dataSource = widget.currentData;
          }

          if (dataSource == null) {
            // If data source not available, bind 0
            variableValues[varName] = 0.0;
            continue;
          }

          // Get the field key (remove "previous_" prefix if present for backward compatibility)
          final fieldKey = varName.startsWith('previous_') ? varName.substring(9) : varName;

          final value = dataSource[fieldKey];

          if (value != null && value is num) {
            variableValues[varName] = value.toDouble();
          } else {
            // If value is null or not a number, bind 0
            variableValues[varName] = 0.0;
          }
        }
      } else {
        // Fallback: Old approach for backward compatibility
        // If no previous data, return empty string
        if (widget.previousData == null) {
          return '';
        }

        // Find all variable names in the expression
        final variablePattern = RegExp(r'\b[a-zA-Z_][a-zA-Z0-9_]*\b');
        final matches = variablePattern.allMatches(expression);

        for (var match in matches) {
          final varName = match.group(0)!;

          // Remove "previous_" prefix if present
          final fieldKey = varName.startsWith('previous_') ? varName.substring(9) : varName;

          final value = widget.previousData![fieldKey];

          if (value != null && value is num) {
            variableValues[varName] = value.toDouble();
          } else {
            // If value is null or not a number, bind 0
            variableValues[varName] = 0.0;
          }
        }
      }

      // Special handling for boolean expressions with comparisons and multiplications
      // Parse and evaluate manually for better compatibility
      String processedExpression = expression;

      // Replace variables with their values
      variableValues.forEach((varName, value) {
        processedExpression = processedExpression.replaceAll(
          RegExp('\\b$varName\\b'),
          value.toString(),
        );
      });

      // Now evaluate the expression by handling comparisons
      // Replace comparison operators with numeric equivalents
      // x < y becomes (x < y ? 1 : 0)
      // x == 0 becomes (x.abs() < 0.01 ? 1 : 0)
      // x > 0 becomes (x > 0 ? 1 : 0)

      // Evaluate using simple Dart expression evaluation
      double result = _evaluateSimpleExpression(processedExpression);

      // Format result
      // Round to 0 or 1 for boolean-like results
      if ((result - 0.0).abs() < 0.01) {
        return '0';
      } else if ((result - 1.0).abs() < 0.01) {
        return '1';
      }
      // Remove trailing zeros for other values
      return result.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
    } catch (e) {
      debugPrint('❌ Expression evaluation error for ${widget.fieldName}: $e');
      return 'Error: ${e.toString()}';
    }
  }

  double _evaluateSimpleExpression(String expr) {
    // Remove whitespace
    expr = expr.replaceAll(' ', '');

    // Evaluate expressions with comparisons and arithmetic
    // Pattern: (value1 < value2) * (value3 == value4) * ...

    // Split by multiplication
    final parts = expr.split('*');
    double result = 1.0;

    for (var part in parts) {
      part = part.trim();

      // Remove surrounding parentheses if present
      if (part.startsWith('(') && part.endsWith(')')) {
        part = part.substring(1, part.length - 1);
      }

      // Evaluate comparison
      double partResult = _evaluateComparison(part);
      result *= partResult;

      // Short circuit if result is 0
      if (result == 0.0) break;
    }

    return result;
  }

  double _evaluateComparison(String expr) {
    // Handle ==, !=, <, >, <=, >=

    if (expr.contains('==')) {
      final parts = expr.split('==');
      if (parts.length == 2) {
        final left = double.tryParse(parts[0].trim()) ?? 0.0;
        final right = double.tryParse(parts[1].trim()) ?? 0.0;
        return (left - right).abs() < 0.01 ? 1.0 : 0.0;
      }
    } else if (expr.contains('!=')) {
      final parts = expr.split('!=');
      if (parts.length == 2) {
        final left = double.tryParse(parts[0].trim()) ?? 0.0;
        final right = double.tryParse(parts[1].trim()) ?? 0.0;
        return (left - right).abs() >= 0.01 ? 1.0 : 0.0;
      }
    } else if (expr.contains('<=')) {
      final parts = expr.split('<=');
      if (parts.length == 2) {
        final left = double.tryParse(parts[0].trim()) ?? 0.0;
        final right = double.tryParse(parts[1].trim()) ?? 0.0;
        return left <= right ? 1.0 : 0.0;
      }
    } else if (expr.contains('>=')) {
      final parts = expr.split('>=');
      if (parts.length == 2) {
        final left = double.tryParse(parts[0].trim()) ?? 0.0;
        final right = double.tryParse(parts[1].trim()) ?? 0.0;
        return left >= right ? 1.0 : 0.0;
      }
    } else if (expr.contains('<')) {
      final parts = expr.split('<');
      if (parts.length == 2) {
        final left = double.tryParse(parts[0].trim()) ?? 0.0;
        final right = double.tryParse(parts[1].trim()) ?? 0.0;
        return left < right ? 1.0 : 0.0;
      }
    } else if (expr.contains('>')) {
      final parts = expr.split('>');
      if (parts.length == 2) {
        final left = double.tryParse(parts[0].trim()) ?? 0.0;
        final right = double.tryParse(parts[1].trim()) ?? 0.0;
        return left > right ? 1.0 : 0.0;
      }
    } else {
      // No comparison, just return the numeric value
      return double.tryParse(expr.trim()) ?? 0.0;
    }

    return 0.0;
  }

  /// Evaluate a calculated function by name
  String _evaluateCalculatedFunction(String functionName) {
    try {
      switch (functionName) {
        case 'height_measurement_suitability':
          return _calculateHeightMeasurementSuitability();
        default:
          return 'Unknown function: $functionName';
      }
    } catch (e) {
      debugPrint('❌ Function evaluation error for ${widget.fieldName}: $e');
      return 'Error';
    }
  }

  /// Calculate height measurement tree suitability
  /// Returns: "-----" (not in sample), "-" (unsuitable), "?" (unclear), "+" (suitable)
  String _calculateHeightMeasurementSuitability() {
    String suitability = "?????";

    // Helper function to safely get numeric value from dynamic data
    num? getNumValue(String key) {
      final value = widget.currentData?[key];
      if (value == null) return null;
      if (value is num) return value;
      if (value is bool) return value ? 1 : 0;
      if (value is String) return num.tryParse(value);
      return null;
    }

    // Get current data fields
    final treeStatus = getNumValue('tree_status');
    final stemForm = getNumValue('stem_form');
    final stemBreakage = getNumValue('stem_breakage');
    final damageDead = getNumValue('damage_dead');
    final standLayer = getNumValue('stand_layer');
    final distance = getNumValue('distance');

    // Check: Not in sample (tree_status != 0 and != 1)
    // Pk = 0 (lebend stehend) or 1 (liegend tot)
    if (treeStatus == null || (treeStatus != 0 && treeStatus != 1)) {
      return "-----";
    }

    // TODO: GrenzToleranz check - where does this value come from?
    // Original: if (GrenzToleranz < distance) return "-----";
    // This might need to come from plot/position data

    // Now check for unsuitability based on tree properties
    bool unsuitable = false;

    // Kst (stem_form): 2 = Zwiesel, 3 = Kein Einzelstamm
    if (stemForm == 2 || stemForm == 3) unsuitable = true;

    // Kh (stem_breakage): 1 = Wipfelbruch, 2 = Kronenbruch
    if (stemBreakage == 1 || stemBreakage == 2) unsuitable = true;

    // Tot (damage_dead): 1 = Ja (dead) - could be boolean or numeric
    if (damageDead == 1 || damageDead == true) unsuitable = true;

    // Bs (stand_layer): 9 = ? (unclear layer)
    if (standLayer == 9) unsuitable = true;

    if (unsuitable) {
      return "-";
    }

    // Check if data is complete (for "?" unclear status)
    bool dataIncomplete = false;
    if (stemForm == null) dataIncomplete = true;
    if (stemBreakage == null) dataIncomplete = true;
    if (damageDead == null) dataIncomplete = true;
    if (standLayer == null) dataIncomplete = true;

    if (dataIncomplete) {
      return "?";
    }

    // All checks passed and data complete -> suitable
    return "+";
  }

  @override
  Widget build(BuildContext context) {
    final type = _getType();
    final hasErrors = widget.errors.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final errorBgColor = hasErrors
        ? (isDark ? const Color(0xFF5A1F1F) : const Color(0xFFFFCDD2))
        : null;

    // Check if field is readonly (support both 'readOnly' camelCase and 'readonly' lowercase)
    final isReadonly =
        (widget.fieldSchema['readOnly'] as bool? ??
        widget.fieldSchema['readonly'] as bool? ??
        false);

    // Handle calculated type
    if (type == 'calculated') {
      final calculatedValue = _evaluateExpression();
      final tfmData = widget.fieldSchema['\$tfm'] as Map<String, dynamic>?;
      final unit = tfmData?['unit_short'] as String?;

      // Check display mode from field schema or fieldOptions
      final displayMode =
          widget.fieldSchema['display'] as String? ??
          widget.fieldOptions?['display'] as String? ??
          'auto';

      // Check if this is a boolean/icon display (no unit and value is 0 or 1)
      final numericValue = double.tryParse(calculatedValue.replaceAll(RegExp(r'[^0-9.-]'), ''));
      final isBooleanIcon =
          displayMode != 'text' &&
          unit == null &&
          numericValue != null &&
          (numericValue == 0 || numericValue == 1);

      debugPrint(
        '🎯 ${widget.fieldName}: calculatedValue="$calculatedValue", numericValue=$numericValue, unit=$unit, displayMode=$displayMode, isBooleanIcon=$isBooleanIcon',
      );

      Widget displayWidget;
      if (isBooleanIcon && displayMode != 'text') {
        // Show icon for true (1), nothing for false (0)
        if (numericValue == 1) {
          // Get icon from field schema or options
          final iconName =
              widget.fieldSchema['icon'] as String? ?? widget.fieldOptions?['icon'] as String?;

          // Map icon name to Flutter IconData
          IconData iconData;
          switch (iconName) {
            case 'height':
              iconData = Icons.height;
              break;
            case 'check':
            case 'check_circle':
              iconData = Icons.check_circle;
              break;
            case 'star':
              iconData = Icons.star;
              break;
            case 'flag':
              iconData = Icons.flag;
              break;
            default:
              iconData = Icons.check_circle; // Fallback
          }

          displayWidget = Icon(iconData, color: Colors.green, size: widget.compact ? 20 : 24);
        } else {
          displayWidget = const SizedBox.shrink(); // Empty for false
        }
      } else if (displayMode == 'text' && calculatedValue == '+') {
        // Special case: For suitability functions, show icon if suitable ("+")
        final iconName =
            widget.fieldSchema['icon'] as String? ?? widget.fieldOptions?['icon'] as String?;

        // Map icon name to Flutter IconData
        IconData iconData;
        switch (iconName) {
          case 'height':
            iconData = Icons.height;
            break;
          case 'check':
          case 'check_circle':
            iconData = Icons.check_circle;
            break;
          case 'star':
            iconData = Icons.star;
            break;
          case 'flag':
            iconData = Icons.flag;
            break;
          default:
            iconData = Icons.check_circle; // Fallback
        }

        displayWidget = Icon(iconData, size: widget.compact ? 20 : 24);
      } else if (displayMode == 'text' &&
          (calculatedValue == '-' || calculatedValue == '?' || calculatedValue == '-----')) {
        // Not suitable, unclear, or not in sample - show nothing
        displayWidget = const SizedBox.shrink();
      } else if (calculatedValue.isEmpty ||
          calculatedValue == '0' ||
          calculatedValue.startsWith('Error') ||
          calculatedValue == 'No expression') {
        // Empty, zero, error, or no expression - show nothing
        displayWidget = const SizedBox.shrink();
      } else {
        // Show text value (with unit if present)
        final displayValue = unit != null && unit.isNotEmpty
            ? '$calculatedValue $unit'
            : calculatedValue;

        displayWidget = Text(
          displayValue,
          style: TextStyle(
            fontSize: widget.compact ? 14 : 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        );
      }

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
            displayWidget,
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
          crossAxisAlignment: widget.compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: widget.compact
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
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
      final interval = tfmData?['interval'] as List?;

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

      // Update controller text with current display value
      _controller.text = getDisplayText(widget.value);

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
          controller: _controller,
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
                    interval: interval,
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

      // Check for upDownBtn (spinner buttons)
      // Priority: 1) fieldOptions from layout, 2) schema, 3) auto-detect from range
      int? upDownBtn =
          widget.fieldOptions?['upDownBtn'] as int? ?? widget.fieldSchema['upDownBtn'] as int?;
      bool hasSpinner = upDownBtn != null && type == 'integer';

      // Get min/max values from schema
      final minimum = widget.fieldSchema['minimum'] as num?;
      final maximum = widget.fieldSchema['maximum'] as num?;

      // Auto-detection: IF max - min is small and not explicitly set, add upDownBtn +1
      /*if (widget.fieldOptions?['upDownBtn'] == null && widget.fieldSchema['upDownBtn'] == null) {
        if (minimum != null && maximum != null && (maximum - minimum) <= 1000) {
          // Auto-enable spinner for small range
          debugPrint('Auto-enabling upDownBtn for field ${widget.fieldName} due to small range');
          hasSpinner = true;
          upDownBtn = 1;
        }
      }*/

      // Helper function to increment/decrement value
      void adjustValue(int delta) {
        if (isReadonly) return;

        final currentValue = int.tryParse(_controller.text) ?? (minimum?.toInt() ?? 0);
        final newValue = currentValue + delta;

        // Respect min/max bounds
        if (minimum != null && newValue < minimum.toInt()) return;
        if (maximum != null && newValue > maximum.toInt()) return;

        _controller.text = newValue.toString();
        widget.onChanged?.call(newValue);
      }

      final child = Opacity(
        opacity: isReadonly ? 0.6 : 1.0,
        child: TextField(
          focusNode: _focusNode,
          controller: _controller,
          readOnly: isReadonly,
          textAlign: hasSpinner ? TextAlign.center : TextAlign.right,
          decoration: widget.compact
              ? InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  suffixText: !hasSpinner && unit != null && unit.isNotEmpty ? ' $unit' : null,
                  isDense: true,
                  filled: hasErrors,
                  fillColor: errorBgColor,
                  prefixIcon: hasSpinner
                      ? SizedBox(
                          width: 20,
                          child: IconButton(
                            icon: const Icon(Icons.remove, size: 14),
                            onPressed: isReadonly ? null : () => adjustValue(-upDownBtn!),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                            iconSize: 14,
                          ),
                        )
                      : null,
                  suffixIcon: hasSpinner
                      ? SizedBox(
                          width: unit != null && unit.isNotEmpty ? 70 : 40,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (unit != null && unit.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Text(unit, style: const TextStyle(fontSize: 12)),
                                ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 14),
                                onPressed: isReadonly ? null : () => adjustValue(upDownBtn!),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                iconSize: 14,
                              ),
                            ],
                          ),
                        )
                      : null,
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
                  suffixText: !hasSpinner && unit != null && unit.isNotEmpty ? ' $unit' : null,
                  prefixIcon: hasSpinner
                      ? IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: isReadonly ? null : () => adjustValue(-upDownBtn!),
                        )
                      : null,
                  suffixIcon: hasSpinner
                      ? SizedBox(
                          width: unit != null && unit.isNotEmpty ? 100 : 48,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (unit != null && unit.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(unit, style: const TextStyle(fontSize: 14)),
                                ),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: isReadonly ? null : () => adjustValue(upDownBtn!),
                              ),
                            ],
                          ),
                        )
                      : null,
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
