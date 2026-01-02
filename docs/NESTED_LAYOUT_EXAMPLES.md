# Nested Layout Examples

This document shows examples of nested layouts with tabs, cards, and path-based property references.

## Example 1: Nested Tabs (Sub-Tabs)

Group related arrays under a parent tab:

```json
{
  "layout": {
    "type": "tabs",
    "items": [
      {
        "id": "info",
        "label": "Trakt",
        "type": "form",
        "properties": ["cluster_name", "grid_density"]
      },
      {
        "id": "structure",
        "label": "Struktur",
        "type": "tabs",
        "items": [
          {
            "id": "structure_lt4m",
            "label": "< 4m",
            "type": "array",
            "component": "datagrid",
            "property": "structure_lt4m"
          },
          {
            "id": "structure_gt4m",
            "label": "> 4m",
            "type": "array",
            "component": "datagrid",
            "property": "structure_gt4m"
          }
        ]
      }
    ]
  }
}
```

**Result:**

- Main tabs: "Trakt", "Struktur"
- When "Struktur" is selected, shows sub-tabs: "< 4m", "> 4m"
- Both sub-tabs modify root-level properties `structure_lt4m` and `structure_gt4m`
- Validation still works against original schema structure

## Example 2: Card Container

Group multiple arrays in a card layout:

