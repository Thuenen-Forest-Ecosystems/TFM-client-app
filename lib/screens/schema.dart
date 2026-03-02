import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:terrestrial_forest_monitor/screens/inventory/schema-selection.dart';
import 'package:terrestrial_forest_monitor/widgets/sync-status-button.dart';
import 'package:beamer/beamer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terrestrial_forest_monitor/widgets/version-control.dart';
import 'package:terrestrial_forest_monitor/widgets/playground-mode-button.dart';

class Schema extends StatefulWidget {
  const Schema({super.key});

  // const UserInfoTile(),

  @override
  State<Schema> createState() => _SchemaState();
}

class _SchemaState extends State<Schema> {
  @override
  void initState() {
    super.initState();
    // On Windows tablets, ensure the soft keyboard is dismissed when this
    // screen mounts (safety net after login navigation).
    if (!kIsWeb && Platform.isWindows) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusManager.instance.primaryFocus?.unfocus();
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // add Logo THUENEN_SCREEN_Black.svg
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: SvgPicture.asset('assets/logo/THUENEN_SCREEN_Black.svg', height: 50),
        actions: [
          const SyncStatusButton(),
          const PlaygroundModeButton(),
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
