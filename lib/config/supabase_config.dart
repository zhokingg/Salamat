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

  /// Where Supabase sends people after they open a link from an auth email.
  ///
  /// Registered as a URL scheme in `ios/Runner/Info.plist` and — this half is
  /// not in the repo — allow-listed under Authentication → URL Configuration →
  /// Redirect URLs in the dashboard. GoTrue silently falls back to the Site
  /// URL for any address that is not on that list, which is how confirmation
  /// links ended up pointing at `localhost:3000`.
  ///
  /// The path is arbitrary: supabase_flutter treats ANY incoming URI carrying
  /// a `code` query parameter as the auth callback under PKCE, so this only
  /// has to be ours and stable.
  static const String authRedirect = 'kg.salamat.app://login-callback';

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
