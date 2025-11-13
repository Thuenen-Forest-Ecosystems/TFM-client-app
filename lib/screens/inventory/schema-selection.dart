import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:beamer/beamer.dart';
import 'package:terrestrial_forest_monitor/repositories/schema_repository.dart';

class SchemaSelection extends StatefulWidget {
  const SchemaSelection({super.key});

  @override
  State<SchemaSelection> createState() => _SchemaSelectionState();
}

class _SchemaSelectionState extends State<SchemaSelection> {
  @override
  Widget build(BuildContext context) {
    final repository = context.read<SchemaRepository>();
    // Try to get ScrollController from Provider, but it's optional
    final scrollController = context.watch<ScrollController?>();

    return StreamBuilder<List<SchemaModel>>(
      stream: repository.watchUniqueByInterval(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.error_outline, size: 64, color: Colors.red[300]), const SizedBox(height: 16), Text('Fehler: ${snapshot.error}', style: const TextStyle(fontSize: 16))]),
          );
        }

        final schemas = snapshot.data ?? [];

        if (schemas.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('Keine Schemas verfügbar', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  Text('Bitte synchronisieren Sie die Daten', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: schemas.length,
          physics: const ClampingScrollPhysics(),
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          itemBuilder: (context, index) {
            final schema = schemas[index];
            return _SchemaCard(schema: schema, onTap: () => _handleSchemaSelection(context, schema));
          },
        );
      },
    );
  }

  void _handleSchemaSelection(BuildContext context, SchemaModel schema) {
    final encodedIntervalName = Uri.encodeComponent(schema.intervalName);
    Beamer.of(context).beamToNamed('/records-selection/$encodedIntervalName');
  }
}

class _SchemaCard extends StatelessWidget {
  final SchemaModel schema;
  final VoidCallback onTap;

  const _SchemaCard({required this.schema, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                    child: Text(schema.intervalName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                  ),
                  const Spacer(),
                  if (schema.version != null) Text('v${schema.version}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(width: 8),
                  Icon(schema.isVisible ? Icons.visibility : Icons.visibility_off, size: 20, color: schema.isVisible ? Colors.green : Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              Text(schema.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (schema.description != null && schema.description!.isNotEmpty) ...[const SizedBox(height: 8), Text(schema.description!, style: TextStyle(fontSize: 14, color: Colors.grey[700]), maxLines: 2, overflow: TextOverflow.ellipsis)],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(_formatDate(schema.createdAt), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
