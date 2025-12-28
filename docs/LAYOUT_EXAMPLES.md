# Example: Nested Layout Configuration

This example shows how to create nested layouts with tabs inside tabs or cards containing multiple sections.

## Example 1: Nested Tabs (Future Implementation)

```json
{
  "version": "1.0.0",
  "description": "Example with nested tabs",
  "layout": {
    "type": "tabs",
    "items": [
      {
        "id": "basic",
        "label": "Basic Info",
        "type": "form",
        "properties": ["cluster_name", "grid_density"]
      },
      {
        "id": "measurements",
        "label": "Measurements",
        "type": "tabs",
        "items": [
          {
            "id": "trees",
            "label": "Trees",
            "type": "array",
            "component": "datagrid",
            "property": "tree"
          },
          {
            "id": "deadwood",
            "label": "Deadwood",
            "type": "array",
            "component": "datagrid",
            "property": "deadwood"
          }
        ]
      }
    ]
  }
}
```

## Example 2: Card with Multiple Sections

```json
{
  "version": "1.0.0",
  "description": "Example with card containing sections",
  "layout": {
    "type": "tabs",
    "items": [
      {
        "id": "overview",
        "label": "Overview",
        "type": "card",
        "children": [
          {
            "id": "location",
            "label": "Location",
            "type": "form",
            "properties": ["cartesian_x", "cartesian_y"]
          },
          {
            "id": "status",
            "label": "Status",
            "type": "form",
            "properties": ["cluster_status", "cluster_situation"]
          }
        ]
      }
    ]
  }
}
```

## Example 3: Mixed Layout with Forms, Arrays, and Objects

```json
{
  "version": "1.0.0",
  "description": "Complex layout with multiple component types",
  "layout": {
    "type": "tabs",
    "items": [
      {
        "id": "general",
        "label": "General",
        "type": "form",
        "properties": [
          "cluster_name",
          "inspire_grid_cell",
          "state_responsible",
          "grid_density"
        ]
      },
      {
        "id": "location",
        "label": "Location",
        "type": "object",
        "component": "navigation",
        "property": "position"
      },
      {
        "id": "inventory",
        "label": "Inventory",
        "type": "tabs",
        "items": [
          {
            "id": "trees_main",
            "label": "Trees (Main)",
            "type": "array",
            "component": "datagrid",
            "property": "tree"
          },
          {
            "id": "structure_small",
            "label": "Structure < 4m",
            "type": "array",
            "component": "datagrid",
            "property": "structure_lt4m"
          },
          {
            "id": "structure_large",
            "label": "Structure > 4m",
            "type": "array",
            "component": "datagrid",
            "property": "structure_gt4m"
          }
        ]
      },
      {
        "id": "ecology",
        "label": "Ecology",
        "type": "card",
        "children": [
          {
            "id": "regeneration_section",
            "label": "Regeneration",
            "type": "array",
            "component": "datagrid",
            "property": "regeneration"
          },
          {
            "id": "deadwood_section",
            "label": "Deadwood",
            "type": "array",
            "component": "datagrid",
            "property": "deadwood"
          }
        ]
      }
    ]
  }
}
```

## Example 4: Conditional Layout (Future Enhancement)

This shows a potential future feature where layouts can be conditional based on data state:

```json
{
  "version": "2.0.0",
  "description": "Layout with conditional rendering",
  "layout": {
    "type": "tabs",
    "items": [
      {
        "id": "basic",
        "label": "Basic",
        "type": "form",
        "properties": ["cluster_name", "cluster_status"]
      },
      {
        "id": "forest_data",
        "label": "Forest Data",
        "type": "tabs",
        "condition": {
          "field": "cluster_status",
          "equals": 1
        },
        "items": [
          {
            "id": "tree",
            "type": "array",
            "component": "datagrid",
            "property": "tree"
          }
        ]
      },
      {
        "id": "non_forest",
        "label": "Non-Forest Info",
        "type": "form",
        "condition": {
          "field": "cluster_status",
          "in": [4, 5]
        },
        "properties": ["land_use_type", "notes"]
      }
    ]
  }
}
```

## Example 5: Layout with Custom Styling (Future Enhancement)

```json
{
  "version": "2.0.0",
  "description": "Layout with styling options",
  "layout": {
    "type": "tabs",
    "style": {
      "tabPosition": "left",
      "theme": "compact"
    },
    "items": [
      {
        "id": "priority",
        "label": "Priority Fields",
        "type": "form",
        "properties": ["cluster_name", "grid_density"],
        "style": {
          "layout": "horizontal",
          "columns": 2
        }
      },
      {
        "id": "data",
        "label": "Data",
        "type": "array",
        "component": "datagrid",
        "property": "tree",
        "style": {
          "maxHeight": 600,
          "enableFiltering": true,
          "enableSorting": true
        }
      }
    ]
  }
}
```

## Implementation Notes

### Recursive Layout Rendering

To support nested layouts, the `_buildWidgetFromLayout` method in FormWrapper would need to be enhanced:

```dart
Widget _buildWidgetFromLayout(LayoutItem layoutItem, Map<String, dynamic> schemaProperties) {
  if (layoutItem is TabsLayout) {
    // Nested tabs - create a new TabController
    return NestedTabsWidget(
      items: layoutItem.items,
      schemaProperties: schemaProperties,
      buildChild: (item) => _buildWidgetFromLayout(item, schemaProperties),
    );
  } else if (layoutItem is CardLayout && layoutItem.children != null) {
    // Card with children
    return Card(
      child: Column(
        children: layoutItem.children!.map(
          (child) => _buildWidgetFromLayout(child, schemaProperties)
        ).toList(),
      ),
    );
  }
  // ... existing code for FormLayout, ArrayLayout, ObjectLayout
}
```

### Benefits of Nested Layouts

1. **Better Organization**: Group related fields logically
2. **Reduced Clutter**: Hide advanced options in nested tabs/cards
3. **Improved UX**: Progressive disclosure of information
4. **Flexibility**: Same data can be displayed in different ways

### Migration Path

1. Start with simple flat layouts (current implementation)
2. Add support for card containers with children
3. Implement nested tabs
4. Add conditional rendering
5. Support custom styling options
