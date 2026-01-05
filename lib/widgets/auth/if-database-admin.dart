import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

/// Widget that conditionally renders its child only if the current user is a database admin
class IfDatabaseAdmin extends StatefulWidget {
  final Widget child;

  const IfDatabaseAdmin({super.key, required this.child});

  @override
  State<IfDatabaseAdmin> createState() => _IfDatabaseAdminState();
}

class _IfDatabaseAdminState extends State<IfDatabaseAdmin> {
  bool _isDatabaseAdmin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkDatabaseAdminStatus();

    // Listen to auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        _checkDatabaseAdminStatus();
      }
    });
  }

  Future<void> _checkDatabaseAdminStatus() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _isDatabaseAdmin = false;
            _isLoading = false;
          });
        }
        return;
      }

      final result = await db.getAll('SELECT is_database_admin FROM users_profile WHERE id = ?', [
        user.id,
      ]);

      if (mounted) {
        setState(() {
          _isDatabaseAdmin = result.isNotEmpty && result.first['is_database_admin'] == 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking database admin status: $e');
      if (mounted) {
        setState(() {
          _isDatabaseAdmin = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show anything while loading
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    // Only render child if user is database admin
    return _isDatabaseAdmin ? widget.child : const SizedBox.shrink();
  }
}
