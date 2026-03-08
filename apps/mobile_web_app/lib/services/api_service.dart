import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';

/// Typed HTTP client that auto-injects the Supabase JWT for all requests.
class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 90), // ML ops are slow
      headers: {'Content-Type': 'application/json'},
    ));

    // Add JWT interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          options.headers['Authorization'] = 'Bearer ${session.accessToken}';
        }
        return handler.next(options);
      },
    ));
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> upsertProfile(Map<String, dynamic> body) async {
    final res = await _dio.post('/auth/profile', data: body);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProfile(String userId) async {
    final res = await _dio.get('/auth/profile/$userId');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    final res = await _dio.patch('/auth/profile/$userId', data: updates);
    return res.data as Map<String, dynamic>;
  }

  // ── Sessions ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> startSession(Map<String, dynamic> body) async {
    final res = await _dio.post('/sessions/start', data: body);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendTurn(Map<String, dynamic> body) async {
    final res = await _dio.post('/sessions/turn', data: body);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> endSession(Map<String, dynamic> body) async {
    final res = await _dio.post('/sessions/end', data: body);
    return res.data as Map<String, dynamic>;
  }

  // ── Progress ─────────────────────────────────────────────────────────────

  Future<List<dynamic>> getProgress(String userId, {int days = 7}) async {
    final res = await _dio.get('/progress/$userId?days=$days');
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> getSessionHistory(String userId, {int limit = 10}) async {
    final res = await _dio.get('/progress/history/$userId?limit=$limit');
    return res.data as List<dynamic>;
  }
  // ── Generic Helpers ────────────────────────────────────────────────────────

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final res = await _dio.get(path, queryParameters: query);
    return res.data;
  }

  Future<dynamic> post(String path, dynamic data) async {
    final res = await _dio.post(path, data: data);
    return res.data;
  }

  Future<dynamic> patch(String path, dynamic data) async {
    final res = await _dio.patch(path, data: data);
    return res.data;
  }

  Future<dynamic> put(String path, dynamic data) async {
    final res = await _dio.put(path, data: data);
    return res.data;
  }

  Future<String?> currentUserId() async {
    return Supabase.instance.client.auth.currentUser?.id;
  }
}

final apiServiceProvider = Provider((ref) => ApiService());
