import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/providers/playground_mode_provider.dart';

/// A toggle button that activates/deactivates playground mode.
/// In playground mode, records cannot be saved.
class PlaygroundModeButton extends StatelessWidget {
  const PlaygroundModeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlaygroundModeProvider>();
    final isActive = provider.isPlaygroundMode;

    if (isActive) {
      return InkWell(
        onTap: () => provider.toggle(),
        child: Chip(
          avatar: const Icon(Icons.science, size: 18, color: Colors.white),
          label: const Text('Playground', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.orange,
          shape: const StadiumBorder(),
          deleteIcon: const Icon(Icons.close, size: 18, color: Colors.white),
          onDeleted: () => provider.toggle(),
          side: BorderSide.none,
        ),
      );
    }

    return Tooltip(
      message: 'Playground-Modus aktivieren (kein Speichern möglich)',
      child: IconButton(icon: const Icon(Icons.science), onPressed: () => provider.toggle()),
    );
  }
}
