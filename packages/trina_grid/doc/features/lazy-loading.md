# Lazy Loading

Lazy loading is a performance optimization technique in TrinaGrid that allows you to load data on demand rather than all at once. This approach is particularly useful when dealing with large datasets, as it significantly reduces initial load time and memory usage by only loading the data that is currently needed.

## Overview

TrinaGrid provides a robust lazy loading implementation through the `TrinaLazyPagination` component. This component enables you to fetch and display data in paginated chunks, with built-in support for:

- Server-side pagination
- Server-side sorting
- Server-side filtering
- Customizable page sizes
- Pagination controls

## Benefits of Lazy Loading

- **Improved Performance**: Reduces initial load time and memory usage by loading only the data that is needed
- **Better User Experience**: Provides responsive UI even with large datasets
- **Reduced Network Traffic**: Only transfers the data that is actually being viewed
- **Server-Side Processing**: Offloads data processing to the server, reducing client-side computation

## Implementation

### Basic Setup

To implement lazy loading with pagination in your TrinaGrid, you need to:

1. Create a fetch callback function that returns a `TrinaLazyPaginationResponse`
2. Add the `TrinaLazyPagination` widget to the grid's footer

```dart
TrinaGrid(
  columns: columns,
  rows: [], // Start with empty rows
  onLoaded: (TrinaGridOnLoadedEvent event) {
    stateManager = event.stateManager;
  },
  createFooter: (s) => TrinaLazyPagination(
    initialPage: 1,
    initialFetch: true,
    fetchWithSorting: true,
    fetchWithFiltering: true,
    fetch: fetch,
    stateManager: s,
  ),
)
```

### Fetch Callback

The fetch callback is responsible for loading data when needed. It receives a `TrinaLazyPaginationRequest` and should return a `TrinaLazyPaginationResponse`.

```dart
Future<TrinaLazyPaginationResponse> fetch(
  TrinaLazyPaginationRequest request,
) async {
  // Calculate pagination parameters
  final page = request.page;
  final pageSize = request.pageSize;
  
  // Apply sorting if needed
  if (request.sortColumn != null && !request.sortColumn!.sort.isNone) {
    // Apply sorting logic based on request.sortColumn
  }
  
  // Apply filtering if needed
  if (request.filterRows.isNotEmpty) {
    // Apply filtering logic based on request.filterRows
  }
  
  // Fetch data from your data source for the current page
  final fetchedRows = await yourDataService.fetchPage(
    page: page,
    pageSize: pageSize,
    sortColumn: request.sortColumn,
    filterRows: request.filterRows,
  );
  
  return TrinaLazyPaginationResponse(
    totalPage: totalPageCount,
    rows: fetchedRows,
    totalRecords: totalRecordCount, // Optional
  );
}
```

### Request Parameters

The `TrinaLazyPaginationRequest` provides information about what data to fetch:

- `page`: The page number to fetch (starting from 1)
- `pageSize`: The number of items per page
- `sortColumn`: The column being sorted (if any)
- `filterRows`: The current filter conditions (if any)

### Response Parameters

The `TrinaLazyPaginationResponse` requires:

- `totalPage`: The total number of pages available
- `rows`: The list of rows for the current page
- `totalRecords`: (Optional) The total number of records across all pages

## Configuration Options

The `TrinaLazyPagination` widget accepts several configuration options:

- `initialPage` (default: 1): The page to load initially
- `initialPageSize` (default: 10): The number of items per page
- `initialFetch` (default: true): Whether to fetch data when the grid is first loaded
- `fetchWithSorting` (default: true): Whether sorting should be handled by the fetch callback
- `fetchWithFiltering` (default: true): Whether filtering should be handled by the fetch callback
- `pageSizeToMove`: How many pages to move when clicking the previous/next buttons
- `showPageSizeSelector` (default: false): Whether to show a dropdown to change page size
- `pageSizes` (default: [10, 20, 30, 50, 100]): Available page size options in the dropdown
- `fetch`: The callback function to fetch data
- `stateManager`: The TrinaGrid state manager

## Handling Sorting and Filtering

When `fetchWithSorting` or `fetchWithFiltering` is set to true, the grid will call the fetch function with the appropriate parameters when the user changes the sort or filter settings.

### Sorting

When sorting is enabled, the `sortColumn` parameter in the request will contain information about which column is being sorted and in what direction.

