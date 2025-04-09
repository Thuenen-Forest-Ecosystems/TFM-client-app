import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UsersProfileList extends StatefulWidget {
  final List<Map<String, dynamic>>? usersProfileList;
  const UsersProfileList({super.key, required this.usersProfileList});

  @override
  State<UsersProfileList> createState() => _UsersProfileListState();
}

class _UsersProfileListState extends State<UsersProfileList> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.usersProfileList?.length ?? 0,
      itemBuilder: (context, index) {
        final userProfile = widget.usersProfileList![index];
        print(userProfile);
        return ListTile(
          title: Text(userProfile['email'] ?? 'N/A'),
          subtitle: Text(userProfile['id'] ?? 'N/A'),
          trailing:
              userProfile['email'] != null
                  ? IconButton(
                    icon: const Icon(Icons.email),
                    onPressed: () {
                      // Handle email action
                      launchUrl(Uri.parse('mailto:${userProfile['email']}'));
                    },
                  )
                  : null,
        );
      },
    );
  }
}
