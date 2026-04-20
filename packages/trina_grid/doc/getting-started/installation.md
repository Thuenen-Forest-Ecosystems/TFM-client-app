# Installation

Adding TrinaGrid to your Flutter project is straightforward. Follow these steps to get started:

## 1. Add Dependency

Add the following dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  trina_grid: <latest_version>
```

## 2. Install Package

Run the following command to install the package:

```bash
flutter pub get
```

## 3. Import Package

Import the package in your Dart code:

```dart
import 'package:trina_grid/trina_grid.dart';
```

## 4. Optional Dependencies

## Platform-Specific Considerations

### Web

TrinaGrid works well on the web platform without any additional configuration.

### Desktop (Windows, macOS, Linux)

TrinaGrid is optimized for desktop platforms with keyboard navigation and shortcuts.

### Mobile (Android, iOS)

While TrinaGrid works on mobile platforms, it's primarily designed for larger screens. Consider the following when using on mobile:

- Use appropriate column widths for smaller screens
- Consider using fewer columns for better usability
- Test scrolling and touch interactions thoroughly

## Compatibility

TrinaGrid requires:

- Flutter 3.0.0 or higher
- Dart 2.17.0 or higher

## Troubleshooting

If you encounter any issues during installation:

1. Make sure you have the correct version specified in your pubspec.yaml
2. Run `flutter clean` followed by `flutter pub get`
3. Restart your IDE
4. Check for any conflicting dependencies

If problems persist, please [open an issue](https://github.com/doonfrs/trina_grid/issues) on GitHub.
