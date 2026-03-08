import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final progressDataProvider = FutureProvider.autoDispose.family<List<dynamic>, int>(
  (ref, days) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];
    return ref.read(apiServiceProvider).getProgress(user.id, days: days);
  },
);

final sessionHistoryProvider = FutureProvider.autoDispose<List<dynamic>>(
  (ref) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];
    return ref.read(apiServiceProvider).getSessionHistory(user.id);
  },
);
