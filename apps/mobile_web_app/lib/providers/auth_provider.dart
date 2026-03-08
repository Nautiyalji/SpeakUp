import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';



// ── Auth State ────────────────────────────────────────────────────────────────

class AuthNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    return Supabase.instance.client.auth.currentUser;
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String accent,
    required String level,
  }) async {
    state = const AsyncLoading();
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );
      final user = res.user;
      if (user != null) {
        // Create backend profile
        await ref.read(apiServiceProvider).upsertProfile({
          'user_id': user.id,
          'full_name': fullName,
          'target_accent': accent,
          'level': level,
        });
      }
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      state = AsyncData(res.user);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    state = const AsyncData(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(() => AuthNotifier());

// ── Profile ───────────────────────────────────────────────────────────────────

final profileProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null) return null;
  return ref.read(apiServiceProvider).getProfile(user.id);
});
