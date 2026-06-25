import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/providers/auth.dart';
import 'package:terrestrial_forest_monitor/services/legacy_database_service.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

/// Banner shown on the home screen when leftover data is found in the legacy
/// shared `tfm.db` (written before per-user database isolation). Tapping it
/// opens a read-only modal so the user can inspect what is there.
class LegacyDataBanner extends StatefulWidget {
  const LegacyDataBanner({super.key});

  @override
  State<LegacyDataBanner> createState() => _LegacyDataBannerState();
}

class _LegacyDataBannerState extends State<LegacyDataBanner> {
  // Default to an empty summary so the admin banner can render immediately,
  // even before (or without) a successful legacy-db read.
  LegacyDataSummary _summary = const LegacyDataSummary(recordCount: 0, pendingUploadCount: 0);
  bool _isDatabaseAdmin = false;
  bool _dismissed = false;
  StreamSubscription<void>? _dbSwitchSub;
  StreamSubscription<dynamic>? _adminSub;

  @override
  void initState() {
    super.initState();
    // Read the user id now (sync) so the async checks don't touch context.
    final userId = context.read<AuthProvider>().userId;
    // Determine admin status and read the legacy db independently — a failure
    // to open the legacy db must never suppress the admin banner.
    _watchAdminStatus(userId);
    _refreshSummary();
    // Re-evaluate when switchUserDatabase swaps the global db (e.g. offline →
    // online upgrade), since users_profile is read from the active db.
    _dbSwitchSub = dbSwitchEvents.listen((_) {
      if (!mounted) return;
      LegacyDatabaseService.instance.invalidate();
      _watchAdminStatus(context.read<AuthProvider>().userId);
      _refreshSummary();
    });
  }

  @override
  void dispose() {
    _dbSwitchSub?.cancel();
    _adminSub?.cancel();
    super.dispose();
  }

  /// Watches the user's `is_database_admin` flag reactively, so the banner
  /// appears as soon as users_profile syncs into the active db — the row may
  /// not be present yet when this widget first mounts.
  void _watchAdminStatus(String? userId) {
    _adminSub?.cancel();
    // Prefer the AuthProvider id (works offline); fall back to Supabase.
    final id = userId ?? getUserId();
    if (id == null) return;
    _adminSub = db
        .watch('SELECT is_database_admin FROM users_profile WHERE id = ?', parameters: [id])
        .listen((result) {
          if (!mounted) return;
          final isAdmin = result.isNotEmpty && result.first['is_database_admin'] == 1;
          if (isAdmin != _isDatabaseAdmin) setState(() => _isDatabaseAdmin = isAdmin);
        });
  }

  Future<void> _refreshSummary() async {
    try {
      final summary = await LegacyDatabaseService.instance.getSummary();
      if (mounted) setState(() => _summary = summary);
    } catch (_) {
      // An unreadable/absent legacy db counts as "no data".
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final hasData = summary.hasData;

    // Non-admins only see the banner when there is actually data to recover,
    // and they may hide it for the session. Database admins always see it (even
    // when the legacy db is empty or absent) and cannot dismiss it, so they
    // have a permanent entry point to verify legacy data.
    if (!_isDatabaseAdmin && (_dismissed || !hasData)) {
      return const SizedBox.shrink();
    }

    final pending = summary.pendingUploadCount;

    // Appearance adapts to whether there is leftover data: an amber "found
    // data" alert vs. a neutral "nothing here" entry point for admins.
    final Color background = hasData ? Colors.amber.shade100 : Colors.blueGrey.shade50;
    final Color foreground = hasData ? Colors.amber.shade900 : Colors.blueGrey.shade700;
    final IconData leadingIcon = hasData ? Icons.inventory_2_outlined : Icons.fact_check_outlined;
    final String title = hasData ? 'Daten in lokaler Altdatenbank gefunden' : 'Altdatenbank';
    final String subtitle = !hasData
        ? 'Keine Altdaten vorhanden. Tippen zum Prüfen.'
        : pending > 0
        ? '$pending NICHT hochgeladene Änderung(en) und ${summary.recordCount} Datensatz(e).'
        : '${summary.recordCount} Datensatz(e) gefunden. Tippen zum Anzeigen.';

    return Material(
      color: background,
      child: InkWell(
        onTap: () => _showModal(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(leadingIcon, color: foreground),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontWeight: FontWeight.bold, color: foreground),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: foreground)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: foreground),
              if (!_isDatabaseAdmin)
                IconButton(
                  tooltip: 'Ausblenden',
                  icon: Icon(Icons.close, size: 18, color: foreground),
                  onPressed: () => setState(() => _dismissed = true),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => LegacyDataModal(summary: _summary),
    );
  }
}

/// Read-only modal listing the records found in the legacy `tfm.db`.
class LegacyDataModal extends StatelessWidget {
  final LegacyDataSummary summary;

