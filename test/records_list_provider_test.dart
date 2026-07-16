import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrestrial_forest_monitor/providers/records_list_provider.dart';
import 'package:terrestrial_forest_monitor/repositories/records_repository.dart';
import 'package:terrestrial_forest_monitor/widgets/cluster/order-cluster-by.dart';

Record _record(String id, {String? completedAtTroop, String? localUpdatedAt}) {
  return Record(
    id: id,
    properties: {},
    schemaName: 'schema',
    schemaId: 'schema-id',
    plotId: 'plot-$id',
    clusterId: 'cluster-$id',
    completedAtTroop: completedAtTroop,
    localUpdatedAt: localUpdatedAt,
  );
}

List<Map<String, dynamic>> _entries(List<Record> records) =>
    records.map((record) => {'record': record, 'metadata': null}).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('cacheRecords notifies on completion change with unchanged list length', () {
    final provider = RecordsListProvider();
    var notifications = 0;
    provider.addListener(() => notifications++);

    provider.cacheRecords(
      'all',
      ClusterOrderBy.clusterName,
      _entries([_record('a'), _record('b')]),
      0,
      false,
    );
    expect(notifications, 1, reason: 'initial cache fill must notify');

    provider.cacheRecords(
      'all',
      ClusterOrderBy.clusterName,
      _entries([_record('a'), _record('b')]),
      0,
      false,
    );
    expect(notifications, 1, reason: 'identical content must not notify');

    provider.cacheRecords(
      'all',
      ClusterOrderBy.clusterName,
      _entries([
        _record('a'),
        _record(
          'b',
          completedAtTroop: '2026-07-16T10:00:00Z',
          localUpdatedAt: '2026-07-16T10:00:00Z',
        ),
      ]),
      0,
      false,
    );
    expect(
      notifications,
      2,
      reason: 'completion toggle with same record count must notify',
    );
  });
}
