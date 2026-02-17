import 'package:flutter/foundation.dart';

/// Layout configuration models for dynamic form rendering
///
/// These models represent the structure defined in layout JSON files (e.g., ci2027.json)
/// They describe HOW to display data, while validation schemas describe WHAT the data is.

/// Base class for all layout items
abstract class LayoutItem {
  final String id;
  final String? label;
  final String type;
  final String? icon;

  LayoutItem({required this.id, this.label, required this.type, this.icon});

  factory LayoutItem.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;

    switch (type) {
      case 'tabs':
        return TabsLayout.fromJson(json);
      case 'column':
        return ColumnLayout.fromJson(json);
      case 'form':
        return FormLayout.fromJson(json);
      case 'array':
        return ArrayLayout.fromJson(json);
      case 'object':
        return ObjectLayout.fromJson(json);
      case 'card':
      case 'card-dialog':
        return CardLayout.fromJson(json);
      default:
        throw Exception('Unknown layout type: $type');
    }
  }
}

/// Container layout that displays items in a vertical column
/// Used to stack multiple cards, forms, or other layout items vertically
class ColumnLayout extends LayoutItem {
  final List<LayoutItem> items;

  ColumnLayout({required super.id, super.label, required this.items, super.icon})
    : super(type: 'column');

  factory ColumnLayout.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? [];

    return ColumnLayout(
      id: json['id'] as String? ?? 'column',
      label: json['label'] as String?,
      items: itemsJson.map((item) => LayoutItem.fromJson(item as Map<String, dynamic>)).toList(),
      icon: json['icon'] as String?,
    );
  }
}

/// Container layout that displays items in tabs
/// Can be used as root layout or as a nested tab container
class TabsLayout extends LayoutItem {
  final List<LayoutItem> items;
  final Map<String, dynamic>? typeProperties;
  final int? defaultTab;

  TabsLayout({
    required super.id,
    super.label,
    required this.items,
    this.typeProperties,
    this.defaultTab,
    super.icon,
  }) : super(type: 'tabs');

  factory TabsLayout.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? [];

    return TabsLayout(
      id: json['id'] as String? ?? 'root',
      label: json['label'] as String?,
      items: itemsJson.map((item) => LayoutItem.fromJson(item as Map<String, dynamic>)).toList(),
      typeProperties: json['typeProperties'] as Map<String, dynamic>?,
      defaultTab: json['defaultTab'] as int?,
      icon: json['icon'] as String?,
    );
  }
}

/// Property definition for FormLayout - can be string or object with options
class PropertyConfig {
  final String name;
  final double? width;
  final double? minWidth;
  final double? maxWidth;
  final bool? useSpeechToText;
  final int? upDownBtn;

  PropertyConfig({
    required this.name,
    this.width,
    this.minWidth,
    this.maxWidth,
    this.useSpeechToText,
    this.upDownBtn,
  });

  factory PropertyConfig.fromJson(dynamic json) {
    if (json is String) {
      return PropertyConfig(name: json);
    } else if (json is Map<String, dynamic>) {
      return PropertyConfig(
        name: json['name'] as String,
        width: (json['width'] as num?)?.toDouble(),
        minWidth: (json['minWidth'] as num?)?.toDouble(),
        maxWidth: (json['maxWidth'] as num?)?.toDouble(),
        useSpeechToText: json['useSpeechToText'] as bool?,
        upDownBtn: json['upDownBtn'] as int?,
      );
    }
    throw Exception('Invalid property config format');
  }
}

/// Layout for primitive fields (string, number, boolean, etc.)
class FormLayout extends LayoutItem {
  final List<PropertyConfig> properties;
  final Map<String, dynamic>? options; // UI options for form fields
  final Map<String, dynamic>? typeProperties; // Type-specific properties (scrollHorizontal)
  final String?
  property; // Optional property path (e.g., 'subplots_relative_position[0]' or 'subplots_relative_position.items')
  final List<dynamic>?
  propertiesFilter; // Filter for array items (e.g., [{"tableName": "regeneration"}])

  FormLayout({
    required super.id,
    super.label,
    required this.properties,
    this.options,
    this.typeProperties,
    this.property,
    this.propertiesFilter,
    super.icon,
  }) : super(type: 'form');

  factory FormLayout.fromJson(Map<String, dynamic> json) {
    final propertiesJson = json['properties'] as List<dynamic>? ?? [];

    return FormLayout(
      id: json['id'] as String,
      label: json['label'] as String?,
      properties: propertiesJson.map((p) => PropertyConfig.fromJson(p)).toList(),
      options: json['options'] as Map<String, dynamic>?,
      typeProperties: json['typeProperties'] as Map<String, dynamic>?,
      property: json['property'] as String?,
      propertiesFilter: json['propertiesFilter'] as List<dynamic>?,
      icon: json['icon'] as String?,
    );
  }
}

