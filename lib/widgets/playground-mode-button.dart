import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;

    if (isActive) {
      // Narrow devices: drop the label, keep the orange avatar + close.
      if (MediaQuery.sizeOf(context).width < 600) {
        return Tooltip(
          message: l10n.playgroundModeButtonExit,
          child: IconButton(
            icon: const Icon(Icons.science, color: Colors.white),
            style: IconButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => provider.toggle(),
          ),
        );
      }
      return InkWell(
        onTap: () => provider.toggle(),
        child: Chip(
          avatar: const Icon(Icons.science, size: 18, color: Colors.white),
          label: Text(l10n.playgroundModeButtonLabel, style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.orange,
          shape: const StadiumBorder(),
          deleteIcon: const Icon(Icons.close, size: 18, color: Colors.white),
          onDeleted: () => provider.toggle(),
          side: BorderSide.none,
        ),
      );
    }

    return Tooltip(
      message: l10n.playgroundModeButtonActivate,
      child: IconButton(icon: const Icon(Icons.science), onPressed: () => provider.toggle()),
    );
  }
}