  const LegacyDataModal({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Altdaten',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                summary.pendingUploadCount > 0
                    ? 'Diese Daten stammen aus der gemeinsam genutzten Altdatenbank. '
                          '${summary.pendingUploadCount} Änderung(en) wurden nie hochgeladen und '
                          'sind nur hier lokal vorhanden.'
                    : 'Diese Daten stammen aus der gemeinsam genutzten Altdatenbank. '
                          'Bereits synchronisierte Datensätze sind auch auf dem Server vorhanden.',
                style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
              ),
            ),
            const Divider(height: 16),
            // Records list
            Flexible(
              child: FutureBuilder<List<LegacyRecord>>(
                future: LegacyDatabaseService.instance.getRecords(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Fehler beim Lesen der Altdatenbank: ${snapshot.error}'),
                    );
                  }
                  final records = snapshot.data ?? const [];
                  if (records.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('Keine Datensätze gefunden.')),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: records.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) => _LegacyRecordTile(record: records[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _RecoverState { idle, recovering, done, error }

class _LegacyRecordTile extends StatefulWidget {
  final LegacyRecord record;

  const _LegacyRecordTile({required this.record});

  @override
  State<_LegacyRecordTile> createState() => _LegacyRecordTileState();
}

class _LegacyRecordTileState extends State<_LegacyRecordTile> {
  _RecoverState _state = _RecoverState.idle;
  String? _error;

  LegacyRecord get record => widget.record;

  String _prettyProperties() {
    final raw = record.properties;
    if (raw == null || raw.isEmpty) return '—';
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
    } catch (_) {
      return raw;
    }
  }

  Future<void> _recover() async {
    setState(() {
      _state = _RecoverState.recovering;
      _error = null;
    });
    try {
      final ok = await LegacyDatabaseService.instance.recoverRecord(record.id);
      if (mounted) {
        setState(() => _state = ok ? _RecoverState.done : _RecoverState.error);
        if (!ok) _error = 'Datensatz nicht mehr in der Altdatenbank gefunden.';
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _RecoverState.error;
          _error = e.toString();
        });
      }
    }
  }

  Widget _buildRecoverButton() {
    switch (_state) {
      case _RecoverState.recovering:
        return TextButton.icon(
          onPressed: null,
          icon: const SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          label: const Text('Wird wiederhergestellt …'),
        );
      case _RecoverState.done:
        return TextButton.icon(
          onPressed: null,
          icon: const Icon(Icons.check_circle, color: Colors.green),
          label: Text('Wiederhergestellt', style: TextStyle(color: Colors.green.shade700)),
        );
      case _RecoverState.idle:
      case _RecoverState.error:
        return FilledButton.tonalIcon(
          onPressed: _recover,
          icon: const Icon(Icons.restore, size: 18),
          label: Text(_state == _RecoverState.error ? 'Erneut versuchen' : 'Wiederherstellen'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = [
      if (record.clusterName?.isNotEmpty ?? false) record.clusterName,
      if (record.plotName?.isNotEmpty ?? false) record.plotName,
    ].whereType<String>().join(' · ');

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(
        record.isValid ? Icons.check_circle : Icons.radio_button_unchecked,
        color: record.isValid ? Colors.green : Colors.grey,
        size: 20,
      ),
      title: Text(title.isEmpty ? record.id : title),
      subtitle: Text(
        [
          if (record.schemaName?.isNotEmpty ?? false) record.schemaName!,
          if (record.updatedAt?.isNotEmpty ?? false) record.updatedAt!,
        ].join('  ·  '),
        style: const TextStyle(fontSize: 12),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (record.note?.isNotEmpty ?? false) ...[
          Text('Notiz: ${record.note}', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: SelectableText(
            _prettyProperties(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight, child: _buildRecoverButton()),
      ],
    );
  }
}
