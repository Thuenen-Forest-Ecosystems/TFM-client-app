# Change Tracking

Change tracking is a powerful feature in TrinaGrid that allows you to monitor and manage modifications to cell values. This feature helps users identify which cells have been modified but not yet committed, and provides functionality to commit or revert these changes.

![Change Tracking Demo](https://raw.githubusercontent.com/doonfrs/trina_grid/master/doc/assets/change-tracking.gif)

## Overview

The change tracking feature enables you to:

- Track modifications to cell values
- Visually highlight cells with uncommitted changes
- Commit changes globally or for specific cells
- Revert changes globally or for specific cells
- Monitor the number of dirty (modified) cells
- Integrate with your application's data management workflow

## Enabling Change Tracking

To enable change tracking, use the `setChangeTracking` method on the grid's state manager:

```dart
stateManager.setChangeTracking(true);
```

You can also configure the visual appearance of dirty cells using the grid's configuration:

```dart
TrinaGrid(
  columns: columns,
  rows: rows,
  configuration: TrinaGridConfiguration(
    style: TrinaGridStyleConfig(
      cellDirtyColor: Colors.amber[100]!, // Customize the color for dirty cells
    ),
  ),
)
```

## Managing Changes

### Checking if a Cell is Dirty

You can check if a cell has uncommitted changes using the `isDirty` property:

```dart
bool hasPendingChanges = cell.isDirty;
```

### Committing Changes

To commit changes, you can use the `commitChanges` method. You can either commit all changes or specify a particular cell:

```dart
// Commit all changes
stateManager.commitChanges();

// Commit changes for a specific cell
stateManager.commitChanges(cell: specificCell);
```

### Reverting Changes

To revert changes back to their original values:

```dart
// Revert all changes
stateManager.revertChanges();

// Revert changes for a specific cell
stateManager.revertChanges(cell: specificCell);
```

## Example Implementation

Here's a complete example showing how to implement change tracking with UI controls:

```dart
class ChangeTrackingScreen extends StatefulWidget {
  @override
  _ChangeTrackingScreenState createState() => _ChangeTrackingScreenState();
}

class _ChangeTrackingScreenState extends State<ChangeTrackingScreen> {
  final List<TrinaColumn> columns = [];
  final List<TrinaRow> rows = [];
  late TrinaGridStateManager stateManager;
  
  // Use ValueNotifier for efficient updates without rebuilding the entire widget
  final ValueNotifier<bool> changeTrackingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<TrinaCell?> selectedCellNotifier = ValueNotifier<TrinaCell?>(null);
  final ValueNotifier<int> dirtyCountNotifier = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Controls for change tracking
        Row(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: changeTrackingNotifier,
              builder: (context, isEnabled, _) {
                return Switch(
                  value: isEnabled,
                  onChanged: (flag) {
                    changeTrackingNotifier.value = flag;
                    stateManager.setChangeTracking(flag);
                    updateDirtyCount();
                  },
                );
              },
            ),
            const Text('Enable Change Tracking'),
            ValueListenableBuilder<int>(
              valueListenable: dirtyCountNotifier,
              builder: (context, count, _) {
                return Text(
                  'Dirty Cells: $count',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: count > 0 ? Colors.orange : Colors.black,
                  ),
                );
              },
            ),
          ],
        ),
        
        // Commit/Revert buttons
        ValueListenableBuilder<TrinaCell?>(
          valueListenable: selectedCellNotifier,
          builder: (context, selectedCell, _) {
            return Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    stateManager.commitChanges();
                    updateDirtyCount();
                  },
                  child: const Text('Commit All Changes'),
                ),
                ElevatedButton(
                  onPressed: () {
                    stateManager.revertChanges();
                    updateDirtyCount();
                  },
                  child: const Text('Revert All Changes'),
                ),
                ElevatedButton(
                  onPressed: selectedCell != null
                      ? () {
                          stateManager.commitChanges(cell: selectedCell);
                          updateDirtyCount();
                        }
                      : null,
                  child: const Text('Commit Selected Cell'),
                ),
                ElevatedButton(
                  onPressed: selectedCell != null
                      ? () {
                          stateManager.revertChanges(cell: selectedCell);
                          updateDirtyCount();
                        }
                      : null,
                  child: const Text('Revert Selected Cell'),
                ),
              ],
            );
          },
        ),
        
        // The grid
        Expanded(
          child: TrinaGrid(
            columns: columns,
            rows: rows,
            onChanged: (event) {
              if (changeTrackingNotifier.value) {
                updateDirtyCount();
              }
            },
            onLoaded: (event) {
              stateManager = event.stateManager;
              stateManager.setSelectingMode(TrinaGridSelectingMode.cell);
            },
            onActiveCellChanged: (event) {
              selectedCellNotifier.value = event.cell;
            },
            configuration: TrinaGridConfiguration(
              style: TrinaGridStyleConfig(
                cellDirtyColor: Colors.amber[100]!,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Update the count of dirty cells
  void updateDirtyCount() {
    int count = 0;
    for (var row in rows) {
      for (var cell in row.cells.values) {
        if (cell.isDirty) {
          count++;
        }
      }
    }
    dirtyCountNotifier.value = count;
  }
}
```

## Best Practices

1. **Efficient State Management**: Use `ValueNotifier` or similar state management solutions to avoid unnecessary rebuilds when tracking changes.

2. **Visual Feedback**: Provide clear visual indicators for:
   - Cells with uncommitted changes
   - The total number of modified cells
   - Whether change tracking is enabled/disabled

3. **Granular Control**: Offer both global and cell-level options for committing and reverting changes.

4. **Error Handling**: Implement proper error handling when committing or reverting changes, especially if these operations involve backend services.

5. **Performance**: For large datasets, consider optimizing the dirty cell count calculation or using a more efficient tracking mechanism.

## Integration with Other Features

Change tracking works seamlessly with other TrinaGrid features:

- **Cell Editing**: Track changes made during cell editing
- **Copy/Paste**: Monitor changes made through paste operations
- **Keyboard Navigation**: Maintain tracking state while navigating with keyboard
- **Data Validation**: Validate changes before marking cells as dirty

## Events and Callbacks

The following events are relevant for change tracking:

- `onChanged`: Triggered when a cell value changes
- `onActiveCellChanged`: Useful for tracking the currently selected cell
- `onLoaded`: Used to initialize the state manager and configure change tracking

## Limitations and Considerations

1. Change tracking increases memory usage as it needs to maintain the original values.
2. For very large datasets, frequent updates to the dirty cell count might impact performance.
3. The feature works best with primitive data types; complex objects might require custom comparison logic.

## See Also

- [Cell Editing](cell-editing.md)
- [Data Validation](cell-validation.md)
- [Cell Selection](cell-selection.md)
