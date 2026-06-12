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

  // Indices of tabs that have been visited. Visited tabs stay in the tree
  // (offstage when inactive) so their state — e.g. TrinaGrid sorting and
  // scroll position — survives tab switches. Unvisited tabs are not built.
  final Set<int> _builtTabIndices = {};

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
                final currentIndex = _tabController.index;
                _builtTabIndices.add(currentIndex);

                // Keep visited tabs in the tree (offstage when inactive) so
                // their state survives tab switches; lazily skip unvisited ones.
                final children = List<Widget>.generate(widget.tabsLayout.items.length, (i) {
                  if (!_builtTabIndices.contains(i)) return const SizedBox.shrink();

                  final item = widget.tabsLayout.items[i];
                  final content = widget.buildWidgetFromLayout(item, widget.schemaProperties);
                  // Only wrap in ScrollView if scrollableTabView is true
                  return Visibility(
                    key: ValueKey(item.id),
                    visible: i == currentIndex,
                    maintainState: true,
                    child: scrollableTabView ? SingleChildScrollView(child: content) : content,
                  );
                });

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
