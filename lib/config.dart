// Copy this template: `cp lib/app_config_template.dart lib/app_config.dart`
// Edit lib/app_config.dart and enter your Supabase and PowerSync project details.

class AppConfig {
  static const List<Map<String, String>> servers = [
    {
      'name': 'Local',
      'supabaseUrl': 'http://127.0.0.1:54321',
      'anonKey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
      'powersyncUrl': 'http://127.0.0.1:8181',
      'supabaseStorageBucket': 'tfm',
      'database': 'tfm-remote',
    },
    {
      'name': 'Remote',
      'supabaseUrl': 'https://ci.thuenen.de',
      'anonKey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE',
      'powersyncUrl': 'https://ci.thuenen.de/sync/',
      'supabaseStorageBucket': 'tfm',
      'database': 'tfm-local',
    },
  ];
}
