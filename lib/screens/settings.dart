import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrestrial_forest_monitor/config.dart';
import 'package:terrestrial_forest_monitor/l10n/app_localizations.dart';
import 'package:terrestrial_forest_monitor/providers/language.dart';
import 'package:terrestrial_forest_monitor/providers/theme-mode.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/services/utils.dart';
//import 'package:terrestrial_forest_monitor/widgets/bluetooth/android-bluetooth.dart';
//import 'package:terrestrial_forest_monitor/widgets/gnss-settings.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  late bool _lights;
  late String _selectedLanguage = 'en';

  List<bool> _selectedServer = <bool>[];
  List<Widget> _servers = <Widget>[]; // Add

  void _setLanguage(String language) async {
    setDeviceSettings('language', language);
  }

  void _watchLanguage() {
    db.watch('SELECT * FROM device_settings WHERE key = \'language\'').listen((event) {
      print('newLanguage: $event');
    });
    return;

    try {
      db.watch('SELECT * FROM user_settings WHERE key = \'language\' AND user_id=\'${getUserId()}\'').listen((event) {
        if (event.isNotEmpty) {
          String languageCountry = event.first['value'];
          //_selectedLanguage = languageCountry.split('_')[0];
          //print('event user_settings: $_selectedLanguage');
          setState(() {
            _selectedLanguage = languageCountry.split('_')[0];
          });
        }
      });
    } catch (e) {
      print('Error watching language: $e');
    }
  }

  @override
  void initState() {
    super.initState();

    _updateServerSelection();
    // _watchLanguage();
  }

  _updateServerSelection() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? serverName = prefs.getString('selectedServer');

    _selectedServer.clear();
    _servers.clear();
    // Add Servers
    for (int i = 0; i < AppConfig.servers.length; i++) {
      if (AppConfig.servers[i]['supabaseUrl'] == serverName) {
        _selectedServer.add(true);
      } else {
        _selectedServer.add(false);
      }

      _servers.add(Padding(padding: const EdgeInsets.all(8.0), child: Text(AppConfig.servers[i]['name']!)));
    }
    setState(() {});
    changeServer();
  }

  _updateServer(index) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // The button that is tapped is set to true, and the others to false.
    for (int i = 0; i < AppConfig.servers.length; i++) {
      if (i == index) {
        await prefs.setString('selectedServer', AppConfig.servers[i]['supabaseUrl']!);
      }
    }
    _updateServerSelection();
  }

  @override
  Widget build(BuildContext context) {
    //String languageCountry = context.watch<Language>().locale.toString();
    //_selectedLanguage = languageCountry.split('_')[0];

    ThemeMode themeMode = context.watch<ThemeModeProvider>().mode;
    _lights = themeMode == ThemeMode.dark;

    print(kDebugMode);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: Text(AppLocalizations.of(context)!.settings),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.close),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 800, minWidth: 300),
          child: ListView(
            children: <Widget>[
              //if (!kIsWeb) Container(margin: EdgeInsets.only(top: 20.0, left: 30.0, right: 30.0), child: Text('GNSS', style: TextStyle(fontSize: 15))),
              //if (!kIsWeb) Card(margin: EdgeInsets.all(10.0), child: BluetoothSetup()),
              Container(margin: EdgeInsets.only(top: 20.0, left: 30.0, right: 30.0), child: Text('Layout', style: TextStyle(fontSize: 15))),
              Card(
                margin: EdgeInsets.all(10.0),
                child: Column(
                  children: <Widget>[
                    Consumer<Language>(
                      builder:
                          (context, value, child) => ListTile(
                            title: Text(AppLocalizations.of(context)!.language),
                            leading: const Icon(Icons.language),
                            trailing: SegmentedButton(
                              selected: {value.locale.languageCode},
                              onSelectionChanged: (newSelection) async {
                                //await setSettings('language', newSelection.first);
                                _setLanguage(newSelection.first);
                                //await setDeviceSettings('language', newSelection.first);

                                //context.read<Language>().setLocale(Locale(newSelection.first));
                              },
                              segments: [ButtonSegment(value: 'en', label: Text('English')), ButtonSegment(value: 'de', label: Text('Deutsch'))],
                            ),
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
                      secondary: Icon((_lights ? Icons.dark_mode : Icons.light_mode)),
                    ),
                  ],
                ),
              ),
              if (kDebugMode)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(margin: EdgeInsets.only(top: 20.0, left: 30.0, right: 30.0), child: Text('Development Options', style: TextStyle(fontSize: 15))),
                    Card(
                      margin: EdgeInsets.all(10.0),
                      child: Column(
                        children: [
                          ListTile(
                            title: Text('Host'),
                            leading: const Icon(Icons.bug_report),
                            trailing: ToggleButtons(
                              onPressed: _updateServer,
                              isSelected: _selectedServer,
                              borderRadius: const BorderRadius.all(Radius.circular(8)),
                              constraints: const BoxConstraints(minHeight: 40.0, minWidth: 80.0),
                              children: _servers,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
