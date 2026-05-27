import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Represents an acknowledged error or warning with an optional user note
class AcknowledgedError {
  final String message;
  final String? instancePath;
  final String? schemaPath;
  final String type; // 'error' or 'warning'
  final String source; // 'ajv' or 'tfm'
  final String? note; // User's acknowledgment note
  final DateTime acknowledgedAt;
  final Map<String, dynamic> rawError;

  AcknowledgedError({
    required this.message,
    this.instancePath,
    this.schemaPath,
    required this.type,
    required this.source,
    this.note,
    DateTime? acknowledgedAt,
    Map<String, dynamic>? rawError,
  }) : acknowledgedAt = acknowledgedAt ?? DateTime.now(),
       rawError = rawError ?? {};

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      if (instancePath != null) 'instancePath': instancePath,
      if (schemaPath != null) 'schemaPath': schemaPath,
      'type': type,
      'source': source,
      if (note != null && note!.isNotEmpty) 'note': note,
      'acknowledgedAt': acknowledgedAt.toIso8601String(),
      'rawError': rawError,
    };
  }

  factory AcknowledgedError.fromJson(Map<String, dynamic> json) {
    try {
      // Safely extract rawError and convert to Map<String, dynamic>
      final rawErrorValue = json['rawError'];
      Map<String, dynamic> rawErrorMap = {};
      if (rawErrorValue != null) {
        if (rawErrorValue is Map) {
          rawErrorMap = Map<String, dynamic>.from(rawErrorValue);
        } else {
        }
      }

      return AcknowledgedError(
        message: json['message'] as String,
        instancePath: json['instancePath'] as String?,
        schemaPath: json['schemaPath'] as String?,
        type: json['type'] as String,
        source: json['source'] as String,
        note: json['note'] as String?,
        acknowledgedAt: DateTime.parse(json['acknowledgedAt'] as String),
        rawError: rawErrorMap,
      );
    } catch (e, stackTrace) {
      rethrow; // Re-throw so decodeList catches it
    }
  }

  static String encodeList(List<AcknowledgedError> errors) {
    return jsonEncode(errors.map((e) => e.toJson()).toList());
  }

  static List<AcknowledgedError> decodeList(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return [];
    try {

      dynamic decoded = jsonDecode(jsonString);


      // Handle double-encoded JSON: if decode result is still a String, decode again
      if (decoded is String) {
        decoded = jsonDecode(decoded);
      }

      if (decoded is! List) {
        return [];
      }

      final List<AcknowledgedError> errors = [];
      for (var i = 0; i < decoded.length; i++) {
        try {
          final item = decoded[i];
          if (item is! Map) {
            continue;
          }

          final Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
          errors.add(AcknowledgedError.fromJson(itemMap));
        } catch (itemError) {
          // Continue processing other items
        }
      }

      return errors;
    } catch (e, stackTrace) {
      return [];
    }
  }
}
