# Loading Options

TrinaGrid provides flexible options for displaying loading indicators while data is being processed or loaded. This feature allows you to control both the coverage area of the loading indicator and customize its appearance with your own widgets.

![Loading Options Demo](https://raw.githubusercontent.com/doonfrs/trina_grid/master/doc/assets/loading-options.gif)

## Loading Levels

You can control how much of the grid is covered by the loading indicator using the `TrinaGridLoadingLevel` enum:

| Level | Description |
|-------|-------------|
| `TrinaGridLoadingLevel.grid` | Covers the entire grid area (default) |
| `TrinaGridLoadingLevel.body` | Covers only the body area of the grid |
| `TrinaGridLoadingLevel.row` | Covers only the row area of the grid |

## Basic Usage

To show or hide a loading indicator, use the `setShowLoading` method on the `TrinaGridStateManager`:

```dart
// Show loading with default settings (grid level)
stateManager.setShowLoading(true);

// Show loading with a specific level
stateManager.setShowLoading(true, level: TrinaGridLoadingLevel.body);

// Hide loading
stateManager.setShowLoading(false);
```

The loading indicator can be used to provide visual feedback during asynchronous operations:

```dart
// Show loading indicator
stateManager.setShowLoading(true);

// Perform an asynchronous operation
yourAsyncOperation().then((_) {
  // Hide loading indicator when operation completes
  stateManager.setShowLoading(false);
});
```

## Custom Loading Widgets

For complete control over the loading indicator's appearance, you can provide your own custom widget. This allows you to match your application's branding and style.

```dart
// Show loading with a custom widget
stateManager.setShowLoading(
  true,
  customLoadingWidget: YourCustomLoadingWidget(),
);
```

**Important Note:** When using a custom loading widget, the loading level is always treated as `TrinaGridLoadingLevel.grid`, regardless of the level parameter provided.

### Example Custom Loading Widgets

#### Branded Loading

```dart
Container(
  color: Colors.black.withOpacity(0.7),
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      CircleAvatar(
        radius: 40,
        backgroundColor: Colors.blue,
        child: Icon(
          Icons.grid_on,
          color: Colors.white,
          size: 40,
        ),
      ),
      SizedBox(height: 20),
      Text(
        'Loading data...',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      SizedBox(height: 30),
      SizedBox(
        width: 200,
        child: LinearProgressIndicator(
          backgroundColor: Colors.white.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      ),
    ],
  ),
)
```

#### Shimmer Loading Effect

A shimmer loading effect can create the illusion of content being loaded:

```dart
Container(
  color: Colors.white.withOpacity(0.9),
  child: Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Shimmer loading widgets here
        // See example code for implementation details
      ],
    ),
  ),
)
```

#### Simple Spinner

```dart
Container(
  color: Colors.black.withOpacity(0.5),
  child: Center(
    child: SizedBox(
      width: 100,
      height: 100,
      child: CircularProgressIndicator(
        strokeWidth: 8,
        valueColor: AlwaysStoppedAnimation<Color>(
          Colors.purple.shade400,
        ),
      ),
    ),
  ),
)
```

## Best Practices

- **Provide Feedback**: Always show loading indicators for operations that take more than a few hundred milliseconds.
- **Choose Appropriate Coverage**: Use grid-level loading for operations that affect the entire grid and body-level for operations that only affect the data.
- **Match Your App's Style**: When using custom loading widgets, make sure they match your application's overall design language.
- **Informative Messages**: Include informative text when appropriate to help users understand what's happening.
- **Consider Overlays**: For longer operations, consider using a shimmer effect or placeholder content to indicate that data is loading.

## Complete Example

```dart
class LoadingOptionsExample extends StatefulWidget {
  @override
  _LoadingOptionsExampleState createState() => _LoadingOptionsExampleState();
}

class _LoadingOptionsExampleState extends State<LoadingOptionsExample> {
  late TrinaGridStateManager stateManager;
  
  void _loadData() {
    // Show loading with the default loading widget
    stateManager.setShowLoading(true);
    
    // Simulate a network request
    Future.delayed(const Duration(seconds: 2), () {
      // Hide loading when data is loaded
      if (mounted) {
        stateManager.setShowLoading(false);
      }
    });
  }
  
  void _loadDataWithCustomWidget() {
    // Show loading with a custom widget
    stateManager.setShowLoading(
      true,
      customLoadingWidget: Container(
        color: Colors.black.withOpacity(0.7),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: Colors.blue,
              child: Icon(
                Icons.grid_on,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Fetching your data...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
    
    // Simulate a network request
    Future.delayed(const Duration(seconds: 3), () {
      // Hide loading when data is loaded
      if (mounted) {
        stateManager.setShowLoading(false);
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Loading Options Example')),
      body: Column(
        children: [
          Row(
            children: [
              ElevatedButton(
                onPressed: _loadData,
                child: Text('Show Default Loading'),
              ),
              SizedBox(width: 16),
              ElevatedButton(
                onPressed: _loadDataWithCustomWidget,
                child: Text('Show Custom Loading'),
              ),
            ],
          ),
          Expanded(
            child: TrinaGrid(
              columns: yourColumns,
              rows: yourRows,
              onLoaded: (TrinaGridOnLoadedEvent event) {
                stateManager = event.stateManager;
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

For more examples, refer to the loading options demo in the example application. 