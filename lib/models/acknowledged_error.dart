import 'dart:convert';

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
    return AcknowledgedError(
      message: json['message'] as String,
      instancePath: json['instancePath'] as String?,
      schemaPath: json['schemaPath'] as String?,
      type: json['type'] as String,
      source: json['source'] as String,
      note: json['note'] as String?,
      acknowledgedAt: DateTime.parse(json['acknowledgedAt'] as String),
      rawError: json['rawError'] as Map<String, dynamic>? ?? {},
    );
  }

  static String encodeList(List<AcknowledgedError> errors) {
    return jsonEncode(errors.map((e) => e.toJson()).toList());
  }

  static List<AcknowledgedError> decodeList(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      return list.map((e) => AcknowledgedError.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }
}