```dart
if (request.sortColumn != null && !request.sortColumn!.sort.isNone) {
  // Get sort direction
  final isAscending = request.sortColumn!.sort.isAscending;
  
  // Get sort field
  final sortField = request.sortColumn!.field;
  
  // Apply sorting logic
  // ...
}
```

### Filtering

When filtering is enabled, the `filterRows` parameter in the request will contain the filter conditions.

```dart
if (request.filterRows.isNotEmpty) {
  // Convert filter rows to a more usable format
  final filterMap = FilterHelper.convertRowsToMap(request.filterRows);
  
  // Or create a filter function
  final filter = FilterHelper.convertRowsToFilter(
    request.filterRows,
    stateManager.refColumns,
  );
  
  // Apply filtering logic
  // ...
}
```

## Page Size Selection

You can enable a page size selector dropdown by setting `showPageSizeSelector` to true:

```dart
TrinaLazyPagination(
  // ... other parameters
  showPageSizeSelector: true,
  pageSizes: [10, 25, 50, 100],
  onPageSizeChanged: (newPageSize) {
    // Optional callback when page size changes
    print('Page size changed to $newPageSize');
  },
  // ... other parameters
)
```

## Complete Example

Here's a complete example of implementing lazy loading with pagination in TrinaGrid:

```dart
class MyGridScreen extends StatefulWidget {
  @override
  _MyGridScreenState createState() => _MyGridScreenState();
}

class _MyGridScreenState extends State<MyGridScreen> {
  late List<TrinaColumn> columns;
  late List<TrinaRow> rows;
  late TrinaGridStateManager stateManager;
  
  @override
  void initState() {
    super.initState();
    
    // Define your columns
    columns = [
      TrinaColumn(
        title: 'ID',
        field: 'id',
        type: TrinaColumnType.number(),
      ),
      TrinaColumn(
        title: 'Name',
        field: 'name',
        type: TrinaColumnType.text(),
      ),
      // Add more columns as needed
    ];
    
    // Start with an empty list of rows
    rows = [];
  }
  
  Future<TrinaLazyPaginationResponse> fetch(
    TrinaLazyPaginationRequest request,
  ) async {
    // In a real application, you would fetch data from an API
    // This is a simplified example
    
    // Apply sorting if needed
    String? sortField;
    bool? sortAscending;
    
    if (request.sortColumn != null && !request.sortColumn!.sort.isNone) {
      sortField = request.sortColumn!.field;
      sortAscending = request.sortColumn!.sort.isAscending;
    }
    
    // Apply filtering if needed
    Map<String, dynamic>? filters;
    
    if (request.filterRows.isNotEmpty) {
      filters = FilterHelper.convertRowsToMap(request.filterRows);
    }
    
    // Fetch data from your API
    final response = await yourApiService.fetchPaginatedData(
      page: request.page,
      pageSize: request.pageSize,
      sortField: sortField,
      sortAscending: sortAscending,
      filters: filters,
    );
    
    // Convert API response to TrinaRows
    final fetchedRows = response.items.map((item) => TrinaRow(
      cells: {
        'id': TrinaCell(value: item.id),
        'name': TrinaCell(value: item.name),
        // Add more cells as needed
      },
    )).toList();
    
    return TrinaLazyPaginationResponse(
      totalPage: response.totalPages,
      rows: fetchedRows,
      totalRecords: response.totalRecords,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Lazy Loading Grid')),
      body: TrinaGrid(
        columns: columns,
        rows: rows,
        onLoaded: (TrinaGridOnLoadedEvent event) {
          stateManager = event.stateManager;
          stateManager.setShowColumnFilter(true);
        },
        createFooter: (s) => TrinaLazyPagination(
          initialPage: 1,
          initialPageSize: 25,
          initialFetch: true,
          fetchWithSorting: true,
          fetchWithFiltering: true,
          showPageSizeSelector: true,
          pageSizes: [10, 25, 50, 100],
          fetch: fetch,
          stateManager: s,
        ),
      ),
    );
  }
}
```

## Demo

You can find a complete working example of lazy loading with pagination in the TrinaGrid demo project under `demo/lib/screen/feature/row_lazy_pagination_screen.dart`. The demo shows how to implement lazy loading with sorting and filtering support.

## Related Features

- [Infinite Scrolling](infinite-scrolling.md) - For continuous scrolling with on-demand data loading
- [Client-Side Pagination](pagination-client.md) - For client-side pagination
- [Pagination Overview](pagination.md) - For a general overview of pagination options
