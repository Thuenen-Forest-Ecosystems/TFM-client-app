import 'package:flutter/material.dart';

class ClusterFilter {
  final String? clusterNameFilter;
  final List<String> plotNameFilters;

  const ClusterFilter({this.clusterNameFilter, this.plotNameFilters = const []});

  bool get isActive => (clusterNameFilter != null && clusterNameFilter!.isNotEmpty) || plotNameFilters.isNotEmpty;

  ClusterFilter copyWith({String? clusterNameFilter, List<String>? plotNameFilters}) {
    return ClusterFilter(clusterNameFilter: clusterNameFilter ?? this.clusterNameFilter, plotNameFilters: plotNameFilters ?? this.plotNameFilters);
  }
}

class FilterClusterBy extends StatefulWidget {
  final ClusterFilter initialFilter;
  final Function(ClusterFilter)? onFilterChanged;

  const FilterClusterBy({super.key, this.initialFilter = const ClusterFilter(), this.onFilterChanged});

  @override
  State<FilterClusterBy> createState() => _FilterClusterByState();
}

class _FilterClusterByState extends State<FilterClusterBy> {
  late ClusterFilter _currentFilter;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialFilter;
  }

  void _showFilterDialog() {
    final TextEditingController clusterNameController = TextEditingController(text: _currentFilter.clusterNameFilter ?? '');
    final Map<String, bool> plotNameSelections = {
      '1': _currentFilter.plotNameFilters.contains('1'),
      '2': _currentFilter.plotNameFilters.contains('2'),
      '3': _currentFilter.plotNameFilters.contains('3'),
      '4': _currentFilter.plotNameFilters.contains('4'),
    };

    // Use rootNavigator to show bottom sheet at device bottom, not constrained by parent DraggableScrollableSheet
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),

                  // Title
                  const Text('Filter Records', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // Cluster Name Filter
                  const Text('Cluster Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(controller: clusterNameController, decoration: const InputDecoration(hintText: 'Enter cluster name...', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8))),
                  const SizedBox(height: 20),

                  // Plot Name Filter
                  const Text('Plot Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children:
                        ['1', '2', '3', '4'].map((plotName) {
                          return FilterChip(
                            label: Text('Plot $plotName'),
                            selected: plotNameSelections[plotName] ?? false,
                            onSelected: (bool selected) {
                              setSheetState(() {
                                plotNameSelections[plotName] = selected;
                              });
                            },
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            // Clear all filters
                            setState(() {
                              _currentFilter = const ClusterFilter();
                            });
                            widget.onFilterChanged?.call(_currentFilter);
                            Navigator.of(context).pop();
                          },
                          child: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            // Apply filters
                            final selectedPlotNames = plotNameSelections.entries.where((entry) => entry.value).map((entry) => entry.key).toList();

                            setState(() {
                              _currentFilter = ClusterFilter(clusterNameFilter: clusterNameController.text.isEmpty ? null : clusterNameController.text, plotNameFilters: selectedPlotNames);
                            });

                            widget.onFilterChanged?.call(_currentFilter);
                            Navigator.of(context).pop();
                          },
                          child: const Text('Apply Filter'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(icon: const Icon(Icons.filter_list, size: 20), onPressed: _showFilterDialog, tooltip: 'Filter records'),
        // Badge indicator
        if (_currentFilter.isActive)
          Positioned(right: 8, top: 8, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), constraints: const BoxConstraints(minWidth: 8, minHeight: 8))),
      ],
    );
  }
}
