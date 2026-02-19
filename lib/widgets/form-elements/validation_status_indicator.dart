import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/widgets/validation_errors_dialog.dart';

/// Helper class for displaying validation status indicators in grid rows
class ValidationStatusIndicator {
  /// Builds a validation status indicator widget for a specific row
  ///
  /// Returns a colored circle indicator:
  /// - Red: Row has errors
  /// - Orange/Yellow: Row has warnings
  /// - Green: Row is valid (no errors or warnings)
  ///
  /// When clicked, shows a dialog with filtered errors/warnings for that row
  static Widget build({
    required BuildContext context,
    required int rowIndex,
    required String propertyName,
    TFMValidationResult? validationResult,
  }) {
    if (validationResult == null) {
      // No validation result yet - show neutral/gray
      return const Center(child: Icon(Icons.circle_outlined, size: 20, color: Colors.grey));
    }

    // Check if this row has any errors or warnings
    final hasErrors = _hasRowErrors(rowIndex, propertyName, validationResult);
    final hasWarnings = _hasRowWarnings(rowIndex, propertyName, validationResult);

    // Errors take priority over warnings
    final IconData icon;
    final Color color;
    if (hasErrors) {
      icon = Icons.report;
      color = Colors.red;
    } else if (hasWarnings) {
      icon = Icons.warning;
      color = Colors.orange;
    } else {
      icon = Icons.check;
      color = Color.fromARGB(255, 0, 255, 179); // Green color
    }

    if (hasErrors || hasWarnings) {
      return Center(
        child: InkWell(
          onTap: () => _showRowValidationDialog(context, rowIndex, propertyName, validationResult),
          child: Icon(icon, size: 28, color: color),
        ),
      );
    }

    return Center(child: Icon(icon, size: 28, color: color));
  }

  /// Show validation dialog filtered to this specific row
  static void _showRowValidationDialog(
    BuildContext context,
    int rowIndex,
    String propertyName,
    TFMValidationResult validationResult,
  ) {
    // Filter validation result to only include errors/warnings for this row
    final rowPath = '/$propertyName/$rowIndex';

    final filteredAjvErrors = validationResult.ajvErrors.where((error) {
      return error.instancePath == rowPath ||
          (error.instancePath?.startsWith('$rowPath/') ?? false);
    }).toList();

    // Filter tfmErrors (includes both errors and warnings)
    final filteredTfmErrors = validationResult.tfmErrors.where((error) {
      return error.instancePath == rowPath ||
          (error.instancePath?.startsWith('$rowPath/') ?? false);
    }).toList();

    // Create filtered validation result
    final filteredResult = TFMValidationResult(
      ajvValid: filteredAjvErrors.isEmpty,
      ajvErrors: filteredAjvErrors,
      tfmAvailable: validationResult.tfmAvailable,
      tfmErrors: filteredTfmErrors,
    );

    // Show dialog with filtered results
    ValidationErrorsDialog.show(context, filteredResult, showActions: false);
  }

  /// Check if a specific row has validation errors
  static bool _hasRowErrors(
    int rowIndex,
    String propertyName,
    TFMValidationResult validationResult,
  ) {
    final rowPath = '/$propertyName/$rowIndex';

    // Check AJV errors
    final hasAjvErrors = validationResult.ajvErrors.any((error) {
      return error.instancePath == rowPath ||
          (error.instancePath?.startsWith('$rowPath/') ?? false);
    });

    // Check TFM errors (not warnings)
    final hasTfmErrors = validationResult.tfmErrors.any((error) {
      final matchesPath =
          error.instancePath == rowPath || (error.instancePath?.startsWith('$rowPath/') ?? false);
      return matchesPath && error.isError;
    });

    return hasAjvErrors || hasTfmErrors;
  }

  /// Check if a specific row has validation warnings
  static bool _hasRowWarnings(
    int rowIndex,
    String propertyName,
    TFMValidationResult validationResult,
  ) {
    final rowPath = '/$propertyName/$rowIndex';

    // Check tfmErrors for warnings (those with type 'warning')
    return validationResult.tfmErrors.any((error) {
      final matchesPath =
          error.instancePath == rowPath || (error.instancePath?.startsWith('$rowPath/') ?? false);
      return matchesPath && error.isWarning;
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
