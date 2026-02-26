import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart';

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

class _SubmissionSuccessDialogState extends State<SubmissionSuccessDialog> {
  List<Record>? _clusterRecords;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClusterRecords();
  }

  Future<void> _loadClusterRecords() async {
    try {
      final records = await RecordsRepository().getRecordsByClusterName(
        widget.submittedRecord.clusterName,
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
      debugPrint('Error loading cluster records: $e');
      if (mounted) {
        setState(() {
          _clusterRecords = [];
          _isLoading = false;
        });
      }
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
            // Header with success message
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Erfolgreich übermittelt',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Trakt ${widget.submittedRecord.clusterName} · Ecke ${widget.submittedRecord.plotName}',
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
