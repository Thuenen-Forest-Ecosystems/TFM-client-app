import 'package:brick_core/core.dart';
import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/brick-models/plot.model.dart';
import 'package:terrestrial_forest_monitor/brick-models/plot_nested.model.dart';
import 'package:terrestrial_forest_monitor/brick/repository.dart';

// BRICK
import 'package:terrestrial_forest_monitor/brick/repository.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;

class BrickScreen extends StatefulWidget {
  const BrickScreen({super.key});

  @override
  State<BrickScreen> createState() => _BrickScreenState();
}

class _BrickScreenState extends State<BrickScreen> {
  Future _getPlotSupabase() async {
    /*await Supabase.initialize(
      url: 'http://127.0.0.1:54321', //supabaseUrl,
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0', // supabaseAnonKey,
    );
    print('PLOT DATA SUPABASE START');
    try {
      final data = await Supabase.instance.client.from('plot').select().eq('cluster_name', 1);
      print('PLOT DATA SUPABASE');
      print(data);
    } catch (e) {
      print('ERROR');
      print(e);
    }*/
  }

  Future _getPlots() async {
    print('-----------PLOT DATA START');
    List<Plot> data = await Repository().get<Plot>(query: Query.where('cluster_name', 200));
    print('-----------PLOT DATA');
    print(data);
  }

  // filepath: /Users/b-mini/sites/thuenen/tfm/TFM-app/lib/screens/brick.dart
  Future<void> _getNestedPlots() async {
    try {
      print('-----------PLOT DATA START');

      // QUERY ALL RECORDS from Server
      List<PlotNestedJson> data = await Repository().get<PlotNestedJson>();

      print('-----------PLOT DATA RETRIEVED');
      print('Number of records: ${data.length}');

      // Print the first few records
      for (int i = 0; i < data.length; i++) {
        print('Record $i - ID: ${data[i].id}, Cluster Name: ${data[i].cluster_id}');
        print(data[i].tree);
        // Print a few more fields to verify data is correct
        // Only print first 3 to avoid console flood
        if (i >= 2) break;
      }

      // If you got at least one record, try to examine it in more detail
      if (data.isNotEmpty) {
        print('First record details:');
        print('ID: ${data[0].id}');
        print('Cluster Name: ${data[0].cluster_id}');
        // Add more fields as needed
      }

      setState(() {
        // Update your UI state if needed
      });
    } catch (e, stackTrace) {
      print('Error in _getNestedPlots: $e');
      print('Stack trace: $stackTrace');
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    //_getPlotSupabase();
    _getNestedPlots();
  }

  @override
  Widget build(BuildContext context) {
    return Text('sdfsdf');
  }
}
