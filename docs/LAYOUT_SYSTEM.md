# TFM Layout Configuration System

## Overview

The TFM Layout System separates form **structure/presentation** from **data/validation**. This allows you to:

- Define how forms are displayed without modifying code
- Create different layouts for the same data schema
- Support multiple component types (tabs, cards, datagrids, etc.)
- Maintain backward compatibility with existing forms

## Architecture

### Separation of Concerns

1. **Validation Schema** (`validation.json`) - Defines WHAT the data is:

   - Data types, constraints, validation rules
   - Field labels, descriptions
   - Enum values and their translations
   - Business logic constraints

2. **Layout Configuration** (`ci2027.json`) - Defines HOW to display the data:
   - Tab structure and order
   - Component types for arrays and objects
   - Which fields appear where
   - Visual organization

### Key Components

- **Layout Models** (`lib/models/layout_config.dart`) - Data structures for layout configuration
- **Layout Service** (`lib/services/layout_service.dart`) - Loading and parsing layouts
- **FormWrapper** (`lib/widgets/form-elements/form-wrapper.dart`) - Dynamic form renderer

## Layout Configuration Format

### Basic Structure

```json
{
  "version": "1.0.0",
  "description": "Layout configuration for TFM forms",
  "layout": {
    "type": "tabs",
    "items": [
      // Layout items here
    ]
  },
  "components": {
    // Component definitions (documentation only)
  }
}
```

### Layout Item Types

#### 1. Form Layout (Primitive Fields)

Displays a collection of primitive fields (strings, numbers, booleans).

```json
{
  "id": "info",
  "label": "Trakt",
  "type": "form",
  "properties": ["cluster_name", "grid_density", "inspire_grid_cell"]
}
```

- **id**: Unique identifier for the tab/section
- **label**: Display label for the tab
- **type**: Must be "form"
- **properties**: Array of property names from validation schema

#### 2. Array Layout (Data Grid)

Displays array data using a data grid component.

```json
{
  "id": "tree",
  "label": "WZP",
  "type": "array",
  "component": "datagrid",
  "property": "tree"
}
```

- **id**: Unique identifier
- **label**: Display label
- **type**: Must be "array"
- **component**: Component to use ("datagrid")
- **property**: Property name in validation schema

#### 3. Object Layout (Navigation, Card, etc.)

Displays object data using specialized components.

```json
{
  "id": "position",
  "label": "Position",
  "type": "object",
  "component": "navigation",
  "property": "position"
}
```

- **id**: Unique identifier
- **label**: Display label
- **type**: Must be "object"
- **component**: Component to use ("navigation", "card", "form")
- **property**: Property name in validation schema

#### 4. Nested Layouts (Future)

Support for nested tabs or cards with children.

```json
{
  "id": "advanced",
  "label": "Advanced",
  "type": "card",
  "children": [
    {
      "id": "settings",
      "type": "form",
      "properties": ["setting1", "setting2"]
    }
  ]
}
```

## Supported Components

### Current Implementation

| Component    | Type        | Description                 | Widget              |
| ------------ | ----------- | --------------------------- | ------------------- |
| `datagrid`   | array       | Data grid for array editing | `ArrayElementTrina` |
| `navigation` | object      | Map/location component      | `NavigationElement` |
| `form`       | form/object | Generic form fields         | `GenericForm`       |

### Future Components

| Component    | Type   | Description             |
| ------------ | ------ | ----------------------- |
| `card`       | object | Card layout for objects |
| `expandable` | object | Collapsible sections    |
| `list`       | array  | List view for arrays    |
| `table`      | array  | Simple table view       |

## Usage

### In FormWrapper

```dart
FormWrapper(
  jsonSchema: _jsonSchema,
  formData: _formData,
  layoutName: 'ci2027', // Specify layout configuration
  onFormDataChanged: _onFormDataChanged,
  validationResult: _validationResult,
)
```

### Backward Compatibility

If no `layoutName` is provided or the layout file is not found, FormWrapper automatically falls back to the hard-coded structure:

```dart
FormWrapper(
  jsonSchema: _jsonSchema,
  formData: _formData,
  // No layoutName - uses fallback
  onFormDataChanged: _onFormDataChanged,
)
```

## Creating Custom Layouts

### Step 1: Create Layout File

Create a new JSON file in `assets/schema/`:

```bash
touch assets/schema/my-custom-layout.json
```

### Step 2: Define Layout Structure

```json
{
  "version": "1.0.0",
  "description": "Custom layout for specific use case",
  "layout": {
    "type": "tabs",
    "items": [
      {
        "id": "basic",
        "label": "Basic Info",
        "type": "form",
        "properties": ["field1", "field2"]
      },
      {
        "id": "details",
        "label": "Details",
        "type": "array",
        "component": "datagrid",
        "property": "items"
      }
    ]
  }
}
```

