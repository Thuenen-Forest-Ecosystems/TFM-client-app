# Client-Side Pagination in Trina Grid

Client-side pagination is suitable for smaller datasets that can be loaded entirely into memory. It handles pagination logic on the client side without requiring server requests for each page change.

## Overview

Client-side pagination in TrinaGrid:

- Handles all pagination logic locally
- Suitable for datasets that fit in memory
- Provides smooth user experience with instant page changes
- Maintains sorting and filtering capabilities on the full dataset

## Basic Implementation

To add client-side pagination to your grid, simply add the `TrinaPagination` widget to your grid's footer:

```dart
TrinaGrid(
  columns: columns,
  rows: rows,
  createFooter: (stateManager) {
    return TrinaPagination(
      stateManager: stateManager,
    );
  },
)
```

## Configuration Options

The `TrinaPagination` widget supports several configuration options:

```dart
TrinaPagination(
  stateManager: stateManager,
  // Number of pages to move with prev/next buttons
  // Default: null (moves by visible page count)
  pageSizeToMove: 1,
)
```

## Page Size Configuration

You can configure the default page size and change it programmatically:

```dart
// Set default page size in state manager
stateManager.setPageSize(20);

// Get current page size
int currentPageSize = stateManager.pageSize;

// Get total number of pages
int totalPages = stateManager.totalPage;
```

## Navigation Methods

The state manager provides several methods for programmatic page navigation:

```dart
// Move to a specific page
stateManager.setPage(pageNumber);

// Reset to first page
stateManager.resetPage();

// Get current page number
int currentPage = stateManager.page;

// Get page range
int rangeFrom = stateManager.pageRangeFrom;
int rangeTo = stateManager.pageRangeTo;
```

## Working with Row Groups

Client-side pagination works seamlessly with row grouping:

```dart
// Check if pagination is active
bool isPaginated = stateManager.isPaginated;

// Get paginated rows with groups
if (stateManager.enabledRowGroups) {
  // Pagination will respect group structure
  // and keep parent-child relationships intact
}
```

## Complete Example

Here's a complete example demonstrating client-side pagination:

```dart
class MyDataGrid extends StatefulWidget {
  @override
  _MyDataGridState createState() => _MyDataGridState();
}

class _MyDataGridState extends State<MyDataGrid> {
  late TrinaGridStateManager stateManager;
  final List<TrinaColumn> columns = [];
  final List<TrinaRow> rows = [];

  @override
  void initState() {
    super.initState();
    // Initialize your columns and rows here
    columns.addAll([
      TrinaColumn(
        title: 'ID',
        field: 'id',
        type: TrinaColumnType.text(),
      ),
      TrinaColumn(
        title: 'Name',
        field: 'name',
        type: TrinaColumnType.text(),
      ),
    ]);

    // Add sample data
    rows.addAll([
      TrinaRow(cells: {
        'id': TrinaCell(value: '1'),
        'name': TrinaCell(value: 'John Doe'),
      }),
      // ... more rows
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return TrinaGrid(
      columns: columns,
      rows: rows,
      onLoaded: (event) {
        stateManager = event.stateManager;
        // Configure initial page size
        stateManager.setPageSize(10);
      },
      createFooter: (stateManager) => TrinaPagination(
        stateManager: stateManager,
        pageSizeToMove: 1,
      ),
    );
  }
}
```

## Best Practices

1. **Dataset Size**
   - Use client-side pagination for smaller datasets (typically < 1000 rows)
   - Consider lazy pagination for larger datasets

2. **Page Size**
   - Choose a reasonable page size based on your UI and data
   - Consider screen size and data complexity
   - Typical values range from 10-50 rows per page

3. **Performance**
   - Monitor memory usage with large datasets
   - Consider implementing virtualization for better performance
   - Test pagination with sorting and filtering enabled

4. **User Experience**
   - Provide clear pagination controls
   - Show total record count when available
   - Maintain consistent page sizes across sessions

## Related Features

- For server-side pagination, see [Lazy Pagination](lazy-pagination.md)
- For infinite scrolling, see [Infinity Scroll](infinity-scroll.md)
