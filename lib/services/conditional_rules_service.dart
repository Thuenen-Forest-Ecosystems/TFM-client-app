import 'dart:convert';
import 'package:universal_io/io.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Service for loading and applying conditional rules to JSON schemas
/// based on form data state
class ConditionalRulesService {
  static final ConditionalRulesService _instance = ConditionalRulesService._internal();
  factory ConditionalRulesService() => _instance;
  ConditionalRulesService._internal();

  List<ConditionalRule>? _cachedRules;
  String? _cachedDirectory;

  /// Load conditional rules from file
  Future<List<ConditionalRule>> loadRules(String directory) async {
    // Return cached rules if directory hasn't changed
    if (_cachedRules != null && _cachedDirectory == directory) {
      return _cachedRules!;
    }

    try {
      final appDirectory = await getApplicationDocumentsDirectory();
      final styleMapPath = '${appDirectory.path}/TFM/validation/$directory/style.json';

      final styleMapFile = File(styleMapPath);

      if (!await styleMapFile.exists()) {
        debugPrint('❌ style-map.json not found at: $styleMapPath');
        return [];
      }

      final styleMapContent = await styleMapFile.readAsString();
      final styleMapJson = jsonDecode(styleMapContent);

      //final rulesJson = styleMapJson['conditionalRules'];

      // Extract conditional rules from style-map.json
      final rules =
          (styleMapJson['conditionalRules'] as List?)
              ?.map((rule) => ConditionalRule.fromJson(rule))
              .toList() ??
          [];

      // Cache the loaded rules
      _cachedRules = rules;
      _cachedDirectory = directory;

      return rules;
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading conditional rules: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Deep copy a map to avoid mutating the original
  Map<String, dynamic> _deepCopyMap(Map<String, dynamic> original) {
    final copy = <String, dynamic>{};
    original.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        copy[key] = _deepCopyMap(value);
      } else if (value is List) {
        copy[key] = _deepCopyList(value);
      } else {
        copy[key] = value;
      }
    });
    return copy;
  }

  /// Deep copy a list to avoid mutating the original
  List<dynamic> _deepCopyList(List<dynamic> original) {
    return original.map((item) {
      if (item is Map<String, dynamic>) {
        return _deepCopyMap(item);
      } else if (item is List) {
        return _deepCopyList(item);
      } else {
        return item;
      }
    }).toList();
  }

  /// Apply conditional rules to a schema based on form data
  Map<String, dynamic> applyRules({
    required Map<String, dynamic> schema,
    required Map<String, dynamic> formData,
    required List<ConditionalRule> rules,
  }) {
    debugPrint('=== Applying ${rules.length} conditional rules ===');
    // Deep copy to avoid mutating the original schema
    var modifiedSchema = _deepCopyMap(schema);

    for (final rule in rules) {
      if (_shouldApplyRule(rule, formData)) {
        debugPrint('✓ Applying conditional rule: ${rule.id}');
        modifiedSchema = _executeRuleActions(rule, modifiedSchema);
      } else {
        debugPrint('✗ Skipping rule: ${rule.id} (condition not met)');
      }
    }

    return modifiedSchema;
  }

  /// Check if a rule's trigger condition is met
  bool _shouldApplyRule(ConditionalRule rule, Map<String, dynamic> formData) {
    final trigger = rule.trigger;
    final fieldValue = formData[trigger.field];

    debugPrint(
      'Checking rule "${rule.id}": field="${trigger.field}", value=$fieldValue (${fieldValue.runtimeType}), operator="${trigger.operator}", expected=${trigger.values}',
    );

    switch (trigger.operator) {
      case 'in':
        // Handle type coercion: compare both as-is and as strings/numbers
        if (trigger.values == null) return false;

        for (final expectedValue in trigger.values!) {
          // Direct comparison
          if (fieldValue == expectedValue) {
            debugPrint('✓ Match found (direct): $fieldValue == $expectedValue');
            return true;
          }

          // String comparison
          if (fieldValue.toString() == expectedValue.toString()) {
            debugPrint(
              '✓ Match found (string): $fieldValue.toString() == $expectedValue.toString()',
            );
            return true;
          }

          // Numeric comparison
          if (fieldValue is num && expectedValue is num) {
            if (fieldValue == expectedValue) {
              debugPrint('✓ Match found (numeric): $fieldValue == $expectedValue');
              return true;
            }
          } else if (fieldValue is String && expectedValue is num) {
            final parsedValue = num.tryParse(fieldValue);
            if (parsedValue == expectedValue) {
              debugPrint('✓ Match found (parsed string to num): $parsedValue == $expectedValue');
              return true;
            }
          } else if (fieldValue is num && expectedValue is String) {
            final parsedExpected = num.tryParse(expectedValue);
            if (fieldValue == parsedExpected) {
              debugPrint('✓ Match found (parsed expected to num): $fieldValue == $parsedExpected');
              return true;
            }
          }
        }

        debugPrint('✗ No match found');
        return false;

      case 'notIn':
        return !(trigger.values?.contains(fieldValue) ?? true);
      case 'equals':
        return fieldValue == trigger.value;
      case 'notEquals':
        return fieldValue != trigger.value;
      case 'greaterThan':
        return fieldValue != null && fieldValue > (trigger.value ?? 0);
      case 'lessThan':
        return fieldValue != null && fieldValue < (trigger.value ?? 0);
      default:
        debugPrint('Unknown operator: ${trigger.operator}');
        return false;
    }
  }

  /// Execute all actions defined in a rule
  Map<String, dynamic> _executeRuleActions(ConditionalRule rule, Map<String, dynamic> schema) {
    var modifiedSchema = Map<String, dynamic>.from(schema);

    for (final action in rule.actions) {
      switch (action.type) {
        case 'setReadOnly':
          modifiedSchema = _applySetReadOnly(modifiedSchema, action);
          break;
        case 'setRequired':
          modifiedSchema = _applySetRequired(modifiedSchema, action);
          break;
        case 'setVisible':
          modifiedSchema = _applySetVisible(modifiedSchema, action);
          break;
        default:
          debugPrint('Unknown action type: ${action.type}');
      }
    }

    return modifiedSchema;
  }

  /// Apply setReadOnly action to schema
  Map<String, dynamic> _applySetReadOnly(Map<String, dynamic> schema, RuleAction action) {
    final modifiedSchema = Map<String, dynamic>.from(schema);
    final properties = modifiedSchema['properties'] as Map<String, dynamic>?;

    if (properties == null) return modifiedSchema;

    final modifiedProperties = <String, dynamic>{};
    final exceptions = action.exceptions ?? [];
    final includeArrays = action.includeArrays ?? false;

    // Parse exceptions to separate top-level and nested (dot notation)
    final topLevelExceptions = <String>[];
    final nestedExceptions = <String, List<String>>{};

    for (final exception in exceptions) {
      if (exception.contains('.')) {
        final parts = exception.split('.');
        final arrayField = parts[0];
        final nestedField = parts.sublist(1).join('.');

        if (!nestedExceptions.containsKey(arrayField)) {
          nestedExceptions[arrayField] = [];
        }
        nestedExceptions[arrayField]!.add(nestedField);
      } else {
        topLevelExceptions.add(exception);
      }
    }

    properties.forEach((key, value) {
      final fieldSchema = Map<String, dynamic>.from(value as Map<String, dynamic>);

      // Check if this field should be affected
      final isException = topLevelExceptions.contains(key);
      final isTargeted =
          action.target == 'allFields' || (action.targetFields?.contains(key) ?? false);

      if (isTargeted && !isException) {
        // Check if this is an array field
        if (fieldSchema['type'] == 'array' ||
            (fieldSchema['type'] is List && (fieldSchema['type'] as List).contains('array'))) {
          if (includeArrays) {
            // Set readonly on the array field itself
            fieldSchema['readonly'] = true;

            // Also set readonly on array items' properties
            final items = fieldSchema['items'] as Map<String, dynamic>?;
            if (items != null && items['properties'] != null) {
              final itemProperties = Map<String, dynamic>.from(
                items['properties'] as Map<String, dynamic>,
              );
              final modifiedItemProperties = <String, dynamic>{};

              // Get nested exceptions for this array field (from dot notation)
              final arrayExceptions = nestedExceptions[key] ?? [];

              itemProperties.forEach((propKey, propValue) {
                final propSchema = Map<String, dynamic>.from(propValue as Map<String, dynamic>);

                // Only set readOnly if this property is not in the nested exceptions
                if (!arrayExceptions.contains(propKey)) {
                  propSchema['readonly'] = true;
                }

                modifiedItemProperties[propKey] = propSchema;
              });

              items['properties'] = modifiedItemProperties;
              fieldSchema['items'] = items;
            }
          }
        } else {
          // Regular field - set readOnly
          fieldSchema['readonly'] = true;
        }
      }

      modifiedProperties[key] = fieldSchema;
    });

    modifiedSchema['properties'] = modifiedProperties;
    return modifiedSchema;
  }

  /// Apply setRequired action to schema
  Map<String, dynamic> _applySetRequired(Map<String, dynamic> schema, RuleAction action) {
    final modifiedSchema = Map<String, dynamic>.from(schema);
    final targetFields = action.targetFields ?? [];
    final value = action.value ?? true;

    if (targetFields.isEmpty) return modifiedSchema;

    final required = List<String>.from(modifiedSchema['required'] ?? []);

    for (final field in targetFields) {
      if (value && !required.contains(field)) {
        required.add(field);
      } else if (!value && required.contains(field)) {
        required.remove(field);
      }
    }

    modifiedSchema['required'] = required;
    return modifiedSchema;
  }

  /// Apply setVisible action to schema
  Map<String, dynamic> _applySetVisible(Map<String, dynamic> schema, RuleAction action) {
    // This would be implemented based on how visibility is handled in your forms
    // For now, return unchanged schema
    debugPrint('setVisible action not yet implemented');
    return schema;
  }

  /// Clear cached rules (useful when switching schemas)
  void clearCache() {
    _cachedRules = null;
    _cachedDirectory = null;
  }
}

