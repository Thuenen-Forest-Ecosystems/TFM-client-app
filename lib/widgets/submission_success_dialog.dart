import 'dart:async';

import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';

/// Result returned from SubmissionSuccessDialog
class SubmissionSuccessResult {
  /// 'back' to go to records-selection, or 'open' to open a specific record
  final String action;

  /// The record to open (only set when action == 'open')
  final Record? selectedRecord;

  SubmissionSuccessResult({required this.action, this.selectedRecord});
}

/// Dialog shown after successfully submitting a record.
/// Lets the user either go back to the records/plot-selection
/// or pick the next record from the same cluster.
class SubmissionSuccessDialog extends StatefulWidget {
  final Record submittedRecord;

  const SubmissionSuccessDialog({super.key, required this.submittedRecord});

  @override
  State<SubmissionSuccessDialog> createState() => _SubmissionSuccessDialogState();

  /// Show the dialog and return the user's choice.
  static Future<SubmissionSuccessResult?> show(
    BuildContext context, {
    required Record submittedRecord,
  }) {
    return showDialog<SubmissionSuccessResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SubmissionSuccessDialog(submittedRecord: submittedRecord),
    );
  }
}

/// What actually happened to the submission, as opposed to what the old
/// dialog always claimed ("Erfolgreich übermittelt" on the local write alone).
enum _TransferState {
  /// Still in the upload queue, device has no server connection.
  pendingOffline,

  /// In the upload queue, connection is up — upload in flight.
  uploading,

  /// Queue is empty: the server accepted everything.
  delivered,

  /// The server refused this record; the data sits in the quarantine.
  rejected,
}

class _SubmissionSuccessDialogState extends State<SubmissionSuccessDialog> {
  List<Record>? _clusterRecords;
  bool _isLoading = true;

  int _pendingUploads = 0;
  bool _isRejected = false;
  bool _isConnected = false;
  StreamSubscription<dynamic>? _pendingSub;
  StreamSubscription<dynamic>? _rejectedSub;
  StreamSubscription<dynamic>? _statusSub;

  _TransferState get _transferState {
    if (_isRejected) return _TransferState.rejected;
    if (_pendingUploads == 0) return _TransferState.delivered;
    return _isConnected ? _TransferState.uploading : _TransferState.pendingOffline;
  }

  @override
  void initState() {
    super.initState();
    _loadClusterRecords();
    _watchTransferState();
  }

  /// Live view of the upload queue, so the dialog tells the truth while the
  /// user is still looking at it: pending → uploading → delivered.
  void _watchTransferState() {
    _isConnected = db.currentStatus.connected;
    _statusSub = db.statusStream.listen((status) {
      if (mounted) setState(() => _isConnected = status.connected);
    });
    _pendingSub = db.watch('SELECT COUNT(*) AS n FROM ps_crud').listen((rows) {
      if (mounted) {
        setState(() => _pendingUploads = rows.isNotEmpty ? (rows.first['n'] as int? ?? 0) : 0);
      }
    });
    _rejectedSub = db
        .watch(
          'SELECT COUNT(*) AS n FROM upload_failures WHERE record_id = ?',
          parameters: [widget.submittedRecord.id],
        )
        .listen((rows) {
          if (mounted) {
            final n = rows.isNotEmpty ? (rows.first['n'] as int? ?? 0) : 0;
            setState(() => _isRejected = n > 0);
          }
        });
  }

  @override
  void dispose() {
    _pendingSub?.cancel();
    _rejectedSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  Future<void> _loadClusterRecords() async {
    try {
      final records = await RecordsRepository().getRecordsByClusterName(
        widget.submittedRecord.clusterName ?? '',
      );

      // Exclude the just-submitted record from the list
      final otherRecords = records.where((r) => r.id != widget.submittedRecord.id).toList();

      if (mounted) {
        setState(() {
          _clusterRecords = otherRecords;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _clusterRecords = [];
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildStateIcon() {
    switch (_transferState) {
      case _TransferState.delivered:
        return const Icon(Icons.cloud_done, color: Colors.green, size: 48);
      case _TransferState.uploading:
        return const SizedBox(
          width: 44,
          height: 44,
          child: CircularProgressIndicator(strokeWidth: 3),
        );
      case _TransferState.pendingOffline:
        return Icon(Icons.cloud_off, color: Colors.orange.shade700, size: 48);
      case _TransferState.rejected:
        return const Icon(Icons.error_outline, color: Colors.red, size: 48);
    }
  }

  String get _stateTitle {
    switch (_transferState) {
      case _TransferState.delivered:
        return 'Übermittelt und vom Server bestätigt';
      case _TransferState.uploading:
        return 'Gespeichert — wird übertragen …';
      case _TransferState.pendingOffline:
        return 'Auf dem Gerät gespeichert';
      case _TransferState.rejected:
        return 'Übertragung nicht übernommen';
    }
  }

  String get _stateSubtitle {
    switch (_transferState) {
      case _TransferState.delivered:
        return 'Die Aufnahme ist auf dem Server angekommen.';
      case _TransferState.uploading:
        return _pendingUploads > 1
            ? 'Noch $_pendingUploads Änderungen in der Warteschlange.'
            : 'Die Übertragung läuft.';
      case _TransferState.pendingOffline:
        return 'Noch nicht übertragen — das geschieht automatisch, sobald wieder '
            'eine Verbindung besteht. Bitte vor dem Abschluss des Feldtags '
            'online gehen und den Sync-Status prüfen.';
      case _TransferState.rejected:
        return 'Der Server hat diese Änderung nicht übernommen. Die Daten sind '
            'lokal gesichert und stehen unter „Sicherungen" im '
            'Profil zur Wiederherstellung bereit.';
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final DateTime dt = DateTime.parse(date.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header — reflects the ACTUAL transfer state, not just the fact
            // that the local write succeeded.
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildStateIcon(),
                  const SizedBox(height: 12),
                  Text(
                    _stateTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Trakt ${widget.submittedRecord.clusterName} · Ecke ${widget.submittedRecord.plotName}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _stateSubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Cluster records list
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_clusterRecords != null && _clusterRecords!.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Weitere Ecken in Trakt ${widget.submittedRecord.clusterName}:',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _clusterRecords!.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 0),
                  itemBuilder: (context, index) {
                    final record = _clusterRecords![index];
                    final isCompleted =
                        record.completedAtTroop != null && record.completedAtTroop!.isNotEmpty;

                    final lastUpdate = record.localUpdatedAt ?? record.updatedAt;
                    final dateText = _formatDate(lastUpdate);

                    return ListTile(
                      title: Text(
                        'Ecke ${record.plotName}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: dateText.isNotEmpty
                          ? Text(
                              isCompleted ? 'Abgeschlossen: $dateText' : 'Bearbeitet: $dateText',
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          : Text('Nicht bearbeitet', style: Theme.of(context).textTheme.bodySmall),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onTap: () {
                        Navigator.of(
                          context,
                        ).pop(SubmissionSuccessResult(action: 'open', selectedRecord: record));
                      },
                    );
                  },
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Keine weiteren Ecken in diesem Trakt.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            const Divider(height: 1),

            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop(SubmissionSuccessResult(action: 'back'));
                      },
                      icon: const Icon(Icons.list),
                      label: const Text('Zur Übersicht'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
