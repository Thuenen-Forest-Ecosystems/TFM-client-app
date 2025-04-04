import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/services/utils.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportDialog extends StatefulWidget {
  const SupportDialog({super.key});

  @override
  State<SupportDialog> createState() => _SupportDialogState();
}

class _SupportDialogState extends State<SupportDialog> {
  Future<PackageInfo> _initPackageInfo() async {
    return await PackageInfo.fromPlatform();
  }

  Future _getUSerProfiles() async {
    return await db.getAll('SELECT * FROM users_profile');
  }

  Future _loadServerState() async {
    return await getServerConfig();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thünen Institute'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<PackageInfo>(
              future: _initPackageInfo(),
              builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else {
                  return ListTile(
                    title: Text('Version: ${snapshot.data!.version}'),
                    subtitle: Text('Build number: ${snapshot.data!.buildNumber}'),
                  );
                }
              },
            ),
            const SizedBox(height: 20),
            const Text('Your Supervisor:', style: TextStyle(fontWeight: FontWeight.bold)),
            FutureBuilder(
              future: _getUSerProfiles(),
              builder: (BuildContext context, AsyncSnapshot snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else {
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  if (snapshot.data.isEmpty) {
                    return const Text('No Supervisor defined.');
                  }

                  return Column(
                    children: snapshot.data.map<Widget>((user) {
                      if (user['user_id'] == getUserId()) {
                        return Container();
                      }
                      if (user['users_name'] == null || (user['email'] == null && user['phone'] == null)) {
                        return const Text('No support contacts available');
                      }
                      return ListTile(
                        title: Text(
                          user['users_name'] ?? 'no name',
                          softWrap: false,
                        ),
                        subtitle: Text(
                          user['users_company'] ?? '',
                          softWrap: false,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (user['email'] != null)
                              IconButton(
                                icon: const Icon(Icons.email),
                                onPressed: () {
                                  launchUrl(Uri.parse('mailto:${user['email']}'));
                                },
                              ),
                            if (user['phone'] != null)
                              IconButton(
                                icon: const Icon(Icons.phone),
                                onPressed: () {
                                  launchUrl(Uri.parse('tel:${user['phone']}'));
                                },
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                }
              },
            ),
            FutureBuilder(
              future: _loadServerState(),
              builder: (BuildContext context, AsyncSnapshot snapshot) {
                if (snapshot.hasData) {
                  return Column(
                    children: [
                      const SizedBox(height: 20),
                      Divider(),
                      ListTile(
                        title: const Text('Selected Server'),
                        subtitle: Text(snapshot.data['name'] + ': ' + snapshot.data['supabaseUrl']),
                      ),
                    ],
                  );
                } else {
                  return const SizedBox();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
