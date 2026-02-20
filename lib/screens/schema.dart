import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:terrestrial_forest_monitor/screens/inventory/schema-selection.dart';
import 'package:terrestrial_forest_monitor/widgets/sync-status-button.dart';
import 'package:beamer/beamer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terrestrial_forest_monitor/widgets/version-control.dart';

class Schema extends StatefulWidget {
  const Schema({super.key});

  // const UserInfoTile(),

  @override
  State<Schema> createState() => _SchemaState();
}

class _SchemaState extends State<Schema> {
  @override
  Widget build(BuildContext context) {
    // add Logo THUENEN_SCREEN_Black.svg
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: SvgPicture.asset('assets/logo/THUENEN_SCREEN_Black.svg', height: 50),
        actions: [
          const SyncStatusButton(),
          //SizedBox(width: 5),
          IconButton(
            onPressed: () => Beamer.of(context).beamToNamed('/profile'),
            icon: const Icon(Icons.settings),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            onSelected: (value) async {
              if (value == 'logout') {
                await Supabase.instance.client.auth.signOut();
              }
            },
            itemBuilder: (context) {
              final user = Supabase.instance.client.auth.currentUser;
              final email = user?.email ?? '-';

              return [
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    email,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(children: [Text('Abmelden')]),
                ),
              ];
            },
          ),
        ],
      ),
      body: const SchemaSelection(),
      bottomNavigationBar: const SafeArea(child: VersionControl()),
    );
  }
}
