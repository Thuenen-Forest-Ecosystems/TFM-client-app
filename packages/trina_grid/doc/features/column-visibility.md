# Column Viewport Visibility

TrinaGrid provides functionality to check which columns are currently visible in the viewport and to determine if a specific column is within the viewable area. This is particularly useful for optimizing rendering performance and implementing features that need to react to visible columns.

## Checking Visible Columns

### Get Viewport Visible Columns

The `getViewPortVisibleColumns()` method returns a list of columns that are currently visible in the viewport. This allows you to operate only on columns that the user can actually see.

```dart
// Get all columns currently visible in the viewport
List<TrinaColumn> visibleColumns = stateManager.getViewPortVisibleColumns();

// Now you can work with only the visible columns
for (final column in visibleColumns) {
  // Do something with the visible column
}
```

This method is useful when you need to:

- Perform operations only on visible columns to improve performance
- Update only the columns that are currently in view
- Implement custom rendering logic based on visible columns

### Check if a Column is Visible

You can also check if a specific column is currently visible in the viewport using the `isColumnVisibleInViewport()` method:

```dart
// Check if a specific column is visible
bool isVisible = stateManager.isColumnVisibleInViewport(myColumn);

if (isVisible) {
  // Perform actions for visible column
} else {
  // Handle case when column is out of view
}
```

This method is particularly helpful for:

- Conditional rendering based on column visibility
- Optimizing event handlers to ignore off-screen columns
- Implementing viewport-aware behaviors

## Implementation Details

The visibility detection works by:

1. Checking if the column is hidden (`column.hide`)
2. Getting the current grid render box dimensions
3. Calculating the current scroll position and viewport boundaries
4. Determining if the column's position overlaps with the viewport

A column is considered visible if any part of it intersects with the current viewport. This means that partially visible columns (those cut off at the edge of the screen) are also included in the visibility results.

## Example: Viewport-Aware Updates

Here's an example of how to use these methods to implement viewport-aware updates:

```dart
void updateOnlyVisibleColumns() {
  // Get all columns currently visible in the viewport
  final visibleColumns = stateManager.getViewPortVisibleColumns();
  
  // Update only visible columns
  for (final column in visibleColumns) {
    // Apply updates to visible columns only
    updateColumnData(column);
  }
}
```

## Example: Scrolling to Make a Column Visible

You can combine visibility checking with scrolling functionality:

```dart
void ensureColumnIsVisible(TrinaColumn column) {
  // Check if the column is already visible
  if (!stateManager.isColumnVisibleInViewport(column)) {
    // If not visible, scroll to make it visible
    stateManager.scrollToColumn(column);
  }
}
```

## Related Features

- [Column Freezing](column-freezing.md) - Learn about freezing columns in position
- [Column Hiding](column-hiding.md) - Understand how to show and hide columns
- [Scrollbars](scrollbars.md) - Customize scrolling behavior
