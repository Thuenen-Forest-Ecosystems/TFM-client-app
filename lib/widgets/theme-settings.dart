import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/providers/theme-mode.dart';

class ThemeSettings extends StatefulWidget {
  const ThemeSettings({super.key});

  @override
  State<ThemeSettings> createState() => _ThemeSettingsState();
}

class _ThemeSettingsState extends State<ThemeSettings> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeModeProvider>(context);
    final currentMode = themeProvider.mode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ThemeOption(
          title: 'Hell',
          subtitle: 'Helles Farbschema verwenden',
          isSelected: currentMode == ThemeMode.light,
          onTap: () => themeProvider.setTheme(ThemeMode.light),
        ),
        _ThemeOption(
          title: 'Dunkel',
          subtitle: 'Dunkles Farbschema verwenden',
          isSelected: currentMode == ThemeMode.dark,
          onTap: () => themeProvider.setTheme(ThemeMode.dark),
        ),
        _ThemeOption(
          title: 'System',
          subtitle: 'Systemeinstellung folgen',
          isSelected: currentMode == ThemeMode.system,
          onTap: () => themeProvider.setTheme(ThemeMode.system),
        ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing:
          isSelected
              ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
              : null,
      onTap: onTap,
    );
  }
}
