import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class UserInfoTile extends StatefulWidget {
  const UserInfoTile({super.key});

  @override
  State<UserInfoTile> createState() => _UserInfoTileState();
}

class _UserInfoTileState extends State<UserInfoTile> {
  User? _user;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();

    // Listen to auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {
          _user = data.session?.user;
          _loadUserProfile();
        });
      }
    });
  }

  void _loadUserInfo() {
    setState(() {
      _user = getCurrentUser();
    });
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    if (_user == null) {
      setState(() {
        _userProfile = null;
      });
      return;
    }

    try {
      final result = await db.getAll('SELECT * FROM users_profile WHERE id = ?', [_user!.id]);

      if (mounted && result.isNotEmpty) {
        setState(() {
          _userProfile = result.first;
        });
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Material(
        child: ListTile(
          title: Text('Nicht angemeldet'),
          subtitle: Text('Bitte melden Sie sich an'),
        ),
      );
    }

    final email = _user!.email ?? 'Keine E-Mail';
    final name = _user!.userMetadata?['name'] ?? _user!.userMetadata?['full_name'];
    final isDatabaseAdmin = _userProfile?['is_database_admin'] == 1;
    final isAdmin = _userProfile?['is_admin'] == 1;

    return Material(
      child: ListTile(
        leading: Icon(Icons.person),
        title: Text(name ?? 'Benutzer'),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(email)]),
        trailing: (isDatabaseAdmin || isAdmin) ? const Icon(Icons.admin_panel_settings) : null,
      ),
    );
  }
}
