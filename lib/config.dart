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
      'anonKey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.ewogICJyb2xlIjogImFub24iLAogICJpc3MiOiAiVEZNIiwKICAiaWF0IjogMTczOTkxOTYwMCwKICAiZXhwIjogMTg5NzY4NjAwMAp9.L28Sk6wzRLoUh1wLz_TjeY_rtUp3UX3-6UttadUEoC0',
      'powersyncUrl': 'https://ci.thuenen.de/sync/',
      'supabaseStorageBucket': 'tfm',
      'database': 'postgres',
    },
  ];
}
