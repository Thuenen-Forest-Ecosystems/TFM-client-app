import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beamer/beamer.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

class AdminButton extends StatefulWidget {
  const AdminButton({super.key});

  @override
  State<AdminButton> createState() => _AdminButtonState();
}

class _AdminButtonState extends State<AdminButton> {
  User? user = null; //getCurrentUser();

  /*@override
  void initState() {
    super.initState();

    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      print('STATE CHANGE');
      setState(() {
        user = getCurrentUser();
      });
    });

    print('USER: $user');
    print(user?.id);
    db.get('SELECT * FROM users_profile WHERE id = ?', [user?.id]).then((value) {
      print(value);
    }).catchError((error) {
      print('Error: $error');
    });
  }*/

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          User? user = getCurrentUser();

          if (user == null) {
            return SizedBox();
          }

          return FutureBuilder(
            future: db.get('SELECT * FROM users_profile WHERE id = ?', [user.id]),
            builder: (context, snapshot) {
              print('snapshot: $snapshot : ${user.id}');
              if (snapshot.hasData) {
                final data = snapshot.data as Map<String, dynamic>;

                if (data['is_admin'] == null || data.isEmpty) {
                  return SizedBox();
                }

                if (data['is_admin'] == 1) {
                  return IconButton(
                    onPressed: () {
                      context.beamToNamed('/admin');
                    },
                    icon: Icon(Icons.admin_panel_settings),
                  );
                } else {
                  return SizedBox();
                }
              }
              return SizedBox();
            },
          );
        } else {
          return SizedBox();
        }
      },
    );
    return FutureBuilder(
        future: db.get('SELECT * FROM users_profile WHERE id = ?', [user?.id]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SizedBox(
              width: 24,
              height: 24,
              child: const CircularProgressIndicator(),
            );
          }
          if (snapshot.hasError) {
            return SizedBox();
          }
          if (snapshot.hasData) {
            final data = snapshot.data as Map<String, dynamic>;

            if (data['is_admin'] == null || data.isEmpty) {
              return SizedBox();
            }

            if (data['is_admin'] == 1) {
              return IconButton(
                onPressed: () {
                  context.beamToNamed('/admin');
                },
                icon: Icon(Icons.admin_panel_settings),
              );
            }
          }
          return Icon(Icons.admin_panel_settings);
        });
  }
}
