import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:terrestrial_forest_monitor/providers/language.dart';
import 'package:terrestrial_forest_monitor/providers/theme-mode.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/widgets/gnss-settings.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  late bool _lights;
  late String _selectedLanguage;

  @override
  Widget build(BuildContext context) {
    String languageCountry = context.watch<Language>().locale.toString();
    _selectedLanguage = languageCountry.split('_')[0];

    ThemeMode themeMode = context.watch<ThemeModeProvider>().mode;
    _lights = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        automaticallyImplyLeading: true,
        title: Text(AppLocalizations.of(context)!.settings),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 800,
            minWidth: 300,
          ),
          child: ListView(
            children: <Widget>[
              Container(
                margin: EdgeInsets.only(top: 20.0, left: 30.0, right: 30.0),
                child: Text(
                  'GNSS',
                  style: TextStyle(fontSize: 15),
                ),
              ),
              Card(
                margin: EdgeInsets.all(10.0),
                child: GnssSettings(),
              ),
              Container(
                margin: EdgeInsets.only(top: 20.0, left: 30.0, right: 30.0),
                child: Text(
                  'Layout',
                  style: TextStyle(fontSize: 15),
                ),
              ),
              Card(
                margin: EdgeInsets.all(10.0),
                child: Column(
                  children: <Widget>[
                    ListTile(
                      title: Text(AppLocalizations.of(context)!.language),
                      leading: const Icon(Icons.language),
                      trailing: SegmentedButton(
                        selected: {_selectedLanguage},
                        onSelectionChanged: (newSelection) => {
                          context.read<Language>().setLocale(Locale(newSelection.first)),
                        },
                        segments: [
                          ButtonSegment(
                            value: 'en',
                            label: Text('English'),
                          ),
                          ButtonSegment(
                            value: 'de',
                            label: Text('Deutsch'),
                          ),
                        ],
                      ),
                    ),
                    Divider(),
                    SwitchListTile(
                      title: Text(AppLocalizations.of(context)!.energySaving),
                      subtitle: Text(AppLocalizations.of(context)!.energySavingDescription),
                      value: _lights,
                      onChanged: (bool value) {
                        setState(() {
                          ThemeMode newThemeMode = value ? ThemeMode.dark : ThemeMode.light;
                          context.read<ThemeModeProvider>().setTheme(newThemeMode);
                        });
                      },
                      secondary: Icon(
                        (_lights ? Icons.dark_mode : Icons.light_mode),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: EdgeInsets.only(top: 20.0, left: 30.0, right: 30.0),
                child: Text(
                  'Development Options',
                  style: TextStyle(fontSize: 15),
                ),
              ),
              Card(
                margin: EdgeInsets.all(10.0),
                child: Column(
                  children: [
                    ListTile(
                      title: Text('Host'),
                      leading: const Icon(Icons.bug_report),
                      trailing: Container(
                        width: 200,
                        child: DropdownButtonFormField(
                          items: [
                            DropdownMenuItem(
                              value: 'production',
                              child: const Text('Production'),
                            ),
                            DropdownMenuItem(
                              value: 'development',
                              child: const Text('Development'),
                            ),
                          ],
                          onChanged: (value) {
                            print('Clicked $value');
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
