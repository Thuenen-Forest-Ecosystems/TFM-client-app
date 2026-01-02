# Styling Migration Guide

## Overview

This guide documents how to migrate form styling configuration from `validation.json` (`$tfm.form` properties) to `ci2027.json` layout configuration.

## Architecture Principle

**Separation of Concerns:**

- `validation.json` defines **WHAT** the data is (types, constraints, validation rules)
- `ci2027.json` defines **HOW** to display it (layout, styling, UI presentation)

## Migration Path

### Before: Schema-based Styling

```json
{
  "properties": {
    "tree": {
      "type": "array",
      "items": {
        "properties": {
          "tree_number": {
            "type": "integer",
            "$tfm": {
              "form": {
                "sortBy": 1,
                "autoIncrement": true,
                "ui:options": {
                  "pinned": "left",
                  "width": 80
                }
              }
            }
          },
          "tree_species": {
            "type": "string",
            "$tfm": {
              "form": {
                "sortBy": 2,
                "ui:options": {
                  "pinned": "left",
                  "width": 150
                }
              }
            }
          },
          "azimuth": {
            "type": "number",
            "$tfm": {
              "form": {
                "sortBy": 10,
                "groupBy": {
                  "headerName": "Wichtigste",
                  "columnGroupShow": "open",
                  "sortBy": 1
                },
                "ui:options": {
                  "width": 100
                }
              }
            }
          }
        }
      }
    }
  }
}
```

### After: Layout-based Styling

**validation.json** - Only data definition:

```json
{
  "properties": {
    "tree": {
      "type": "array",
      "items": {
        "properties": {
          "tree_number": {
            "type": "integer",
            "title": "Baum Nr."
          },
          "tree_species": {
            "type": "string",
            "title": "Baumart",
            "enum": ["pine", "oak", "beech"]
          },
          "azimuth": {
            "type": "number",
            "title": "Azimut",
            "minimum": 0,
            "maximum": 400
          }
        }
      }
    }
  }
}
```

**ci2027.json** - Layout and styling:

```json
{
  "layout": [
    {
      "id": "tree",
      "label": "WZP",
      "type": "array",
      "component": "datagrid",
      "property": "tree",
      "options": {
        "layout": "fullSize"
      },
      "columns": {
        "tree_number": {
          "pinned": "left",
          "autoIncrement": true,
          "width": 80
        },
        "tree_species": {
          "pinned": "left",
          "width": 150
        },
        "azimuth": {
          "groupBy": {
            "headerName": "Wichtigste",
            "columnGroupShow": "open",
            "sortBy": 1
          },
          "width": 100
        }
      }
    }
  ]
}
```

## Column Configuration Properties

### Supported Properties

| Property        | Type    | Description                | Example             |
| --------------- | ------- | -------------------------- | ------------------- |
| `pinned`        | string  | Pin column to left/right   | `"left"`, `"right"` |
| `width`         | number  | Column width in pixels     | `120`               |
| `display`       | boolean | Show/hide column           | `true`, `false`     |
| `autoIncrement` | boolean | Auto-increment on new rows | `true`              |
| `readonly`      | boolean | Make column read-only      | `true`              |
| `groupBy`       | object  | Column grouping config     | See below           |

### Column Grouping

```json
{
  "groupBy": {
    "headerName": "Wichtigste",
    "columnGroupShow": "open",
    "sortBy": 1
  }
}
```

- `headerName`: Group header label
- `columnGroupShow`: When to show column (`"open"`, `"closed"`)
- `sortBy`: Order of groups

## Array Layout Options

```json
{
  "type": "array",
  "options": {
    "layout": "fullSize",
    "enableAddRow": true,
    "enableDeleteRow": true
  },
  "columns": { ... }
}
```

## Implementation Details

### ArrayElementTrina Widget

The `ArrayElementTrina` widget now accepts optional styling configuration:

```dart
ArrayElementTrina(
  jsonSchema: propertySchema,
  data: propertyData,
  propertyName: propertyName,
  validationResult: validationResult,
  columnConfig: layoutItem.columns,      // Layout column config
  layoutOptions: layoutItem.options,     // Layout options
  onDataChanged: onDataChanged,
)
```

### Configuration Priority

1. **Layout configuration** (if provided via `columnConfig`)
2. **Schema `$tfm.form`** (fallback for backward compatibility)

This ensures:

- New forms can use clean layout-based styling
- Existing forms continue to work without changes
- Gradual migration path is supported

### Helper Method

The `_getColumnConfig()` method merges layout and schema config:

```dart
Map<String, dynamic> _getColumnConfig(String fieldKey, Map<String, dynamic> propertySchema) {
  // 1. Try layout config first
  if (widget.columnConfig?.containsKey(fieldKey) ?? false) {
    return widget.columnConfig![fieldKey];
  }

  // 2. Fallback to schema $tfm.form
  final tfm = propertySchema['\$tfm'];
  final form = tfm?['form'];
  return form ?? {};
}
```

## Migration Steps

1. **Identify** all properties with `$tfm.form` styling in validation.json
2. **Extract** styling properties to layout configuration
3. **Clean** validation.json - remove `$tfm.form.ui:options`, `sortBy`, `groupBy`
4. **Keep** validation properties: `$tfm.unit_short`, `$tfm.name_de`, data validation
5. **Test** form rendering with layout configuration
6. **Verify** backward compatibility with non-layout forms

## Example: Complete Tree Array

### validation.json

```json
{
  "tree": {
    "type": "array",
    "title": "Winkelzählprobe",
    "items": {
      "type": "object",
      "properties": {
        "tree_number": {
          "type": "integer",
          "title": "Baum Nr.",
          "default": 1
        },
        "tree_status": {
          "type": "string",
          "title": "Status",
          "enum": ["standing", "fallen", "dead"]
        },
        "azimuth": {
          "type": "number",
          "title": "Azimut",
          "$tfm": {
            "unit_short": "gon"
          },
          "minimum": 0,
          "maximum": 400
        },
        "dbh": {
          "type": "number",
          "title": "BHD",
          "$tfm": {
            "unit_short": "cm"
          },
          "minimum": 7
        }
      }
    }
  }
}
```

### ci2027.json

```json
{
  "layout": [
    {
      "id": "tree",
      "label": "WZP",
      "type": "array",
      "component": "datagrid",
      "property": "tree",
      "options": {
        "layout": "fullSize"
      },
      "columns": {
        "tree_number": {
          "pinned": "left",
          "autoIncrement": true,
          "width": 80
        },
        "tree_status": {
          "pinned": "left",
          "width": 100
        },
        "azimuth": {
          "groupBy": {
            "headerName": "Wichtigste",
            "sortBy": 1
          },
          "width": 100
        },
        "dbh": {
          "groupBy": {
            "headerName": "Wichtigste",
            "sortBy": 6
          },
          "width": 120
        }
      }
    }
  ]
}
```

## Benefits

✅ **Clean separation** - Data definition vs presentation  
✅ **Reusability** - Same schema, different layouts  
✅ **Flexibility** - Easy to customize per form type  
✅ **Maintainability** - Styling changes don't affect validation  
✅ **Backward compatible** - Existing forms still work

## Next Steps

After migrating styling to layout:

1. Consider removing `$tfm.form` from schema entirely (breaking change)
2. Document remaining valid `$tfm` properties (units, labels, translations)
3. Create layout templates for common patterns
4. Build layout editor UI for non-developers
