import 'package:flutter/foundation.dart';
import 'package:terrestrial_forest_monitor/models/layout_config.dart';

/// Service for loading and managing layout configurations
class LayoutService {
  static LayoutConfig? _cachedLayout;
  static String? _cachedDirectory;

  /// Load a layout configuration from schema data
  ///
  /// [styleData] - Style data from schema table
  /// [directory] - Directory name (used only for cache key)
  /// Returns null if the layout cannot be loaded
  static Future<LayoutConfig?> loadLayout({
    Map<String, dynamic>? styleData,
    String? directory,
  }) async {
    // Return cached layout if already loaded for this directory
    if (_cachedLayout != null && _cachedDirectory == directory) {
      return _cachedLayout;
    }


    if (styleData == null) {
      return null;
    }

    try {
      final jsonData = styleData;

      _cachedLayout = LayoutConfig.fromJson(jsonData);
      _cachedDirectory = directory;


      return _cachedLayout;
    } catch (e) {
      return null;
    }
  }

  /// The layout loaded most recently by [loadLayout], if any. Lets widgets that
  /// are opened detached from the form (the validation result dialog) map
  /// error paths to the same tabs the form shows.
  static LayoutConfig? get cachedLayout => _cachedLayout;

  /// Property paths a tab owns, derived from its layout subtree.
  ///
  /// Forms contribute their field names, arrays and objects their `property`
  /// path, cards their `properties`. An `array_summary` object is skipped: it
  /// only mirrors the row count of an array that is edited in another tab (the
  /// WZP4 trees shown in Bestockung), so claiming its path here would badge
  /// this tab with the other tab's validation errors (TFM-client-app#477).
  static List<String> getPropertyPathsForTab(LayoutConfig? config, String tabId) {
    final paths = <String>[];
    if (config == null) return paths;
    final tabItem = findItemById(config, tabId);
    if (tabItem == null) return paths;
    _collectPropertyPaths(tabItem, paths);
    return paths;
  }

  static void _collectPropertyPaths(LayoutItem item, List<String> paths) {
    if (item is FormLayout) {
      paths.addAll(item.properties.map((p) => p.name));
    } else if (item is ArrayLayout) {
      if (item.property != null) paths.add(item.property!);
    } else if (item is ObjectLayout) {
      if (item.property != null && item.component != 'array_summary') {
        paths.add(item.property!);
      }
      for (final child in item.children ?? const <LayoutItem>[]) {
        _collectPropertyPaths(child, paths);
      }
    } else if (item is ColumnLayout) {
      for (final child in item.items) {
        _collectPropertyPaths(child, paths);
      }
    } else if (item is TabsLayout) {
      for (final child in item.items) {
        _collectPropertyPaths(child, paths);
      }
    } else if (item is CardLayout) {
      if (item.properties != null) paths.addAll(item.properties!);
      for (final child in item.children ?? const <LayoutItem>[]) {
        _collectPropertyPaths(child, paths);
      }
    }
  }

  /// Whether an error belongs to a tab that owns [tabPropertyPaths].
  ///
  /// [instancePath] is the AJV/plausibility path (`/tree/3/dbh`); a root
  /// `required` error carries the field in [missingProperty] instead.
  static bool errorMatchesPaths(
    List<String> tabPropertyPaths, {
    String? instancePath,
    String? missingProperty,
  }) {
    final path = instancePath ?? '';
    for (final propertyPath in tabPropertyPaths) {
      if (path == '/$propertyPath' || path.startsWith('/$propertyPath/')) {
        return true;
      }
      if (path.isEmpty && missingProperty != null && missingProperty == propertyPath) {
        return true;
      }
    }
    return false;
  }

  /// Id of the top-level tab an error belongs to, or null when no tab of
  /// [config] owns the error's path. Tabs are checked in layout order.
  static String? findTabIdForError(
    LayoutConfig? config, {
    String? instancePath,
    String? missingProperty,
  }) {
    for (final tab in getTabItems(config)) {
      final paths = getPropertyPathsForTab(config, tab.id);
      if (errorMatchesPaths(paths, instancePath: instancePath, missingProperty: missingProperty)) {
        return tab.id;
      }
    }
    return null;
  }

  /// Label of a top-level tab (`label`, falling back to its id), or null when
  /// [config] has no such tab.
  static String? getTabLabel(LayoutConfig? config, String tabId) {
    for (final tab in getTabItems(config)) {
      if (tab.id == tabId) return tab.label ?? tab.id;
    }
    return null;
  }

  /// Clear the cached layout (useful for testing or hot reload)
  static void clearCache() {
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
