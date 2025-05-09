import 'package:flutter/material.dart';

class OrderSelection extends StatefulWidget {
  // Use specific types
  final List<Map<String, dynamic>> selectionList;

  const OrderSelection({super.key, required this.selectionList});

  @override
  State<OrderSelection> createState() => _OrderSelectionState();
}

class _OrderSelectionState extends State<OrderSelection> {
  List<bool> isSelected = [];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    // Initialize isSelected with the same length as selectionList
    isSelected = List.generate(widget.selectionList.length, (index) => false);
  }

  void _select(int index) {
    // Toggle the selected state single selection only
    for (int i = 0; i < isSelected.length; i++) {
      isSelected[i] = i == index;
    }
    setState(() {
      // Update the state to reflect the new selection
    });
  }

  @override
  Widget build(BuildContext context) {
    // Ensure the lengths match before building ToggleButtons
    if (widget.selectionList.length != isSelected.length) {
      // Return an empty container or an error widget if lengths don't match
      // This prevents the assertion error in ToggleButtons
      return Container(child: Text('Error: Selection list and isSelected list lengths differ.'));
      // Or handle this more gracefully depending on your app's logic
    }

    return ToggleButtons(
      // The map operation now correctly infers List<Widget> due to better typing
      isSelected: isSelected, // Use the passed-in list
      onPressed: _select, // Use the passed-in callback
      // Add some styling for better appearance
      constraints: const BoxConstraints(minHeight: 32.0), // Ensure minimum height
      borderRadius: BorderRadius.circular(8.0),
      // The map operation now correctly infers List<Widget> due to better typing
      children:
          widget.selectionList.map<Widget>((e) {
            // Ensure required keys exist and handle potential nulls gracefully
            final IconData icon = e['icon'] as IconData? ?? Icons.error; // Default icon if null
            final String label = e['label'] as String? ?? 'N/A'; // Default label if null
            return Padding(
              // Add padding for better spacing
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18), // Slightly smaller icon
                  const SizedBox(width: 4),
                  Text(label, style: const TextStyle(fontSize: 12)),
                ],
              ),
            );
          }).toList(),
    );
  }
}
