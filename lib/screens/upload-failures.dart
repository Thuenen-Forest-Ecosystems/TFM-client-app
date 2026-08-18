import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:terrestrial_forest_monitor/services/legacy_database_service.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/services/upload_failure_service.dart';
import 'package:terrestrial_forest_monitor/widgets/database-backup-button.dart';

/// Central recovery page for local data that never reached the server.
///
/// One tab per database file:
/// - "Aktive DB": quarantined uploads from the local-only `upload_failures`
///   table (ops the server rejected or silently ignored). Re-applying writes
///   through the PowerSync view, so the change re-enters the upload queue.
/// - One tab per inactive database file (legacy shared db, other users'
///   per-user files): rows stranded there, recoverable into the active db.
class UploadFailuresScreen extends StatefulWidget {
  const UploadFailuresScreen({super.key});

  @override
  State<UploadFailuresScreen> createState() => _UploadFailuresScreenState();
}

class _UploadFailuresScreenState extends State<UploadFailuresScreen> {
  List<UploadFailure> _failures = [];
  bool _loading = true;
  bool _busy = false;
  StreamSubscription<dynamic>? _watchSub;
  StreamSubscription<void>? _dbSwitchSub;

  List<DatabaseFileInfo> _otherDbs = [];
  bool _dbsLoading = true;
  String? _activeDbName;

  @override
  void initState() {
    super.initState();
    _subscribe();
    _loadOtherDbs();
    _loadActiveDbName();
    _dbSwitchSub = dbSwitchEvents.listen((_) {
      _watchSub?.cancel();
      _subscribe();
      // The active file changed, so the set of "other" files changed too.
      _loadOtherDbs();
      _loadActiveDbName();
    });
  }

  Future<void> _loadActiveDbName() async {
    try {
      final path = await getActiveDatabasePath();
      if (mounted) setState(() => _activeDbName = p.basename(path));
    } catch (_) {}
  }

  void _subscribe() {
    _watchSub = db.watch(UploadFailureService.watchSql).listen((rows) {
      if (!mounted) return;
      setState(() {
        _failures = rows
            .map((r) => UploadFailureService.rowToFailure({for (final k in r.keys) k: r[k]}))
            .toList();
        _loading = false;
      });
    });
  }

