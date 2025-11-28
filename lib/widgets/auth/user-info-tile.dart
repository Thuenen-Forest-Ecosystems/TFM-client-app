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

  @override
  void initState() {
    super.initState();
    _loadUserInfo();

    // Listen to auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {
          _user = data.session?.user;
        });
      }
    });
  }

  void _loadUserInfo() {
    setState(() {
      _user = getCurrentUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const ListTile(
        title: Text('Nicht angemeldet'),
        subtitle: Text('Bitte melden Sie sich an'),
      );
    }

    final email = _user!.email ?? 'Keine E-Mail';
    final name = _user!.userMetadata?['name'] ?? _user!.userMetadata?['full_name'];

    return ListTile(
      leading: Icon(Icons.person),
      title: Text(name ?? 'Benutzer'),
      subtitle: Text(email),
    );
  }
}