### Step 3: Use Layout

```dart
FormWrapper(
  jsonSchema: schema,
  formData: data,
  layoutName: 'my-custom-layout',
  // ...
)
```

## Layout Service API

### Loading Layouts

```dart
// Load a layout configuration
final layout = await LayoutService.loadLayout('ci2027');

// Clear cache (useful for hot reload)
LayoutService.clearCache();
```

### Querying Layouts

```dart
// Get all tab items
final tabs = LayoutService.getTabItems(layoutConfig);

// Find item by ID
final item = LayoutService.findItemById(layoutConfig, 'tree');

// Get property for item
final property = LayoutService.getPropertyForItem(item);

// Get component type
final component = LayoutService.getComponentType(item);

// Type checks
final isArray = LayoutService.isArrayLayout(item);
final isForm = LayoutService.isFormLayout(item);
final isObject = LayoutService.isObjectLayout(item);
```

## Best Practices

### 1. Keep Layout Simple

Layout should only define structure, not content. All labels, validations, and data definitions belong in the validation schema.

❌ **Bad** - Duplicating content in layout:

```json
{
  "id": "tree",
  "label": "WZP",
  "description": "Winkelzählprobe", // Don't duplicate
  "validation": { "required": true } // Don't add validation
}
```

✅ **Good** - Reference schema:

```json
{
  "id": "tree",
  "type": "array",
  "component": "datagrid",
  "property": "tree" // Reference validation schema
}
```

### 2. Use Meaningful IDs

IDs should be descriptive and match the data they represent:

```json
{
  "id": "tree", // Good - matches property name
  "property": "tree"
}
```

### 3. Organize by User Workflow

Structure tabs in the order users will typically work through them:

```json
{
  "items": [
    { "id": "info" }, // General info first
    { "id": "position" }, // Location second
    { "id": "tree" }, // Main data entry
    { "id": "advanced" } // Advanced last
  ]
}
```

### 4. Test Fallback Behavior

Always test that forms work when layout is missing or invalid:

```dart
// Should still work without layout
FormWrapper(
  jsonSchema: schema,
  formData: data,
  // layoutName not provided
)
```

## Migration Guide

### From Hard-coded to Layout-based

**Before:**

```dart
// Form structure hard-coded in FormWrapper
List<FormTab> _buildTabsList() {
  return [
    FormTab(id: 'info', label: 'Trakt'),
    FormTab(id: 'tree', label: 'WZP'),
    // ...
  ];
}
```

**After:**

```dart
// Layout defined in ci2027.json
{
  "layout": {
    "type": "tabs",
    "items": [
      {"id": "info", "label": "Trakt", "type": "form"},
      {"id": "tree", "type": "array", "component": "datagrid"}
    ]
  }
}

// FormWrapper automatically uses layout
FormWrapper(layoutName: 'ci2027', ...)
```

## Troubleshooting

### Layout Not Loading

**Symptom**: Form uses fallback structure even though layout file exists

**Solutions**:

1. Check file is in `assets/schema/`
2. Verify `pubspec.yaml` includes assets:
   ```yaml
   assets:
     - assets/schema/
   ```
3. Run `flutter pub get`
4. Check console for error messages

### Invalid JSON

**Symptom**: `Failed to load layout` error in console

**Solutions**:

1. Validate JSON syntax using a JSON validator
2. Check all required fields are present
3. Verify property names match validation schema

### Wrong Component Type

**Symptom**: "Unsupported component" message displayed

**Solutions**:

1. Check component name matches supported types
2. Verify component type matches data type (e.g., 'datagrid' for arrays)
3. Check LayoutService.getComponentType() implementation

## Future Enhancements

- [ ] Card component for object display
- [ ] Expandable sections for complex forms
- [ ] Alternative array components (list, table)
- [ ] Conditional layouts based on data state
- [ ] Layout templates and inheritance
- [ ] Visual layout editor

## Example: Complete ci2027.json

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "version": "1.0.0",
  "description": "Layout configuration for TFM CI2027 forms",
  "layout": {
    "type": "tabs",
    "items": [
      {
        "id": "info",
        "label": "Trakt",
        "type": "form",
        "properties": [
          "cluster_name",
          "grid_density",
          "inspire_grid_cell",
          "state_responsible"
        ]
      },
      {
        "id": "position",
        "label": "Position",
        "type": "object",
        "component": "navigation",
        "property": "position"
      },
      {
        "id": "tree",
        "label": "WZP",
        "type": "array",
        "component": "datagrid",
        "property": "tree"
      }
    ]
  }
}
```
