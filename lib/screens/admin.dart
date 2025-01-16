import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/widgets/admin/storage-list.dart';
import 'package:terrestrial_forest_monitor/widgets/admin/database-list.dart';
import 'package:terrestrial_forest_monitor/config.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<bool> _selectedServer = <bool>[];
  List<Widget> _servers = <Widget>[]; // Add

  _updateServerSelection() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? serverName = await prefs.getString('selectedServer');

    _selectedServer.clear();
    _servers.clear();
    // Add Servers
    for (int i = 0; i < AppConfig.servers.length; i++) {
      if (AppConfig.servers[i]['supabaseUrl'] == serverName) {
        _selectedServer.add(true);
      } else {
        _selectedServer.add(false);
      }

      _servers.add(
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(AppConfig.servers[i]['name']!),
        ),
      );
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

  _getServerName() {
    for (int i = 0; i < _selectedServer.length; i++) {
      if (_selectedServer[i]) {
        var config = AppConfig.servers.firstWhere((element) => element['supabaseUrl'] == AppConfig.servers[i]['supabaseUrl'], orElse: () => AppConfig.servers[0]);
        return config['supabaseUrl'] ?? '';
      }
    }
    return '';
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _updateServerSelection();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: false,
          automaticallyImplyLeading: true,
          title: Text('Admin'),
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
                    'Server',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
                Card(
                  margin: EdgeInsets.all(10.0),
                  child: ListTile(
                    title: Text('Selected Server'),
                    subtitle: Text(_getServerName()),
                    trailing: ToggleButtons(
                      children: _servers,
                      onPressed: _updateServer,
                      isSelected: _selectedServer,
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      constraints: const BoxConstraints(
                        minHeight: 40.0,
                        minWidth: 80.0,
                      ),
                    ),
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(top: 20.0, left: 30.0, right: 30.0),
                  child: Text(
                    'Local Files',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
                Card(
                  margin: EdgeInsets.all(10.0),
                  child: StorageList(),
                ),
                Container(
                  margin: EdgeInsets.only(top: 20.0, left: 30.0, right: 30.0),
                  child: Text(
                    'Local Database',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
                Card(
                  margin: EdgeInsets.all(10.0),
                  child: DatabaseList(),
                )
              ],
            ),
          ),
        ));
  }
}
