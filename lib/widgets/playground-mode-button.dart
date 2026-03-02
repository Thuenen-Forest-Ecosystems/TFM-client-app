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

    return Tooltip(
      message: isActive
          ? 'Playground-Modus aktiv – Speichern deaktiviert. Tippen zum Deaktivieren.'
          : 'Playground-Modus aktivieren (kein Speichern möglich)',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          provider.toggle();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.science),
              if (isActive) ...[const SizedBox(width: 4), const Text('Playground')],
            ],
          ),
        ),
      ),
    );
  }
}
