import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:beamer/beamer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terrestrial_forest_monitor/providers/auth.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:package_info_plus/package_info_plus.dart';

class Profile extends StatelessWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = Supabase.instance.client.auth.currentUser;
    final session = Supabase.instance.client.auth.currentSession;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Avatar
            //Center(child: CircleAvatar(radius: 50, backgroundColor: Theme.of(context).primaryColor, child: Text(user?.email?.substring(0, 1).toUpperCase() ?? 'U', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)))),
            //const SizedBox(height: 24),

            // User Information Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nutzer Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(height: 24),
                    _buildInfoRow('E-Mail', user?.email ?? 'N/A'),
                    _buildInfoRow('Benutzer-ID', user?.id ?? 'N/A'),
                    _buildInfoRow('Erstellt am', _formatDate(user?.createdAt == null ? null : DateTime.parse(user!.createdAt!))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Session Information Card
            if (session != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Session Informationen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Divider(height: 24),
                      _buildInfoRow('Access Token Typ', session.tokenType ?? 'N/A'),
                      _buildInfoRow('Läuft ab am', _formatDate(DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000))),
                      _buildInfoRow('Refresh Token', session.refreshToken != null && session.refreshToken!.length > 20 ? '${session.refreshToken!.substring(0, 20)}...' : session.refreshToken ?? 'N/A'),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 32),

            // Logout Button
            TextButton.icon(
              onPressed:
                  authProvider.loggingIn
                      ? null
                      : () async {
                        // Disconnect and clear PowerSync database
                        await db.disconnectAndClear();
                        // Logout from Supabase
                        await authProvider.logout();
                        if (context.mounted) {
                          context.beamToNamed('/login');
                        }
                      },
              icon: authProvider.loggingIn ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.logout),
              label: Text(authProvider.loggingIn ? 'Abmelden...' : 'Abmelden'),
              style: TextButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 16)),
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
                  return Padding(padding: const EdgeInsets.only(top: 16), child: Center(child: Text('App Version: ${packageInfo.version} (${packageInfo.buildNumber})', style: const TextStyle(fontSize: 12, color: Colors.grey))));
                } else {
                  return const SizedBox.shrink();
                }
              },
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
        children: [SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey))), Expanded(child: Text(value, style: const TextStyle(fontSize: 14)))],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
