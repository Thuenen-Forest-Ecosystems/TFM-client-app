import 'package:flutter/material.dart';

class FormFieldWrapper extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;

  const FormFieldWrapper({super.key, required this.children, this.spacing = 16.0, this.runSpacing = 16.0});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: spacing, runSpacing: runSpacing, alignment: WrapAlignment.start, children: children.map((child) => ConstrainedBox(constraints: BoxConstraints(maxWidth: 300), child: child)).toList());
  }
}
