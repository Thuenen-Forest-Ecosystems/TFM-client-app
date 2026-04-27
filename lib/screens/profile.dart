import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:beamer/beamer.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrestrial_forest_monitor/providers/auth.dart';
import 'package:terrestrial_forest_monitor/providers/theme-mode.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/services/grid_density_service.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/floating_num_keyboard.dart';
import 'package:terrestrial_forest_monitor/widgets/map/map-admin.dart';
import 'package:terrestrial_forest_monitor/widgets/settings/gnss-test-btn.dart';
import 'package:terrestrial_forest_monitor/widgets/settings/keyboard-settings.dart';
import 'package:terrestrial_forest_monitor/widgets/settings/density-settings.dart';
import 'package:terrestrial_forest_monitor/widgets/theme-settings.dart';
import 'package:terrestrial_forest_monitor/screens/proxy_settings.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:package_info_plus/package_info_plus.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  bool _isOnline = true;
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySub;
  int _resetKey = 0;

  @override
  void initState() {
    super.initState();
    // Seed with current state
    Connectivity().checkConnectivity().then(_updateConnectivity);
    _connectivitySub = Connectivity().onConnectivityChanged.listen(_updateConnectivity);
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    if (!mounted) return;
    setState(() {
      _isOnline = results.any((r) => r != ConnectivityResult.none);
    });
  }

  @override
  void dispose() {
    _connectivitySub.cancel();
    super.dispose();
  }

  Future<void> _clearLocalSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_sweep, size: 36),
        title: const Text('Einstellungen zurücksetzen?'),
        content: const Text(
          'Folgende lokale Einstellungen werden gelöscht:\n\n'
          '• Kompakter Modus\n'
          '• Tastatur-Einstellung\n'
          '• Spaltenbreiten in Tabellen\n'
          '• Filter-Zustände\n'
          '• Zuletzt genutzte Enum-Werte\n'
          '• Karteneinstellungen\n\n'
          'Server-, Organisations- und Proxy-Einstellungen bleiben erhalten.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Zurücksetzen'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();

    // Prefixes covering dynamic per-property keys
    const dynamicPrefixes = ['col_widths_', 'array_filter_', 'enum_chips_view_', 'enum_recent_'];

    // Fixed UI/layout keys (excludes selectedServer, proxy_*, selected_*, is_organization_admin, pinned_records)
    const fixedKeys = {
      'grid_dense_mode',
      'floating_num_keyboard_enabled',
      'map_basemaps',
      'tree_diameter_multiplier',
      'show_tree_labels',
      'tree_label_fields',
      'show_edges',
      'show_crown_circles',
      'show_cluster_polygons',
      'show_probekreise',
    };

    for (final key in allKeys) {
      if (fixedKeys.contains(key) || dynamicPrefixes.any((prefix) => key.startsWith(prefix))) {
        await prefs.remove(key);
      }
    }

    // Reload services so the app reflects the reset values immediately
    await GridDensityService.loadPreference();
    await FloatingNumKeyboard.loadPreference();

    if (!mounted) return;
    context.read<ThemeModeProvider>().setTheme(ThemeMode.dark);
    setState(() => _resetKey++);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Einstellungen wurden zurückgesetzt.')));
  }

  Future<void> _confirmAndLogout(AuthProvider authProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 36),
        title: const Text('Abmelden und Daten löschen?'),
        content: const Text(
          'Alle lokalen Daten werden unwiderruflich gelöscht.\n\n'
          'Nicht synchronisierte Einträge gehen verloren und können nicht wiederhergestellt werden.\n\n'
          'Bitte stellen Sie sicher, dass alle Daten synchronisiert wurden, bevor Sie fortfahren.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Löschen und abmelden'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await db.disconnectAndClear();
    await authProvider.logout();
    if (mounted) context.beamToNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Avatar
            //Center(child: CircleAvatar(radius: 50, backgroundColor: Theme.of(context).primaryColor, child: Text(user?.email?.substring(0, 1).toUpperCase() ?? 'U', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)))),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Text(
                'Kartenverwaltung',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Card(child: MapAdmin()),

            const SizedBox(height: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Text(
                'Layout-Einstellungen',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Card(child: ThemeSettings(key: ValueKey(_resetKey))),
            const SizedBox(height: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Text(
                'Keyboard-Einstellungen',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Card(child: KeyboardSettings(key: ValueKey(_resetKey))),
            const SizedBox(height: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Text(
                'Kompakter Modus',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Card(child: DensitySettings(key: ValueKey(_resetKey))),
            /*const SizedBox(height: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Text(
                'Schemas für Validierung',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Card(child: DownloadSchemasBtn()),*/
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: const Text(
                'Netzwerk',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.vpn_lock),
                title: const Text('Proxy-Einstellungen'),
                subtitle: const Text('Konfiguration für Landesdatennetze'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (context) => const ProxySettingsScreen()));
                },
              ),
            ),

            /*const SizedBox(height: 16),
            // In your profile or settings screen
            ElevatedButton(
              onPressed: () async {
                await BackgroundSyncService.registerOneTimeSync(delay: const Duration(seconds: 5));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Background sync will run in 5 seconds')),
                );
              },
              child: const Text('Test Background Sync'),
            ),

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (context) => const TestTrinaGrid()));
              },
              child: const Text('Test TrinaGrid'),
            ),*/

            // Reset LocalStorage Button
            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: _clearLocalSettings,
              icon: const Icon(Icons.delete_sweep),
              label: const Text('Einstellungen zurücksetzen'),
            ),

            const SizedBox(height: 32),

            // Logout Button
            TextButton.icon(
              onPressed: (authProvider.loggingIn || !_isOnline)
                  ? null
                  : () => _confirmAndLogout(authProvider),
              icon: authProvider.loggingIn
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout),
              label: Text(
                authProvider.loggingIn
                    ? 'Abmelden...'
                    : !_isOnline
                    ? 'Abmelden (offline nicht möglich)'
                    : 'Abmelden und Daten löschen',
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    launchUrl(Uri.parse('https://www.thuenen.de/de/impressum'));
                  },
                  child: const Text('Impressum', style: TextStyle(fontSize: 12)),
                ),
                const Text('|', style: TextStyle(color: Colors.grey)),
                TextButton(
                  onPressed: () {
                    launchUrl(Uri.parse('https://www.thuenen.de/de/datenschutzerklaerung'));
                  },
                  child: const Text('Datenschutzbestimmungen', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),

            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                  final packageInfo = snapshot.data!;
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Center(
                      child: Text(
                        'App Version: ${packageInfo.version} (${packageInfo.buildNumber})',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
            ),

            const SizedBox(height: 16),
            // Button to logger.dart
            ElevatedButton(
              onPressed: () {
                context.beamToNamed('/records-raw');
              },
              child: const Text('Records anzeigen'),
            ),
            ElevatedButton(
              onPressed: () {
                context.beamToNamed('/synced_tables');
              },
              child: const Text('Synced Tables anzeigen'),
            ),
            /*ElevatedButton(
              onPressed: () {
                db.getAll('SELECT * FROM lookup_tree_species').then((value) {
                  print('Tree species lookup table:');
                  for (var row in value) {
                    print(row);
                  }
                });
              },
              child: const Text('Tree Species'),
            ),*/
            ElevatedButton(
              onPressed: () {
                context.beamToNamed('/logs');
              },
              child: const Text('Protokolle anzeigen'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
