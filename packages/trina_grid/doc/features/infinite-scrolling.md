# Infinite Scrolling

Infinite scrolling is a feature in TrinaGrid that allows you to load data dynamically as the user scrolls through the grid. This approach is particularly useful for handling large datasets efficiently, as it loads only the data that is currently needed, reducing initial load time and memory usage.

## Overview

The infinite scrolling feature in TrinaGrid is implemented through the `TrinaInfinityScrollRows` widget, which can be added to the grid's footer. This widget monitors the scroll position and triggers data loading when the user reaches the end of the currently loaded data.

Key benefits of infinite scrolling:

- **Improved Performance**: Only loads the data that's needed, reducing memory usage and initial load time
- **Better User Experience**: Provides a seamless scrolling experience without pagination controls
- **Server-Side Processing**: Supports server-side sorting and filtering
- **Keyboard Navigation**: Loads more data when navigating with arrow keys or Page Down

## Implementation

### Basic Setup

To implement infinite scrolling in your TrinaGrid, you need to:

1. Create a fetch callback function that returns a `TrinaInfinityScrollRowsResponse`
2. Add the `TrinaInfinityScrollRows` widget to the grid's footer

```dart
TrinaGrid(
  columns: columns,
  rows: rows,  // Can be initially empty
  onLoaded: (TrinaGridOnLoadedEvent event) {
    stateManager = event.stateManager;
  },
  createFooter: (s) => TrinaInfinityScrollRows(
    initialFetch: true,
    fetchWithSorting: true,
    fetchWithFiltering: true,
    fetch: fetch,
    stateManager: s,
  ),
)
```

### Fetch Callback

The fetch callback is responsible for loading data when needed. It receives a `TrinaInfinityScrollRowsRequest` and should return a `TrinaInfinityScrollRowsResponse`.

```dart
Future<TrinaInfinityScrollRowsResponse> fetch(
  TrinaInfinityScrollRowsRequest request,
) async {
  // Fetch data from your data source
  List<TrinaRow> fetchedRows = await yourDataFetchingLogic(request);
  
  // Determine if this is the last batch of data
  bool isLast = noMoreDataAvailable;
  
  return TrinaInfinityScrollRowsResponse(
    isLast: isLast,
    rows: fetchedRows,
  );
}
```

### Request Parameters

The `TrinaInfinityScrollRowsRequest` provides information about what data to fetch:

- `lastRow`: The last row currently displayed in the grid (null for initial fetch)
- `sortColumn`: The column being sorted (if any)
- `filterRows`: The current filter conditions (if any)

### Response Parameters

The `TrinaInfinityScrollRowsResponse` requires:

- `isLast`: Set to true when there is no more data to load
- `rows`: The list of rows to be added to the grid

## Configuration Options

The `TrinaInfinityScrollRows` widget accepts several configuration options:

- `initialFetch` (default: true): Whether to fetch data when the grid is first loaded
- `fetchWithSorting` (default: true): Whether sorting should be handled by the fetch callback
- `fetchWithFiltering` (default: true): Whether filtering should be handled by the fetch callback
- `fetch`: The callback function to fetch data
- `stateManager`: The TrinaGrid state manager

## Handling Sorting and Filtering

When `fetchWithSorting` or `fetchWithFiltering` is set to true, the grid will call the fetch function with the appropriate parameters when the user changes the sort or filter settings.

### Sorting

When sorting is enabled, the `sortColumn` parameter in the request will contain information about which column is being sorted and in what direction.

```dart
if (request.sortColumn != null && !request.sortColumn!.sort.isNone) {
  // Apply sorting logic based on request.sortColumn
}
```

### Filtering

When filtering is enabled, the `filterRows` parameter in the request will contain the filter conditions.

```dart
if (request.filterRows.isNotEmpty) {
  // Apply filtering logic based on request.filterRows
  // You can use FilterHelper to convert the filter rows to a more usable format
  final filter = FilterHelper.convertRowsToFilter(
    request.filterRows,
    stateManager.refColumns,
  );
}
```

## Events That Trigger Data Loading

Data loading is triggered in the following scenarios:

1. When the grid is first loaded (if `initialFetch` is true)
2. When the user scrolls to the bottom of the grid
3. When the user tries to navigate beyond the last row using arrow keys
4. When the user changes the sort settings (if `fetchWithSorting` is true)
5. When the user changes the filter settings (if `fetchWithFiltering` is true)

## Example Implementation

Here's a complete example of implementing infinite scrolling with TrinaGrid:

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
  
  Future<TrinaInfinityScrollRowsResponse> fetch(
    TrinaInfinityScrollRowsRequest request,
  ) async {
    // Get the last ID to determine what data to fetch next
    final lastId = request.lastRow?.cells['id']?.value as int? ?? 0;
    
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
    final response = await yourApiService.fetchData(
      lastId: lastId,
      pageSize: 30,
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
    
    return TrinaInfinityScrollRowsResponse(
      isLast: response.isLastPage,
      rows: fetchedRows,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Infinite Scrolling Grid')),
      body: TrinaGrid(
        columns: columns,
        rows: rows,
        onLoaded: (TrinaGridOnLoadedEvent event) {
          stateManager = event.stateManager;
          stateManager.setShowColumnFilter(true);
        },
        createFooter: (s) => TrinaInfinityScrollRows(
          initialFetch: true,
          fetchWithSorting: true,
          fetchWithFiltering: true,
          fetch: fetch,
          stateManager: s,
        ),
      ),
    );
  }
}
```

## Demo

You can find a complete working example of infinite scrolling in the TrinaGrid demo project under `demo/lib/screen/feature/row_infinity_scroll_screen.dart`. The demo shows how to implement infinite scrolling with sorting and filtering support.

## Related Features

- [Lazy Pagination](lazy-pagination.md) - For page-based loading with lazy loading
- [Client Pagination](pagination-client.md) - For client-side pagination