```json
{
  "layout": {
    "type": "tabs",
    "items": [
      {
        "id": "ecology",
        "label": "Ökologie",
        "type": "card",
        "items": [
          {
            "id": "regeneration",
            "label": "Verjüngung",
            "type": "array",
            "component": "datagrid",
            "property": "regeneration"
          },
          {
            "id": "deadwood",
            "label": "Totholz",
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

**Result:**

- Single tab "Ökologie" containing a card
- Card displays both "Verjüngung" and "Totholz" sections vertically
- Both sections modify their respective root properties

## Example 3: Path-Based Properties

Reference nested properties using dot notation:

```json
{
  "layout": {
    "type": "tabs",
    "items": [
      {
        "id": "coordinates",
        "label": "Coordinates",
        "type": "object",
        "component": "form",
        "property": "position.coordinates"
      },
      {
        "id": "landmarks",
        "label": "Landmarks",
        "type": "array",
        "component": "datagrid",
        "property": "plot.landmark"
      }
    ]
  }
}
```

**Schema Structure:**

```json
{
  "properties": {
    "position": {
      "type": "object",
      "properties": {
        "coordinates": {
          "type": "object",
          "properties": {
            "x": { "type": "number" },
            "y": { "type": "number" }
          }
        }
      }
    },
    "plot": {
      "type": "object",
      "properties": {
        "landmark": {
          "type": "array",
          "items": { ... }
        }
      }
    }
  }
}
```

**Result:**

- Tab "Coordinates" edits `position.coordinates` object
- Tab "Landmarks" edits `plot.landmark` array
- Data changes are applied to the correct nested paths
- Validation works on the full schema structure

## Example 4: Complex Multi-Level Nesting

Combine tabs, cards, and nested properties:

```json
{
  "layout": {
    "type": "tabs",
    "items": [
      {
        "id": "basic",
        "label": "Basic",
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
            "type": "card",
            "items": [
              {
                "id": "main_trees",
                "label": "Main Sample",
                "type": "array",
                "component": "datagrid",
                "property": "tree"
              },
              {
                "id": "additional",
                "label": "Additional",
                "type": "array",
                "component": "datagrid",
                "property": "plot.additional_trees"
              }
            ]
          },
          {
            "id": "structure",
            "label": "Structure",
            "type": "tabs",
            "items": [
              {
                "id": "small",
                "label": "< 4m",
                "type": "array",
                "component": "datagrid",
                "property": "structure_lt4m"
              },
              {
                "id": "large",
                "label": "> 4m",
                "type": "array",
                "component": "datagrid",
                "property": "structure_gt4m"
              }
            ]
          }
        ]
      },
      {
        "id": "ecology",
        "label": "Ecology",
        "type": "card",
        "items": [
          {
            "id": "regen",
            "type": "array",
            "component": "datagrid",
            "property": "regeneration"
          },
          {
            "id": "dead",
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

**Navigation Structure:**

```
Main Tabs:
├─ Basic (form)
├─ Measurements (nested tabs)
│  ├─ Trees (card)
│  │  ├─ Main Sample (datagrid)
│  │  └─ Additional (datagrid)
│  └─ Structure (nested tabs)
│     ├─ < 4m (datagrid)
│     └─ > 4m (datagrid)
└─ Ecology (card)
   ├─ Verjüngung (datagrid)
   └─ Totholz (datagrid)
```

## Example 5: Mixed Root and Nested Properties

```json
{
  "layout": {
    "type": "tabs",
    "items": [
      {
        "id": "overview",
        "label": "Overview",
        "type": "card",
        "items": [
          {
            "id": "general",
            "label": "General Info",
            "type": "form",
            "properties": ["cluster_name", "grid_density"]
          },
          {
            "id": "location",
            "label": "Location",
            "type": "object",
            "component": "card",
            "property": "position.coordinates"
          }
        ]
      },
      {
        "id": "data",
        "label": "Data",
        "type": "tabs",
        "items": [
          {
            "id": "root_trees",
            "label": "Trees (Root)",
            "type": "array",
            "component": "datagrid",
            "property": "tree"
          },
          {
            "id": "plot_trees",
            "label": "Trees (Plot)",
            "type": "array",
            "component": "datagrid",
            "property": "plot.tree"
          }
        ]
      }
    ]
  }
}
```

**Key Points:**

- First tab contains a card with both root-level form and nested object
- Second tab contains sub-tabs for arrays at different levels
- Property paths determine where data is stored/validated
- All references point to schema structure

## Benefits of Nested Layouts

### 1. Logical Organization

Group related data together without changing schema structure:

- Structure < 4m and > 4m under single "Structure" tab
- Ecology data (regeneration, deadwood) in one view

### 2. Reduced Clutter

Hide complexity behind nested tabs or cards:

- Main tabs stay clean and focused
- Detailed data available in sub-sections

### 3. Flexible Reorganization

Move items between tabs without code changes:

```json
// Before: flat structure
{"id": "structure_lt4m", "type": "array"}
{"id": "structure_gt4m", "type": "array"}

// After: nested under parent tab
{
  "id": "structure",
  "type": "tabs",
  "items": [
    {"id": "structure_lt4m", ...},
    {"id": "structure_gt4m", ...}
  ]
}
```

### 4. Path-Based Access

Access deeply nested properties:

```json
{
  "property": "plot.measurements.trees.sample_1"
}
```

### 5. Validation Integrity

- Data changes update correct paths
- Validation runs against full schema
- No schema modifications needed

## Implementation Details

### Path Resolution

**Getting values:**

```dart
final data = LayoutService.getValueByPath(formData, 'position.coordinates.x');
// Returns: formData['position']['coordinates']['x']
```

**Setting values:**

```dart
LayoutService.setValueByPath(formData, 'position.coordinates.x', 123);
// Sets: formData['position']['coordinates']['x'] = 123
```

**Getting schema:**

```dart
final schema = LayoutService.getSchemaByPath(schemaProperties, 'position.coordinates');
// Returns: schemaProperties['position']['properties']['coordinates']
```

### Recursive Rendering

The `_buildWidgetFromLayout` method handles all nesting recursively:

```dart
Widget _buildWidgetFromLayout(LayoutItem layoutItem, ...) {
  if (layoutItem is TabsLayout) {
    return _buildNestedTabs(layoutItem, ...);
  } else if (layoutItem is CardLayout) {
    return _buildCardWithChildren(layoutItem, ...);
  }
  // ... other types
}
```

### Data Flow

```
User edits nested field
       ↓
onChange callback
       ↓
LayoutService.setValueByPath(formData, 'plot.tree', updatedArray)
       ↓
Updates: formData['plot']['tree'] = updatedArray
       ↓
Validation runs on full formData
       ↓
Schema validates against original structure
```

## Migration Example

### Before (Hard-coded):

```dart
// Fixed tabs in FormWrapper code
tabs.add(FormTab(id: 'structure_lt4m', label: 'Struktur <4m'));
tabs.add(FormTab(id: 'structure_gt4m', label: 'Struktur >4m'));
```

### After (Layout-driven):

```json
{
  "id": "structure",
  "label": "Struktur",
  "type": "tabs",
  "items": [
    { "id": "structure_lt4m", "label": "< 4m", "property": "structure_lt4m" },
    { "id": "structure_gt4m", "label": "> 4m", "property": "structure_gt4m" }
  ]
}
```

**Result:** Same data structure, better organization, no code changes needed to reorganize!
