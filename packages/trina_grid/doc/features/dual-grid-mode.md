# Dual Grid Mode

TrinaGrid offers a powerful dual grid mode that allows you to display two grids side by side with synchronized keyboard navigation between them. This feature is particularly useful for master-detail relationships or any scenario where two related datasets need to be displayed simultaneously.

## Overview

The dual grid mode provides:

- Two grids arranged horizontally with a customizable divider
- Seamless keyboard navigation between the grids
- Synchronized selection events
- Flexible layout options for controlling grid widths
- Support for both standard and popup display modes

## Basic Usage

```dart
TrinaDualGrid(
  gridPropsA: TrinaDualGridProps(
    columns: leftGridColumns,
    rows: leftGridRows,
    onLoaded: (event) {
      leftGridStateManager = event.stateManager;
    },
    // Other grid properties...
  ),
  gridPropsB: TrinaDualGridProps(
    columns: rightGridColumns,
    rows: rightGridRows,
    onLoaded: (event) {
      rightGridStateManager = event.stateManager;
    },
    // Other grid properties...
  ),
)
```

## Master-Detail Pattern

A common use case for dual grid mode is implementing a master-detail pattern, where selecting a row in the left grid updates the content in the right grid:

```dart
void leftGridHandler() {
  if (leftGridStateManager.currentRow == null) {
    return;
  }

  if (leftGridStateManager.currentRow!.key != currentRowKey) {
    currentRowKey = leftGridStateManager.currentRow!.key;
    
    // Show loading indicator
    rightGridStateManager.setShowLoading(true);
    
    // Fetch related data for the selected row
    fetchRelatedData();
  }
}

// In your initState or onLoaded callback:
leftGridStateManager.addListener(leftGridHandler);
```

## Layout Options

TrinaGrid provides several display options for controlling the width distribution between the two grids:

### Equal Ratio (Default)

```dart
TrinaDualGrid(
  // Grid properties...
  display: TrinaDualGridDisplayRatio(), // 50:50 ratio by default
)
```

### Custom Ratio

```dart
TrinaDualGrid(
  // Grid properties...
  display: TrinaDualGridDisplayRatio(ratio: 0.7), // 70:30 ratio
)
```

### Fixed Left Grid Width

```dart
TrinaDualGrid(
  // Grid properties...
  display: TrinaDualGridDisplayFixedAndExpanded(width: 300), // Left grid fixed at 300px
)
```

### Fixed Right Grid Width

```dart
TrinaDualGrid(
  // Grid properties...
  display: TrinaDualGridDisplayExpandedAndFixed(width: 300), // Right grid fixed at 300px
)
```

## Divider Customization

You can customize the divider between the grids:

```dart
TrinaDualGrid(
  // Grid properties...
  divider: TrinaDualGridDivider(
    show: true, // Show the divider
    backgroundColor: Colors.grey[200]!, // Divider background color
    indicatorColor: Colors.blue, // Center indicator color
    draggingColor: Colors.lightBlue[100]!, // Color when dragging
  ),
)
```

For dark themes, you can use the built-in dark theme divider:

```dart
TrinaDualGrid(
  // Grid properties...
  divider: const TrinaDualGridDivider.dark(),
)
```

## Popup Mode

In addition to the standard dual grid mode, TrinaGrid also offers a popup version that can be triggered from user actions:

```dart
TrinaDualGridPopup(
  context: context,
  gridPropsA: TrinaDualGridProps(
    columns: leftGridColumns,
    rows: leftGridRows,
    // Other properties...
  ),
  gridPropsB: TrinaDualGridProps(
    columns: rightGridColumns,
    rows: rightGridRows,
    // Other properties...
  ),
  width: 800, // Optional custom width
  height: 600, // Optional custom height
  onSelected: (event) {
    // Handle selection
  },
);
```

## Keyboard Navigation

The dual grid mode seamlessly handles keyboard navigation between the two grids:

- When focus is on the right edge of the left grid and you press the right arrow key, focus automatically moves to the right grid
- When focus is on the left edge of the right grid and you press the left arrow key, focus automatically moves to the left grid

## Events

You can listen for selection events across both grids:

```dart
TrinaDualGrid(
  // Grid properties...
  onSelected: (TrinaDualOnSelectedEvent event) {
    // Access selected rows/cells from both grids
    final leftSelectedRow = event.gridA?.row;
    final rightSelectedRow = event.gridB?.row;
    
    // Take action based on selections
  },
)
```

## Example

See the [dual mode example](https://github.com/doonfrs/trina_grid/blob/master/demo/lib/screen/feature/dual_mode_screen.dart) for a complete implementation showing how to use the dual grid mode with dynamic data loading.
