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
          debugPrint('⚠️ rawError is not a Map: $rawErrorValue (${rawErrorValue.runtimeType})');
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
      debugPrint('❌ ERROR in AcknowledgedError.fromJson: $e');
      debugPrint('❌ Stack: $stackTrace');
      debugPrint('❌ JSON: $json');
      rethrow; // Re-throw so decodeList catches it
    }
  }

  static String encodeList(List<AcknowledgedError> errors) {
    return jsonEncode(errors.map((e) => e.toJson()).toList());
  }

  static List<AcknowledgedError> decodeList(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      debugPrint('❌ DEBUG: Input jsonString type: ${jsonString.runtimeType}');
      debugPrint('❌ DEBUG: Input jsonString length: ${jsonString.length}');
      debugPrint(
        '❌ DEBUG: First 100 chars: ${jsonString.substring(0, jsonString.length > 100 ? 100 : jsonString.length)}',
      );

      dynamic decoded = jsonDecode(jsonString);

      debugPrint('❌ DEBUG: After 1st jsonDecode, type: ${decoded.runtimeType}');

      // Handle double-encoded JSON: if decode result is still a String, decode again
      if (decoded is String) {
        debugPrint('❌ DEBUG: Double-encoded JSON detected! Decoding again...');
        debugPrint(
          '❌ DEBUG: String value: ${decoded.substring(0, decoded.length > 100 ? 100 : decoded.length)}',
        );
        decoded = jsonDecode(decoded);
        debugPrint('❌ DEBUG: After 2nd jsonDecode, type: ${decoded.runtimeType}');
      }

      if (decoded is! List) {
        debugPrint('❌ ERROR: Decoded JSON is not a List, got ${decoded.runtimeType}');
        return [];
      }

      final List<AcknowledgedError> errors = [];
      for (var i = 0; i < decoded.length; i++) {
        try {
          final item = decoded[i];
          if (item is! Map) {
            debugPrint('❌ ERROR: Item $i is not a Map, got ${item.runtimeType}');
            continue;
          }

          final Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
          errors.add(AcknowledgedError.fromJson(itemMap));
        } catch (itemError) {
          debugPrint('❌ ERROR decoding item $i: $itemError');
          debugPrint('❌ Item data: ${decoded[i]}');
          // Continue processing other items
        }
      }

      return errors;
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR decoding AcknowledgedError list: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      debugPrint(
        '❌ JSON was: ${jsonString.substring(0, jsonString.length > 200 ? 200 : jsonString.length)}...',
      );
      return [];
    }
  }
}
