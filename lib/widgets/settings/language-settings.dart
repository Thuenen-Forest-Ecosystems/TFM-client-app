import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/l10n/app_localizations.dart';
import 'package:terrestrial_forest_monitor/providers/language.dart';

class LanguageSettings extends StatelessWidget {
  const LanguageSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageProvider = context.watch<Language>();
    final selected = languageProvider.selectedCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _LangOption(
          title: l10n.langDe,
          subtitle: l10n.langDeSubtitle,
          flag: '🇩🇪',
          isSelected: selected == 'de',
          onTap: () => languageProvider.setLocale(const Locale('de')),
        ),
        _LangOption(
          title: l10n.langEn,
          subtitle: l10n.langEnSubtitle,
          flag: '🇬🇧',
          isSelected: selected == 'en',
          onTap: () => languageProvider.setLocale(const Locale('en')),
        ),
        _LangOption(
          title: l10n.langSystem,
          subtitle: l10n.langSystemSubtitle,
          flag: '🌐',
          isSelected: selected == 'system',
          onTap: () => languageProvider.setLocale(const Locale('system')),
        ),
      ],
    );
  }
}

class _LangOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final String flag;
  final bool isSelected;
  final VoidCallback onTap;

  const _LangOption({
    required this.title,
    required this.subtitle,
    required this.flag,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      //leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}
