import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:beamer/beamer.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrestrial_forest_monitor/l10n/app_localizations.dart';
import 'package:terrestrial_forest_monitor/providers/auth.dart';
import 'package:terrestrial_forest_monitor/providers/language.dart';
import 'package:terrestrial_forest_monitor/providers/theme-mode.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/services/grid_density_service.dart';
import 'package:terrestrial_forest_monitor/widgets/form-elements/floating_num_keyboard.dart';
import 'package:terrestrial_forest_monitor/widgets/map/map-admin.dart';
import 'package:terrestrial_forest_monitor/widgets/settings/gnss-test-btn.dart';
import 'package:terrestrial_forest_monitor/widgets/settings/keyboard-settings.dart';
import 'package:terrestrial_forest_monitor/widgets/settings/density-settings.dart';
import 'package:terrestrial_forest_monitor/widgets/settings/language-settings.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.profileResetTitle),
        content: Text(l10n.profileResetContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.profileResetCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.profileResetConfirm),
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
      'app_language',
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
    context.read<Language>().setLocale(const Locale('system'));
    context.read<ThemeModeProvider>().setTheme(ThemeMode.dark);
    setState(() => _resetKey++);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.profileResetSnackbar)));
  }

  Future<void> _confirmAndLogout(AuthProvider authProvider) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 36),
        title: Text(l10n.profileLogoutTitle),
        content: Text(l10n.profileLogoutContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.profileLogoutCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.profileLogoutConfirm),
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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
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
                l10n.profileMapManagement,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Card(child: MapAdmin()),

            const SizedBox(height: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Text(
                l10n.profileLayoutSettings,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Card(child: ThemeSettings(key: ValueKey(_resetKey))),
            const SizedBox(height: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Text(
                l10n.profileLanguageSettings,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Card(child: LanguageSettings(key: ValueKey(_resetKey))),
            const SizedBox(height: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Text(
                l10n.profileKeyboardSettings,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Card(child: KeyboardSettings(key: ValueKey(_resetKey))),
            const SizedBox(height: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Text(
                l10n.profileCompactMode,
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
              child: Text(
                l10n.profileNetwork,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.vpn_lock),
                title: Text(l10n.profileProxySettings),
                subtitle: Text(l10n.profileProxySubtitle),
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
              label: Text(l10n.profileResetSettings),
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
                    ? l10n.profileLoggingIn
                    : !_isOnline
                    ? l10n.profileLogoutOffline
                    : l10n.profileLogout,
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
                  child: Text(l10n.profileImprint, style: const TextStyle(fontSize: 12)),
                ),
                const Text('|', style: TextStyle(color: Colors.grey)),
                TextButton(
                  onPressed: () {
                    launchUrl(Uri.parse('https://www.thuenen.de/de/datenschutzerklaerung'));
                  },
                  child: Text(l10n.profilePrivacy, style: const TextStyle(fontSize: 12)),
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
                        l10n.profileAppVersion(packageInfo.version, packageInfo.buildNumber),
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
              child: Text(l10n.profileShowRecords),
            ),
            ElevatedButton(
              onPressed: () {
                context.beamToNamed('/synced_tables');
              },
              child: Text(l10n.profileShowSyncedTables),
            ),
            /*ElevatedButton(
              onPressed: () {
                db.getAll('SELECT * FROM lookup_tree_species').then((value) {
                  for (var row in value) {
                  }
                });
              },
              child: const Text('Tree Species'),
            ),*/
            ElevatedButton(
              onPressed: () {
                context.beamToNamed('/logs');
              },
              child: Text(l10n.profileShowLogs),
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