/// Layout for array data
/// Property can be a path (e.g., 'tree' or 'plot.tree' or 'position.coordinates.points')
class ArrayLayout extends LayoutItem {
  final String? property; // Supports dot-notation paths
  final String component;
  final Map<String, dynamic>? options; // UI options (autoIncrement, etc.)
  final Map<String, dynamic>?
  columns; // Column-specific styling (pinning, grouping, display, width) - OLD STRUCTURE
  final List<dynamic>? items; // Column items array with groups - NEW STRUCTURE
  final String? identifierField; // Field name for matching rows with previous data
  final List<dynamic>? filter; // Filter configuration array

  ArrayLayout({
    required super.id,
    super.label,
    this.property,
    required this.component,
    this.options,
    this.columns,
    this.items,
    this.identifierField,
    this.filter,
    super.icon,
  }) : super(type: 'array');

  factory ArrayLayout.fromJson(Map<String, dynamic> json) {
    final items = json['items'] as List<dynamic>?;
    debugPrint('📋 ArrayLayout.fromJson for ${json['id']}: items count = ${items?.length ?? 0}');
    if (items != null && items.isNotEmpty) {
      debugPrint('   First item: ${items[0]}');
    }

    return ArrayLayout(
      id: json['id'] as String,
      label: json['label'] as String?,
      property: json['property'] as String?,
      component: json['component'] as String? ?? 'datagrid',
      options: json['options'] as Map<String, dynamic>?,
      columns: json['columns'] as Map<String, dynamic>?,
      items: items,
      identifierField: json['identifierField'] as String?,
      filter: json['filter'] as List<dynamic>?,
      icon: json['icon'] as String?,
    );
  }
}

/// Layout for object data
/// Property can be a path (e.g., 'position' or 'plot.coordinates')
class ObjectLayout extends LayoutItem {
  final String? property; // Supports dot-notation paths
  final String component;
  final List<LayoutItem>? children;

  final Map<String, dynamic>? options; // UI options for component

  ObjectLayout({
    required super.id,
    super.label,
    this.property,
    required this.component,
    this.children,
    this.options,
    super.icon,
  }) : super(type: 'object');

  factory ObjectLayout.fromJson(Map<String, dynamic> json) {
    final childrenJson = json['children'] as List<dynamic>?;
    final itemsJson = json['items'] as List<dynamic>?; // Support 'items' as alias for 'children'
    // Support 'child' as single item for children
    final childJson = json['child'] as Map<String, dynamic>?;

    List<LayoutItem>? children;
    if (childrenJson != null) {
      children = childrenJson
          .map((item) => LayoutItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } else if (itemsJson != null) {
      children = itemsJson
          .map((item) => LayoutItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } else if (childJson != null) {
      children = [LayoutItem.fromJson(childJson)];
    }

    return ObjectLayout(
      id: json['id'] as String,
      label: json['label'] as String?,
      property: json['property'] as String?,
      component: json['component'] as String? ?? 'form',
      children: children,
      options: json['options'] as Map<String, dynamic>?,
      icon: json['icon'] as String?,
    );
  }
}

/// Layout for card display
/// Can contain either a list of primitive properties or nested layout items
class CardLayout extends LayoutItem {
  final String? property; // Optional single property path
  final List<String>? properties; // Optional list of property names
  final List<LayoutItem>? children; // Optional nested layout items (tabs, arrays, objects, etc.)

  final Map<String, dynamic>? options; // UI options for card styling
  final Map<String, dynamic>? typeProperties; // Type-specific properties (padding, margin)

  CardLayout({
    required super.id,
    super.label,
    required super.type,
    this.property,
    this.properties,
    this.children,
    this.options,
    this.typeProperties,
    super.icon,
  });

  factory CardLayout.fromJson(Map<String, dynamic> json) {
    final propertiesJson = json['properties'] as List<dynamic>?;
    final childrenJson = json['children'] as List<dynamic>?;
    final itemsJson = json['items'] as List<dynamic>?; // Support 'items' as alias for 'children'
    final type = json['type'] as String? ?? 'card';

    return CardLayout(
      id: json['id'] as String,
      label: json['label'] as String?,
      type: type,
      property: json['property'] as String?,
      properties: propertiesJson?.map((p) => p.toString()).toList(),
      children: (childrenJson ?? itemsJson)
          ?.map((item) => LayoutItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      options: json['options'] as Map<String, dynamic>?,
      typeProperties: json['typeProperties'] as Map<String, dynamic>?,
      icon: json['icon'] as String?,
    );
  }
}

/// Root layout configuration
class LayoutConfig {
  final String? version;
  final String? description;
  final LayoutItem layout;
  final Map<String, dynamic>? components;

  LayoutConfig({this.version, this.description, required this.layout, this.components});

  factory LayoutConfig.fromJson(Map<String, dynamic> json) {
    return LayoutConfig(
      version: json['version'] as String?,
      description: json['description'] as String?,
      layout: LayoutItem.fromJson(json['layout'] as Map<String, dynamic>),
      components: json['components'] as Map<String, dynamic>?,
    );
  }
}
