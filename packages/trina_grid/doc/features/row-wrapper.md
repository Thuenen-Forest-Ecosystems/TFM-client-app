# Row Wrapper

The `rowWrapper` feature in TrinaGrid allows you to customize the rendering of each row by wrapping the default row widget with your own widget or logic. This is useful for adding custom styling, interactivity, or additional UI elements to every row in the grid.

## Overview

- **Purpose:** Customize how each row is displayed with access to both the row widget and its data.
- **Type:**

  ```dart
  typedef RowWrapper = Widget Function(
    BuildContext context,
    Widget rowWidget,
    TrinaRow rowData,
    TrinaGridStateManager stateManager,
  );
  ```

- **Where to use:** Pass as the `rowWrapper` property to the `TrinaGrid` widget.

## Example Usage

```dart
TrinaGrid(
  columns: columns,
  rows: rows,
  rowWrapper: (context, rowWidget, rowData, stateManager) {
    // Example: Add a colored border to each row
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blueAccent),
        borderRadius: BorderRadius.circular(4),
      ),
      child: rowWidget,
    );
  },
)
```

### Advanced Example: Conditional Styling Based on Row Data

```dart
TrinaGrid(
  columns: columns,
  rows: rows,
  rowWrapper: (context, rowWidget, rowData, stateManager) {
    // Access cell values from rowData to apply conditional styling
    final statusValue = rowData.cells['status']?.value;
    final isHighPriority = statusValue == 'urgent';
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isHighPriority ? Colors.red.withOpacity(0.1) : null,
        border: Border.all(
          color: isHighPriority ? Colors.red : Colors.blueAccent,
          width: isHighPriority ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: rowWidget,
    );
  },
)
```

## Use Cases

- Add custom borders, backgrounds, or shadows to rows.
- Apply conditional styling based on row data values.
- Attach gesture detectors or context menus.
- Animate row appearance or add tooltips.
- Implement row-level status indicators or badges based on cell values.
- Create row-specific hover effects or highlights.

## Notes

- If `rowWrapper` is not provided, the default row widget is used.
- The wrapper receives:
  - `context`: The build context
  - `rowWidget`: The default row widget (previously named `row`)
  - `rowData`: The TrinaRow instance containing all cell data
  - `stateManager`: The grid state manager for maximum flexibility
- You can access cell values through `rowData.cells[fieldName]?.value`
- The `rowData` parameter enables data-driven row customization without requiring state manager queries.

## Migration from Previous Versions

If you're upgrading from a version prior to 2.1.0, update your rowWrapper callbacks:

```dart
// Old signature (before 2.1.0)
rowWrapper: (context, row, stateManager) {
  return Container(child: row);
}

// New signature (2.1.0+)
rowWrapper: (context, rowWidget, rowData, stateManager) {
  return Container(child: rowWidget);
}
```
