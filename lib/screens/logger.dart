import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:terrestrial_forest_monitor/services/log_service.dart';

class LoggerScreen extends StatefulWidget {
  const LoggerScreen({super.key});

  @override
  State<LoggerScreen> createState() => _LoggerScreenState();
}

class _LoggerScreenState extends State<LoggerScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  LogLevel _filterLevel = LogLevel.debug;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
    }
  }

  IconData _getLevelIcon(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Icons.bug_report;
      case LogLevel.info:
        return Icons.info_outline;
      case LogLevel.warning:
        return Icons.warning_amber;
      case LogLevel.error:
        return Icons.error_outline;
    }
  }

  void _addTestLog() {
    final logService = LogService();
    logService.log('🧪 Test log entry at ${DateTime.now()}', level: LogLevel.info);
    logService.log('This is a sample debug message', level: LogLevel.debug);
    logService.log('This is a sample warning message', level: LogLevel.warning);
    logService.log('This is a sample error message', level: LogLevel.error);
  }

  @override
  Widget build(BuildContext context) {
    final logService = LogService();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.loggerTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.science),
            tooltip: l10n.loggerAddTestLog,
            onPressed: _addTestLog,
          ),
          PopupMenuButton<LogLevel>(
            icon: const Icon(Icons.filter_list),
            tooltip: l10n.loggerFilter,
            onSelected: (level) {
              setState(() {
                _filterLevel = level;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: LogLevel.debug,
                child: Row(
                  children: [
                    const Icon(Icons.bug_report, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(l10n.loggerFilterAll),
                  ],
                ),
              ),
              PopupMenuItem(
                value: LogLevel.info,
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(l10n.loggerFilterInfo),
                  ],
                ),
              ),
              PopupMenuItem(
                value: LogLevel.warning,
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(l10n.loggerFilterWarning),
                  ],
                ),
              ),
              PopupMenuItem(
                value: LogLevel.error,
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(l10n.loggerFilterError),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center),
            tooltip: _autoScroll ? l10n.loggerAutoScrollOn : l10n.loggerAutoScrollOff,
            onPressed: () {
              setState(() {
                _autoScroll = !_autoScroll;
              });
              if (_autoScroll) {
                _scrollToBottom();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: l10n.loggerCopyAll,
            onPressed: () {
              final allLogs = logService.logs
                  .map(
                    (log) =>
                        '[${log.formattedTime}] [${log.level.name.toUpperCase()}] ${log.message}',
                  )
                  .join('\n');
              Clipboard.setData(ClipboardData(text: allLogs));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.loggerCopiedAll)));
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.loggerClear,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.loggerClearTitle),
                  content: Text(l10n.loggerClearConfirm),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.loggerCancel),
                    ),
                    TextButton(
                      onPressed: () {
                        logService.clear();
                        Navigator.pop(context);
                      },
                      child: Text(l10n.loggerDelete, style: const TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats bar
          Container(
            padding: const EdgeInsets.all(8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.loggerEntryCount(logService.logs.length),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(l10n.loggerFilterLabel(_filterLevel.name), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          // Logs list
          Expanded(
            child: StreamBuilder<LogEntry>(
              stream: logService.logStream,
              builder: (context, snapshot) {
                // Trigger auto-scroll when new log arrives
                if (snapshot.hasData && _autoScroll) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                }

                final filteredLogs = logService.logs.where((log) {
                  return log.level.index >= _filterLevel.index;
                }).toList();

                if (filteredLogs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.article_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          l10n.loggerEmpty,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: filteredLogs.length,
                  itemBuilder: (context, index) {
                    final log = filteredLogs[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        _getLevelIcon(log.level),
                        size: 20,
                        color: _getLevelColor(log.level),
                      ),
                      title: Text(
                        log.message,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: _getLevelColor(log.level),
                        ),
                      ),
                      subtitle: Text(log.formattedTime, style: const TextStyle(fontSize: 10)),
                      onLongPress: () {
                        Clipboard.setData(ClipboardData(text: log.message));
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(l10n.loggerCopiedEntry)));
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
