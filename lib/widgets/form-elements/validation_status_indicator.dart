import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';

/// Helper class for displaying validation status indicators in grid rows
class ValidationStatusIndicator {
  /// Builds a validation status indicator widget for a specific row
  ///
  /// Returns a colored circle indicator:
  /// - Red: Row has errors
  /// - Orange/Yellow: Row has warnings
  /// - Green: Row is valid (no errors or warnings)
  static Widget build({
    required int rowIndex,
    required String propertyName,
    TFMValidationResult? validationResult,
  }) {
    if (validationResult == null) {
      // No validation result yet - show neutral/gray
      return const Center(child: Icon(Icons.circle, size: 12, color: Colors.grey));
    }

    // Check if this row has any errors or warnings
    final hasErrors = _hasRowErrors(rowIndex, propertyName, validationResult);
    final hasWarnings = _hasRowWarnings(rowIndex, propertyName, validationResult);

    Color statusColor;
    if (hasErrors) {
      statusColor = Colors.red;
    } else if (hasWarnings) {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.green;
    }

    return Center(child: Icon(Icons.circle, size: 12, color: statusColor));
  }

  /// Check if a specific row has validation errors
  static bool _hasRowErrors(
    int rowIndex,
    String propertyName,
    TFMValidationResult validationResult,
  ) {
    final rowPath = '/$propertyName/$rowIndex';

    return validationResult.ajvErrors.any((error) {
      // Match exact row path or any field within the row
      return error.instancePath == rowPath ||
          (error.instancePath?.startsWith('$rowPath/') ?? false);
    });
  }

  /// Check if a specific row has validation warnings
  static bool _hasRowWarnings(
    int rowIndex,
    String propertyName,
    TFMValidationResult validationResult,
  ) {
    final rowPath = '/$propertyName/$rowIndex';

    return validationResult.tfmWarnings.any((warning) {
      // Match exact row path or any field within the row
      return warning.instancePath == rowPath ||
          (warning.instancePath?.startsWith('$rowPath/') ?? false);
    });
  }

  /// Get the status color for a row (useful for other UI elements)
  static Color getStatusColor({
    required int rowIndex,
    required String propertyName,
    TFMValidationResult? validationResult,
  }) {
    if (validationResult == null) {
      return Colors.grey;
    }

    final hasErrors = _hasRowErrors(rowIndex, propertyName, validationResult);
    final hasWarnings = _hasRowWarnings(rowIndex, propertyName, validationResult);

    if (hasErrors) {
      return Colors.red;
    } else if (hasWarnings) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }
}
