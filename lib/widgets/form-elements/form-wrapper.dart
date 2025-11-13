import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/array-element-syncfusion.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/navigation-element.dart';

class FormWrapper extends StatefulWidget {
  final Map<String, dynamic>? jsonSchema;
  final Map<String, dynamic>? formData;
  final Map<String, dynamic>? previousFormData;

  final Function(Map<String, dynamic>)? onFormDataChanged;

  const FormWrapper({super.key, this.jsonSchema, this.formData, this.previousFormData, this.onFormDataChanged});
  @override
  State<FormWrapper> createState() => _FormWrapperState();
}

class _FormWrapperState extends State<FormWrapper> {
  late Map<String, dynamic> _localFormData;
  late Map<String, dynamic> _previousProperties;

  @override
  void initState() {
    super.initState();
    _localFormData = Map<String, dynamic>.from(widget.formData ?? {});
    _previousProperties = Map<String, dynamic>.from(widget.previousFormData ?? {});
  }

  @override
  void didUpdateWidget(FormWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update local form data if parent data changes
    if (widget.formData != oldWidget.formData) {
      _localFormData = Map<String, dynamic>.from(widget.formData ?? {});
      _previousProperties = Map<String, dynamic>.from(widget.previousFormData ?? {});
    }
  }

  void _updateField(String key, dynamic value) {
    setState(() {
      _localFormData[key] = value;
    });

    // Notify parent of changes
    widget.onFormDataChanged?.call(Map<String, dynamic>.from(_localFormData));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.jsonSchema == null) {
      return const Center(child: Text('No schema available'));
    }

    // Extract tabs from schema properties
    final schemaProperties = widget.jsonSchema!;
    final tabs = <String>[];

    // Add tabs based on schema structure
    tabs.add('Navigation');
    if (schemaProperties.containsKey('tree')) {
      tabs.add('Tree');
    }

    if (tabs.isEmpty) {
      return const Center(child: Text('No form tabs available'));
    }

    // Debug: Print form data
    debugPrint('FormWrapper - formData: $_localFormData');
    debugPrint('FormWrapper - tree data: ${_localFormData['tree']}');

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          TabBar(tabs: tabs.map((tab) => Tab(text: tab)).toList()),
          Expanded(
            child: TabBarView(
              children:
                  tabs.map((tab) {
                    if (tab == 'Navigation') {
                      return NavigationElement(
                        jsonSchema: schemaProperties,
                        data: _localFormData,
                        previous_properties: _previousProperties,
                        onDataChanged: (updatedData) {
                          _updateField('navigation', updatedData);
                        },
                      );
                    } else if (tab == 'Tree') {
                      return ArrayElementSyncfusion(
                        jsonSchema: schemaProperties['tree'],
                        data: _localFormData['tree'] ?? [],
                        onDataChanged: (updatedData) {
                          _updateField('tree', updatedData);
                        },
                      );
                    }
                    return Center(child: Text('$tab Form'));
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Navigation Form', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // TODO: Build form fields from navigation schema
          TextField(decoration: const InputDecoration(labelText: 'Test Field'), onChanged: (value) => _updateField('test', value)),
        ],
      ),
    );
  }
}
