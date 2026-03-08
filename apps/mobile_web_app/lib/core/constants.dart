/// App-wide constants — API URLs, string keys, UI tokens.
class AppConstants {
  AppConstants._();

  // ── API ──────────────────────────────────────────────────────────────────
  // Swap with your Render.com backend URL in production
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://10.90.236.180:8000', // Local IP for mobile access
  );

  // ── Supabase ─────────────────────────────────────────────────────────────
  // Set these via dart-define or in supabase_config.dart directly
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://uyxhdambiishtarklsei.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV5eGhkYW1iaWlzaHRhcmtsc2VpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2NDIzNjAsImV4cCI6MjA4ODIxODM2MH0.i6sZx8dA2WDXgT2DJoY27T7ORK25WkIAYusWB2JOtYI',
  );

  // ── SharedPreferences Keys ────────────────────────────────────────────────
  static const String keyThemeMode = 'theme_mode';         // 'dark' | 'light'
  static const String keyTargetAccent = 'target_accent';
  static const String keyUserLevel = 'user_level';

  // ── Session Config ────────────────────────────────────────────────────────
  static const int sessionTurnLimit = 5;          // Max turns per daily session
  static const int minAudioDurationMs = 1500;     // Min recording length (1.5s)

  // ── String Labels ─────────────────────────────────────────────────────────
  static const List<String> accents = ['Indian English', 'British English'];
  static const List<String> levels = ['beginner', 'intermediate', 'advanced'];
}