/// Model for a conditional rule
class ConditionalRule {
  final String id;
  final String? description;
  final RuleTrigger trigger;
  final List<RuleAction> actions;

  ConditionalRule({
    required this.id,
    this.description,
    required this.trigger,
    required this.actions,
  });

  factory ConditionalRule.fromJson(Map<String, dynamic> json) {
    return ConditionalRule(
      id: json['id'] as String,
      description: json['description'] as String?,
      trigger: RuleTrigger.fromJson(json['trigger'] as Map<String, dynamic>),
      actions: (json['actions'] as List)
          .map((action) => RuleAction.fromJson(action as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Model for a rule trigger condition
class RuleTrigger {
  final String field;
  final String operator;
  final List<dynamic>? values;
  final dynamic value;

  RuleTrigger({required this.field, required this.operator, this.values, this.value});

  factory RuleTrigger.fromJson(Map<String, dynamic> json) {
    return RuleTrigger(
      field: json['field'] as String,
      operator: json['operator'] as String,
      values: json['values'] as List<dynamic>?,
      value: json['value'],
    );
  }
}

/// Model for a rule action
class RuleAction {
  final String type;
  final String? target;
  final List<String>? targetFields;
  final List<String>? exceptions;
  final bool? includeArrays;
  final dynamic value;

  RuleAction({
    required this.type,
    this.target,
    this.targetFields,
    this.exceptions,
    this.includeArrays,
    this.value,
  });

  factory RuleAction.fromJson(Map<String, dynamic> json) {
    return RuleAction(
      type: json['type'] as String,
      target: json['target'] as String?,
      targetFields: (json['targetFields'] as List?)?.cast<String>(),
      exceptions: (json['exceptions'] as List?)?.cast<String>(),
      includeArrays: json['includeArrays'] as bool?,
      value: json['value'],
    );
  }
}
