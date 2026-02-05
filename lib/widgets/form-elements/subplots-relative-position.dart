import 'package:flutter/material.dart';

class SubplotsRelativePosition extends StatelessWidget {
  final Map<String, dynamic>? jsonSchema;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? previous_properties;
  final String? propertyName;
  final List<Widget> children;

  const SubplotsRelativePosition({
    super.key,
    this.jsonSchema,
    this.data,
    this.previous_properties,
    this.propertyName,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Subplots Relative Position',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text(data!['subplots_relative_position'].toString()),
          Text(previous_properties!['subplots_relative_position'].toString()),

          // Show Items form
          ...children,
        ],
      ),
    );
  }
}