  Future<void> _loadOtherDbs() async {
    try {
      final dbs = await LegacyDatabaseService.instance.listOtherDatabaseFiles();
      if (mounted) {
        setState(() {
          _otherDbs = dbs;
          _dbsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _dbsLoading = false);
    }
  }

  @override
  void dispose() {
    _watchSub?.cancel();
    _dbSwitchSub?.cancel();
    super.dispose();
  }

  Future<void> _restore(UploadFailure failure) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upload wiederherstellen?'),
        content: Text(
          'Der gesicherte Stand von ${_title(failure)} wird lokal übernommen '
          '(überschreibt den aktuellen lokalen Stand dieses Datensatzes) und '
          'beim nächsten Sync erneut hochgeladen.\n\n'
          'Schlägt der Upload wieder fehl, erscheint der Eintrag erneut in dieser Liste.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Wiederherstellen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await UploadFailureService.restore(failure);
      _showSnack('Wiederhergestellt — wird beim nächsten Sync erneut hochgeladen.');
    } catch (e) {
      _showSnack('Wiederherstellen fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Alle ${_failures.length} Einträge wiederherstellen?'),
        content: const Text(
          'Alle gesicherten Stände werden lokal übernommen (älteste zuerst) und '
          'beim nächsten Sync erneut hochgeladen. Aktuelle lokale Stände der '
          'betroffenen Datensätze werden überschrieben.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Alle wiederherstellen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final errors = await UploadFailureService.restoreAll(_failures);
      _showSnack(
        errors.isEmpty
            ? 'Alle Einträge wiederhergestellt — Upload folgt beim nächsten Sync.'
            : '${errors.length} Einträge konnten nicht übernommen werden:\n${errors.join('\n')}',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discard(UploadFailure failure) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 36),
        title: const Text('Eintrag endgültig verwerfen?'),
        content: Text(
          'Die gesicherten Daten von ${_title(failure)} werden gelöscht und '
          'können danach nicht mehr wiederhergestellt werden.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Verwerfen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await UploadFailureService.discard(failure);
    } catch (e) {
      _showSnack('Löschen fehlgeschlagen: $e');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    // Fixed (not floating): a still-visible snackbar re-attaches to whatever
    // Scaffold is current after back-navigation, and floating ones assert
    // when that Scaffold's bottom widgets leave too little room (schema.dart
    // home screen with its VersionControl bottom bar).
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _title(UploadFailure f) {
    if (f.tableName == 'records' && (f.clusterName != null || f.plotName != null)) {
      return 'Trakt ${f.clusterName ?? '?'} / ${f.plotName ?? '?'}';
    }
    return '${f.tableName} ${f.recordId}';
  }

  String _reasonText(UploadFailure f) {
    switch (f.reason) {
      case 'rls_zero_rows':
        return 'Vom Server ignoriert (keine Schreibberechtigung für diesen Datensatz)';
      case 'fatal_error':
        return 'Vom Server abgelehnt${f.errorCode != null ? ' [${f.errorCode}]' : ''}';
      case 'unattempted_after_fatal':
        return 'Nicht versucht (vorheriger Upload derselben Übertragung wurde abgelehnt)';
      default:
        return f.reason ?? 'Unbekannt';
    }
  }

  String _formatTs(String? ts) {
    if (ts == null) return '–';
    try {
      final dt = DateTime.parse(ts).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Without inactive database files there is nothing to tab — plain page.
    if (_dbsLoading || _otherDbs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nicht übernommene Uploads')),
        body: _buildQuarantineBody(context),
        bottomNavigationBar: const DatabaseBackupButton(),
      );
    }

    final tabs = <Tab>[
      Tab(text: _failures.isEmpty ? 'Aktive DB' : 'Aktive DB (${_failures.length})'),
      ..._otherDbs.map(
        (info) => Tab(
          text: info.pendingUploadCount > 0
              ? '${info.label} (⚠ ${info.pendingUploadCount})'
              : info.label,
        ),
      ),
    ];

    // The app's AppBar is light green in BOTH themes (#C3E399 light /
    // #E0F1CB dark), while the M3 TabBar defaults pick the theme's green
    // primary for labels — green on green. Derive the label color from the
    // actual AppBar background instead, so tabs stay readable in both themes.
    final appBarBg =
        Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).colorScheme.surface;
    final onAppBar = ThemeData.estimateBrightnessForColor(appBarBg) == Brightness.dark
        ? Colors.white
        : Colors.black87;

    return DefaultTabController(
      key: ValueKey('upload-failures-tabs-${_otherDbs.length}'),
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Nicht übernommene Uploads'),
          bottom: TabBar(
            isScrollable: true,
            labelColor: onAppBar,
            unselectedLabelColor: onAppBar.withValues(alpha: 0.55),
            indicatorColor: onAppBar,
            tabs: tabs,
          ),
        ),
        body: TabBarView(
          children: [
            _buildQuarantineBody(context),
            ..._otherDbs.map((info) => _DatabaseFileTab(key: ValueKey(info.path), info: info)),
          ],
        ),
        bottomNavigationBar: const DatabaseBackupButton(),
      ),
    );
  }

  // ── Tab 1: quarantined uploads of the active database ──────────────────

  Widget _buildQuarantineBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    // Mirrors the layout of _DatabaseFileTab: bold summary line, explanation,
    // actions on the right, list (or centered message) below.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_activeDbName ?? 'Aktive Datenbank'}'
                          '${_failures.isNotEmpty ? ' · ${_failures.length} nicht übernommen' : ''}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _failures.isNotEmpty
                              ? 'Diese Änderungen hat der Server nicht übernommen. Die '
                                    'Daten sind lokal gesichert und können erneut '
                                    'übertragen werden.'
                              : 'Alle Uploads dieser Datenbank wurden vom Server '
                                    'übernommen.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (_failures.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    FilledButton.icon(
                      onPressed: _busy ? null : _restoreAll,
                      icon: const Icon(Icons.restore, size: 18),
                      label: Text('Alle ${_failures.length} wiederherstellen'),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _failures.isEmpty
                  ? const Center(
                      child: Text('Keine Einträge — alle Uploads wurden übernommen.'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: _failures.length,
                      itemBuilder: (context, index) => _buildEntry(context, _failures[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntry(BuildContext context, UploadFailure failure) {
    // Quarantined entries are by definition not in sync — every card gets the
    // restore icon. The op payload is not shown here; it stays available via
    // the diagnostic export.
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Icon(
          failure.reason == 'rls_zero_rows' ? Icons.visibility_off_outlined : Icons.block,
          color: Colors.red,
        ),
        title: Text(_title(failure)),
        subtitle: Text(
          '${_formatTs(failure.createdAt)} · ${failure.op} · ${_reasonText(failure)}'
          '${failure.errorMessage != null ? '\n${failure.errorMessage}' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: failure.errorMessage != null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Wiederherstellen',
              onPressed: _busy ? null : () => _restore(failure),
              icon: const Icon(Icons.restore),
            ),
            IconButton(
              tooltip: 'Verwerfen',
              onPressed: _busy ? null : () => _discard(failure),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tabs 2+: rows in an inactive database file ────────────────────────────

class _DatabaseFileTab extends StatefulWidget {
  final DatabaseFileInfo info;

  const _DatabaseFileTab({super.key, required this.info});

  @override
  State<_DatabaseFileTab> createState() => _DatabaseFileTabState();
}

class _DatabaseFileTabState extends State<_DatabaseFileTab>
    with AutomaticKeepAliveClientMixin {
  List<LegacyRecord> _records = [];
  Set<String> _pendingIds = {};
  final Set<String> _recovered = {};
  bool _loading = true;
  bool _busy = false;
  String? _error;

  DatabaseFileInfo get info => widget.info;

  // Opening the file is comparatively expensive — keep the tab alive so
  // switching tabs doesn't reopen it every time.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await LegacyDatabaseService.instance.getRecords(path: info.path);
      final pending = await LegacyDatabaseService.instance.getPendingRecordIds(path: info.path);
      // At-risk rows (never uploaded) first; within a group keep the query's
      // local_updated_at DESC order.
      records.sort((a, b) {
        final ap = pending.contains(a.id) ? 0 : 1;
        final bp = pending.contains(b.id) ? 0 : 1;
        return ap.compareTo(bp);
      });
      if (mounted) {
        setState(() {
          _records = records;
          _pendingIds = pending;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _recover(LegacyRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Datensatz wiederherstellen?'),
        content: Text(
          'Der Stand von ${_recordTitle(record)} aus „${info.fileName}“ wird in '
          'die aktive Datenbank übernommen (überschreibt den dortigen Stand) und '
          'beim nächsten Sync hochgeladen.\n\n'
          'Lehnt der Server den Upload ab, erscheint er im Tab „Aktive DB“. '
          'Die Quelldatei bleibt unverändert.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Wiederherstellen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final ok = await LegacyDatabaseService.instance.recoverRecord(record.id, path: info.path);
      if (ok) {
        setState(() => _recovered.add(record.id));
        _showSnack('In aktive Datenbank übernommen — Upload folgt beim nächsten Sync.');
      } else {
        _showSnack('Datensatz nicht mehr in „${info.fileName}“ gefunden.');
      }
    } catch (e) {
      _showSnack('Wiederherstellen fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recoverAllPending() async {
    final pendingRecords = _records
        .where((r) => _pendingIds.contains(r.id) && !_recovered.contains(r.id))
        .toList();
    if (pendingRecords.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${pendingRecords.length} nicht hochgeladene Datensätze wiederherstellen?'),
        content: const Text(
          'Alle Datensätze mit nie hochgeladenen Änderungen werden in die '
          'aktive Datenbank übernommen (überschreiben den dortigen Stand) und '
          'beim nächsten Sync hochgeladen.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Alle wiederherstellen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    var recoveredCount = 0;
    final errors = <String>[];
    try {
      for (final record in pendingRecords) {
        try {
          final ok = await LegacyDatabaseService.instance.recoverRecord(
            record.id,
            path: info.path,
          );
          if (ok) {
            recoveredCount++;
            _recovered.add(record.id);
          }
        } catch (e) {
          errors.add('${_recordTitle(record)}: $e');
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    _showSnack(
      errors.isEmpty
          ? '$recoveredCount Datensätze übernommen — Upload folgt beim nächsten Sync.'
          : '$recoveredCount übernommen, ${errors.length} fehlgeschlagen:\n${errors.join('\n')}',
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    // Fixed (not floating): a still-visible snackbar re-attaches to whatever
    // Scaffold is current after back-navigation, and floating ones assert
    // when that Scaffold's bottom widgets leave too little room (schema.dart
    // home screen with its VersionControl bottom bar).
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _recordTitle(LegacyRecord record) {
    final title = [
      if (record.clusterName?.isNotEmpty ?? false) record.clusterName,
      if (record.plotName?.isNotEmpty ?? false) record.plotName,
    ].whereType<String>().join(' / ');
    return title.isEmpty ? record.id : 'Trakt $title';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Fehler beim Lesen von „${info.fileName}“: $_error'),
        ),
      );
    }

    final pendingCount = _records.where((r) => _pendingIds.contains(r.id)).length;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${info.fileName} · ${_records.length} Datensätze'
                          '${pendingCount > 0 ? ' · $pendingCount nie hochgeladen' : ''}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (!info.isShared &&
                            ((info.userName?.isNotEmpty ?? false) ||
                                (info.email?.isNotEmpty ?? false)))
                          Text(
                            [
                              if (info.userName?.isNotEmpty ?? false) info.userName!,
                              if (info.email?.isNotEmpty ?? false) info.email!,
                            ].join(' · '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        Text(
                          pendingCount > 0
                              ? 'Datensätze mit „Nicht hochgeladen“ existieren NUR in dieser '
                                    'Datei — der Server hat sie nie erhalten.'
                              : 'Alle Datensätze dieser Datei wurden auch auf den Server '
                                    'hochgeladen oder stammen von dort.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Neu laden',
                    onPressed: _busy ? null : _load,
                    icon: const Icon(Icons.refresh, size: 20),
                  ),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 4),
                    FilledButton.icon(
                      onPressed: _busy ? null : _recoverAllPending,
                      icon: const Icon(Icons.restore, size: 18),
                      label: Text('Alle $pendingCount wiederherstellen'),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _records.isEmpty
                  ? const Center(child: Text('Keine Datensätze in dieser Datei.'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: _records.length,
                      itemBuilder: (context, index) => _buildRecordTile(context, _records[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordTile(BuildContext context, LegacyRecord record) {
    final isPending = _pendingIds.contains(record.id);
    final isRecovered = _recovered.contains(record.id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Icon(
          isRecovered
              ? Icons.check_circle
              : isPending
              ? Icons.cloud_off
              : Icons.description_outlined,
          color: isRecovered
              ? Colors.green
              : isPending
              ? Colors.orange
              : Colors.grey,
        ),
        title: Row(
          children: [
            Flexible(child: Text(_recordTitle(record))),
            if (isPending) ...[
              const SizedBox(width: 8),
              Chip(
                label: const Text('Nicht hochgeladen', style: TextStyle(fontSize: 10)),
                backgroundColor: Colors.orange.shade100,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ],
        ),
        subtitle: Text(
          [
            if (record.schemaName?.isNotEmpty ?? false) record.schemaName!,
            if (record.updatedAt?.isNotEmpty ?? false) record.updatedAt!,
          ].join('  ·  '),
          style: const TextStyle(fontSize: 12),
        ),
        // Restore only for rows the server never received (still in this
        // file's upload queue). Everything else is already in sync and needs
        // no action.
        trailing: isRecovered
            ? const Icon(Icons.check_circle, color: Colors.green)
            : isPending
            ? IconButton(
                tooltip: 'Wiederherstellen',
                onPressed: _busy ? null : () => _recover(record),
                icon: const Icon(Icons.restore),
              )
            : null,
      ),
    );
  }
}
