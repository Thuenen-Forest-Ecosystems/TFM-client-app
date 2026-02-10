import 'dart:async';

import 'package:flutter/material.dart';
import 'package:powersync/sqlite3_common.dart' as sqlite;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:intl/intl.dart';

class MessagesChat extends StatefulWidget {
  final String recordId;
  final bool readOnly;

  const MessagesChat({super.key, required this.recordId, this.readOnly = false});

  @override
  State<MessagesChat> createState() => _MessagesChatState();
}

class _MessagesChatState extends State<MessagesChat> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String? _currentUserId;
  StreamSubscription<sqlite.ResultSet>? _messagesSubscription;

  @override
  void initState() {
    super.initState();

    _loadCurrentUser();
    _watchMessages();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      setState(() {
        _currentUserId = user?.id;
      });
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  void _watchMessages() {
    _messagesSubscription = db
        .watch(
          'SELECT rm.*, up.email, up.user_name FROM records_messages rm LEFT JOIN users_profile up ON rm.user_id = up.id WHERE rm.records_id = ? ORDER BY rm.created_at ASC',
          parameters: [widget.recordId],
        )
        .listen(
          (sqlite.ResultSet resultSet) {
            final messages = <Map<String, dynamic>>[];
            for (final row in resultSet) {
              final message = Map<String, dynamic>.from(row);
              messages.add(message);
            }

            if (mounted) {
              setState(() {
                _messages = messages;
                _isLoading = false;
              });
            }

            // Scroll to bottom after loading messages
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          },
          onError: (error) {
            setState(() {
              _isLoading = false;
            });
          },
        );
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    final messageId = db.execute('SELECT uuid() as id').then((result) => result.first['id']);
    final timestamp = DateTime.now().toIso8601String();

    try {
      await db.execute(
        '''
        INSERT INTO records_messages (id, records_id, note, user_id, created_at)
        VALUES (?, ?, ?, ?, ?)
        ''',
        [await messageId, widget.recordId, messageText, _currentUserId, timestamp],
      );

      _messageController.clear();

      // Verify what was actually saved
      final saved = await db.get('SELECT id, records_id, note FROM records_messages WHERE id = ?', [
        await messageId,
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim Senden der Nachricht: $e')));
      }
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await db.execute('DELETE FROM records_messages WHERE id = ?', [messageId]);
    } catch (e) {
      debugPrint('Error deleting message: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim Löschen der Nachricht: $e')));
      }
    }
  }

  void _showDeleteConfirmation(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nachricht löschen'),
        content: const Text('Möchten Sie diese Nachricht wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteMessage(messageId);
            },
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isOwnMessage = message['user_id'] == _currentUserId;
    final timestamp = message['created_at'] != null
        ? DateTime.parse(message['created_at'] as String)
        : null;
    final formattedTime = timestamp != null ? DateFormat('dd.MM.yyyy HH:mm').format(timestamp) : '';

    return Align(
      alignment: isOwnMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.80),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message['email'] != null) ...[
                  Text(
                    message['email'] as String,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(message['note'] ?? ''),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(formattedTime, style: const TextStyle(fontSize: 10)),
                    SizedBox(width: 8),
                    if (isOwnMessage && !widget.readOnly) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _showDeleteConfirmation(message['id'] as String),
                        child: const Icon(Icons.delete_outline, size: 14),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Check if we have bounded constraints
        final hasHeight = constraints.maxHeight != double.infinity;

        final chatContent = Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                  ? const Center(
                      child: Text('Keine Nachrichten', style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageBubble(_messages[index]);
                      },
                    ),
            ),
            if (!widget.readOnly)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Nachricht eingeben...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        keyboardType: TextInputType.multiline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(onPressed: _sendMessage, icon: const Icon(Icons.send)),
                  ],
                ),
              ),
          ],
        );

        // If no bounded height, wrap in SizedBox to provide constraints
        if (!hasHeight) {
          return SizedBox(height: MediaQuery.of(context).size.height * 0.7, child: chatContent);
        }

        return chatContent;
      },
    );
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
