import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

// ── Session State Machine ─────────────────────────────────────────────────────

enum SessionPhase { idle, starting, recording, processing, feedback, ended }

class SessionState {
  final SessionPhase phase;
  final String? sessionId;
  final String? greeting;
  final String? greetingAudio;
  final String? currentExercise;
  final List<Map<String, dynamic>> turns;
  final Map<String, dynamic>? lastTurnResult;
  final Map<String, dynamic>? finalResult;
  final String? error;
  final int turnNumber;

  const SessionState({
    this.phase = SessionPhase.idle,
    this.sessionId,
    this.greeting,
    this.greetingAudio,
    this.currentExercise,
    this.turns = const [],
    this.lastTurnResult,
    this.finalResult,
    this.error,
    this.turnNumber = 0,
  });

  SessionState copyWith({
    SessionPhase? phase,
    String? sessionId,
    String? greeting,
    String? greetingAudio,
    String? currentExercise,
    List<Map<String, dynamic>>? turns,
    Map<String, dynamic>? lastTurnResult,
    Map<String, dynamic>? finalResult,
    String? error,
    int? turnNumber,
  }) =>
      SessionState(
        phase: phase ?? this.phase,
        sessionId: sessionId ?? this.sessionId,
        greeting: greeting ?? this.greeting,
        greetingAudio: greetingAudio ?? this.greetingAudio,
        currentExercise: currentExercise ?? this.currentExercise,
        turns: turns ?? this.turns,
        lastTurnResult: lastTurnResult ?? this.lastTurnResult,
        finalResult: finalResult ?? this.finalResult,
        error: error,
        turnNumber: turnNumber ?? this.turnNumber,
      );
}

class SessionNotifier extends StateNotifier<SessionState> {
  final ApiService _api;
  final String _userId;
  final String _accent;
  final String _level;

  SessionNotifier(this._api, this._userId, this._accent, this._level)
      : super(const SessionState());

  Future<void> startSession() async {
    state = state.copyWith(phase: SessionPhase.starting);
    try {
      final result = await _api.startSession({
        'user_id': _userId,
        'target_accent': _accent,
        'level': _level,
      });
      state = state.copyWith(
        phase: SessionPhase.recording,
        sessionId: result['session_id'],
        greeting: result['greeting'],
        greetingAudio: result['greeting_audio'],
        currentExercise: result['first_exercise'],
      );
    } catch (e) {
      state = state.copyWith(phase: SessionPhase.idle, error: e.toString());
    }
  }

  void setProcessing() {
    state = state.copyWith(phase: SessionPhase.processing);
  }

  Future<void> submitTurn(String audioBase64) async {
    state = state.copyWith(phase: SessionPhase.processing);
    try {
      final result = await _api.sendTurn({
        'session_id': state.sessionId,
        'user_id': _userId,
        'audio_base64': audioBase64,
        'turn_number': state.turnNumber + 1,
      });
      final updatedTurns = [...state.turns, result];
      state = state.copyWith(
        phase: SessionPhase.feedback,
        turns: updatedTurns,
        lastTurnResult: result,
        currentExercise: result['ai_response']?['exercise'],
        turnNumber: state.turnNumber + 1,
      );
    } catch (e) {
      state = state.copyWith(phase: SessionPhase.recording, error: e.toString());
    }
  }

  Future<Map<String, dynamic>?> endSession() async {
    if (state.sessionId == null) return null;
    try {
      final result = await _api.endSession({
        'session_id': state.sessionId,
        'user_id': _userId,
      });
      state = state.copyWith(phase: SessionPhase.ended, finalResult: result);
      return result;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  void reset() {
    state = const SessionState();
  }
}

final sessionProvider = StateNotifierProvider.autoDispose<SessionNotifier, SessionState>(
  (ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final profile = ref.watch(profileProvider).valueOrNull;
    return SessionNotifier(
      ref.read(apiServiceProvider),
      user?.id ?? '',
      profile?['target_accent'] ?? 'Indian English',
      profile?['current_level'] ?? 'beginner',
    );
  },
);
