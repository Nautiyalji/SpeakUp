import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';

/// Initialize Supabase once at app startup.
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
}

/// Quick accessor — use anywhere in the app without context.
SupabaseClient get supabase => Supabase.instance.client;
