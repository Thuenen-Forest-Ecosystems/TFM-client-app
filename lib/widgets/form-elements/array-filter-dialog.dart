import 'package:flutter/material.dart';

/// Filter rule configuration from layout
class ArrayFilterRule {
  final String field;
  final String operator;
  final List<dynamic> values;
  final bool defaultActive;
  final String label;
  final String? description;

  ArrayFilterRule({
    required this.field,
    required this.operator,
    required this.values,
    required this.defaultActive,
    required this.label,
    this.description,
  });

  factory ArrayFilterRule.fromJson(Map<String, dynamic> json) {
    return ArrayFilterRule(
      field: json['field'] as String,
      operator: json['operator'] as String? ?? 'notIn',
      values: json['values'] as List<dynamic>? ?? json['notIn'] as List<dynamic>? ?? [],
      defaultActive: json['default'] as bool? ?? false,
      label: json['label'] as String? ?? 'Filter',
      description: json['description'] as String?,
    );
  }

  /// Check if a row value matches this filter rule
  bool matches(dynamic value) {
    switch (operator) {
      case 'notIn':
        return !values.contains(value);
      case 'in':
        return values.contains(value);
      case 'equals':
        return value == values.first;
      case 'notEquals':
        return value != values.first;
      case 'greaterThan':
        if (value is num && values.first is num) {
          return value > values.first;
        }
        return false;
      case 'lessThan':
        if (value is num && values.first is num) {
          return value < values.first;
        }
        return false;
      default:
        return true;
    }
  }
}

/// Dialog for toggling array filters
class ArrayFilterDialog extends StatefulWidget {
  final List<ArrayFilterRule> filters;
  final Set<int> activeFilterIndices;

  const ArrayFilterDialog({super.key, required this.filters, required this.activeFilterIndices});

  static Future<Set<int>?> show({
    required BuildContext context,
    required List<ArrayFilterRule> filters,
    required Set<int> activeFilterIndices,
  }) async {
    return showDialog<Set<int>>(
      context: context,
      builder: (context) =>
          ArrayFilterDialog(filters: filters, activeFilterIndices: activeFilterIndices),
    );
  }

  @override
  State<ArrayFilterDialog> createState() => _ArrayFilterDialogState();
}

class _ArrayFilterDialogState extends State<ArrayFilterDialog> {
  late Set<int> _activeIndices;

  @override
  void initState() {
    super.initState();
    _activeIndices = Set.from(widget.activeFilterIndices);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.filter_list, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Filter'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: widget.filters.isEmpty
            ? const Padding(padding: EdgeInsets.all(16.0), child: Text('Keine Filter verfügbar'))
            : ListView.builder(
                shrinkWrap: true,
                itemCount: widget.filters.length,
                itemBuilder: (context, index) {
                  final filter = widget.filters[index];
                  final isActive = _activeIndices.contains(index);

                  return SwitchListTile(
                    title: Text(filter.label),
                    subtitle: filter.description != null
                        ? Text(filter.description!, style: theme.textTheme.bodySmall)
                        : null,
                    value: isActive,
                    onChanged: (value) {
                      setState(() {
                        if (value) {
                          _activeIndices.add(index);
                        } else {
                          _activeIndices.remove(index);
                        }
                      });
                    },
                  );
                },
              ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_activeIndices),
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}
