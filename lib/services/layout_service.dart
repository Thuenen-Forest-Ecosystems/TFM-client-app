import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:terrestrial_forest_monitor/models/layout_config.dart';

/// Service for loading and managing layout configurations
///
/// Loads layout JSON files (style.json) from downloaded directories
/// provided by PowerSync sync.
class LayoutService {
  static LayoutConfig? _cachedLayout;
  static String? _cachedDirectory;

  /// Load a layout configuration from schema data or downloaded directory
  ///
  /// [styleData] - Optional style data from schema table
  /// [directory] - Directory name containing the style.json file (e.g., 'v73'), used as fallback
  /// Returns null if the layout cannot be loaded
  static Future<LayoutConfig?> loadLayout({
    Map<String, dynamic>? styleData,
    String? directory,
  }) async {
    // Return cached layout if already loaded for this directory
    if (_cachedLayout != null && _cachedDirectory == directory) {
      debugPrint('🔄 Returning CACHED layout for directory: $directory (version: ${_cachedLayout?.version})');
      return _cachedLayout;
    }

    debugPrint('📥 Loading FRESH layout for directory: $directory');

    try {
      Map<String, dynamic>? jsonData;

      // First try: Use provided style data from schema table
      if (styleData != null) {
        print('Loading layout from schema table data');
        jsonData = styleData;
      }
      // Fallback: Load from file if directory is provided
      else if (directory != null) {
        print('Falling back to loading layout from file: $directory');
        final appDirectory = await getApplicationDocumentsDirectory();
        final stylePath = path.join(
          appDirectory.path,
          'TFM',
          'validation',
          directory,
          'style.json',
        );

        final file = File(stylePath);
        if (await file.exists()) {
          final jsonString = await file.readAsString();
          jsonData = json.decode(jsonString) as Map<String, dynamic>;
        } else {
          print('Style file not found: $stylePath');
        }
      }

      if (jsonData == null) {
        print('No layout data available');
        return null;
      }

      _cachedLayout = LayoutConfig.fromJson(jsonData);
      _cachedDirectory = directory;

      debugPrint('✅ Loaded layout version: ${_cachedLayout?.version} for directory: $directory');

      return _cachedLayout;
    } catch (e) {
      print('Failed to load layout: $e');
      return null;
    }
  }

  /// Clear the cached layout (useful for testing or hot reload)
  static void clearCache() {
    debugPrint('🗑️ Clearing layout cache (was: ${_cachedLayout?.version})');
    _cachedLayout = null;
    _cachedDirectory = null;
  }

  /// Get all tab items from a tabs layout
  /// Returns empty list if layout is not a tabs layout
  static List<LayoutItem> getTabItems(LayoutConfig? config) {
    if (config == null) return [];

    final layout = config.layout;
    if (layout is TabsLayout) {
      return layout.items;
    }

    return [];
  }

  /// Find a layout item by ID (recursive search)
  static LayoutItem? findItemById(LayoutConfig? config, String id) {
    if (config == null) return null;
    return _findItemByIdRecursive(config.layout, id);
  }

  static LayoutItem? _findItemByIdRecursive(LayoutItem item, String id) {
    if (item.id == id) return item;

    // Search in children based on type
    if (item is TabsLayout) {
      for (final child in item.items) {
        final found = _findItemByIdRecursive(child, id);
        if (found != null) return found;
      }
    } else if (item is ColumnLayout) {
      for (final child in item.items) {
        final found = _findItemByIdRecursive(child, id);
        if (found != null) return found;
      }
    } else if (item is ObjectLayout && item.children != null) {
      for (final child in item.children!) {
        final found = _findItemByIdRecursive(child, id);
        if (found != null) return found;
      }
    } else if (item is CardLayout && item.children != null) {
      for (final child in item.children!) {
        final found = _findItemByIdRecursive(child, id);
        if (found != null) return found;
      }
    }

    return null;
  }

  /// Get the property name(s) for a layout item
  /// Returns null for container types (tabs), property name for arrays/objects,
  /// or list of property names for forms
  static dynamic getPropertyForItem(LayoutItem item) {
    if (item is FormLayout) {
      return item.properties;
    } else if (item is ArrayLayout) {
      return item.property;
    } else if (item is ObjectLayout) {
      return item.property;
    } else if (item is CardLayout) {
      return item.property ?? item.properties;
    }
    return null;
  }

  /// Get the component type for rendering
  static String? getComponentType(LayoutItem item) {
    if (item is ArrayLayout) {
      return item.component;
    } else if (item is ObjectLayout) {
      return item.component;
    } else if (item is FormLayout) {
      return 'form';
    } else if (item is CardLayout) {
      return 'card';
    } else if (item is TabsLayout) {
      return 'tabs';
    }
    return null;
  }

  /// Check if a layout item represents an array type
  static bool isArrayLayout(LayoutItem item) {
    return item is ArrayLayout;
  }

  /// Check if a layout item represents a form with primitive fields
  static bool isFormLayout(LayoutItem item) {
    return item is FormLayout;
  }

  /// Check if a layout item represents an object
  static bool isObjectLayout(LayoutItem item) {
    return item is ObjectLayout;
  }

  /// Check if a layout item is a container (tabs, card with children)
  static bool isContainerLayout(LayoutItem item) {
    return item is TabsLayout || (item is CardLayout && item.children != null);
  }

  /// Resolve a property value from data using dot-notation path
  /// Example: getValueByPath(data, 'position.coordinates.x')
  /// returns data['position']['coordinates']['x']
  static dynamic getValueByPath(Map<String, dynamic> data, String path) {
    final parts = path.split('.');
    dynamic current = data;

    for (final part in parts) {
      if (current is Map<String, dynamic>) {
        current = current[part];
      } else {
        return null;
      }
    }

    return current;
  }

  /// Set a property value in data using dot-notation path
  /// Example: setValueByPath(data, 'position.coordinates.x', 123)
  /// sets data['position']['coordinates']['x'] = 123
  static void setValueByPath(Map<String, dynamic> data, String path, dynamic value) {
    final parts = path.split('.');

    if (parts.isEmpty) return;

    // Navigate to the parent object
    dynamic current = data;
    for (int i = 0; i < parts.length - 1; i++) {
      final part = parts[i];
      if (current is Map<String, dynamic>) {
        current[part] ??= <String, dynamic>{};
        current = current[part];
      } else {
        return; // Can't traverse further
      }
    }

    // Set the final value
    if (current is Map<String, dynamic>) {
      current[parts.last] = value;
    }
  }

  /// Get schema for a property path
  /// Example: getSchemaByPath(schema['properties'], 'position.coordinates')
  /// returns schema['properties']['position']['properties']['coordinates']
  static Map<String, dynamic>? getSchemaByPath(Map<String, dynamic> schemaProperties, String path) {
    final parts = path.split('.');
    Map<String, dynamic>? current = schemaProperties;

    for (final part in parts) {
      if (current == null) return null;

      final property = current[part] as Map<String, dynamic>?;
      if (property == null) return null;

      // If this is not the last part, navigate to nested properties
      if (parts.last != part) {
        current = property['properties'] as Map<String, dynamic>?;
      } else {
        return property;
      }
    }

    return null;
  }
}
