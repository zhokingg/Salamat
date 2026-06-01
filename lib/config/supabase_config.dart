/// Supabase connection config.
///
/// Anon key is safe on-device — it's public by design; RLS protects data.
/// Embedded defaults below; override per-build with `--dart-define=SUPABASE_URL=...`
/// and `--dart-define=SUPABASE_ANON_KEY=...` if you need to point at a different project.
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://cpqidxmqydleadbinaon.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNwcWlkeG1xeWRsZWFkYmluYW9uIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk0NDIxNTYsImV4cCI6MjA5NTAxODE1Nn0.na441ItylVOyl_hjgKdlbxsGPqRQ-hD_ELdVEWjQuzU',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
