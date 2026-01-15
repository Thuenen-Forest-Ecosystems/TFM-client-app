import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/models/layout_config.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';

/// Widget for rendering nested tabs from layout configuration
class NestedTabs extends StatefulWidget {
  final TabsLayout tabsLayout;
  final Map<String, dynamic> schemaProperties;
  final Widget Function(LayoutItem, Map<String, dynamic>) buildWidgetFromLayout;

  const NestedTabs({
    super.key,
    required this.tabsLayout,
    required this.schemaProperties,
    required this.buildWidgetFromLayout,
  });

  @override
  State<NestedTabs> createState() => _NestedTabsState();
}

class _NestedTabsState extends State<NestedTabs> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.tabsLayout.items.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if tab content should be scrollable (defaults to true)
    final scrollableTabView =
        widget.tabsLayout.typeProperties?['scrollableTabView'] as bool? ?? true;

    return Card.outlined(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: widget.tabsLayout.items.map((item) {
              return Tab(text: item.label ?? item.id);
            }).toList(),
          ),
          // Use AnimatedSize to grow/shrink based on content
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, child) {
                // Build only the current tab's content
                final currentItem = widget.tabsLayout.items[_tabController.index];
                final content = widget.buildWidgetFromLayout(currentItem, widget.schemaProperties);
                // Only wrap in ScrollView if scrollableTabView is true
                return scrollableTabView ? SingleChildScrollView(child: content) : content;
              },
            ),
          ),
        ],
      ),
    );
  }
}
