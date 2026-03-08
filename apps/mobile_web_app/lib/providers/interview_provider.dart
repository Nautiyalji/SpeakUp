import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

// ── State ─────────────────────────────────────────────────────────────────────

enum InterviewPhase {
  idle,
  setup,
  panelReady,
  roundActive,
  roundEnded,
  completed,
}

class PanelistConfig {
  final String id;
  final String name;
  final String archetype;
  final String title;
  final String emoji;
  final String personality;
  final String funFact;

  PanelistConfig.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        name = j['name'] ?? '',
        archetype = j['archetype'] ?? '',
        title = j['title'] ?? '',
        emoji = j['emoji'] ?? '🤝',
        personality = j['personality'] ?? '',
        funFact = j['fun_fact'] ?? '';
}

class InterviewState {
  final InterviewPhase phase;
  final String? interviewId;
  final String company;
  final String role;
  final List<PanelistConfig> panel;
  final List<String> roundTypes;
  final int currentRound;
  final int currentQuestion;
  final PanelistConfig? activePanelist;
  final String currentQuestion_text;
  final String? currentQuestion_audio;
  final String? lastTranscript;
  final Map<String, dynamic>? lastEvaluation;
  final Map<String, dynamic>? report;
  final String? errorMessage;
  final bool isLoading;

  const InterviewState({
    this.phase = InterviewPhase.idle,
    this.interviewId,
    this.company = '',
    this.role = '',
    this.panel = const [],
    this.roundTypes = const ['hr', 'technical'],
    this.currentRound = 1,
    this.currentQuestion = 1,
    this.activePanelist,
    this.currentQuestion_text = '',
    this.currentQuestion_audio,
    this.lastTranscript,
    this.lastEvaluation,
    this.report,
    this.errorMessage,
    this.isLoading = false,
  });

  InterviewState copyWith({
    InterviewPhase? phase,
    String? interviewId,
    String? company,
    String? role,
    List<PanelistConfig>? panel,
    List<String>? roundTypes,
    int? currentRound,
    int? currentQuestion,
    PanelistConfig? activePanelist,
    String? currentQuestion_text,
    String? currentQuestion_audio,
    String? lastTranscript,
    Map<String, dynamic>? lastEvaluation,
    Map<String, dynamic>? report,
    String? errorMessage,
    bool? isLoading,
  }) {
    return InterviewState(
      phase: phase ?? this.phase,
      interviewId: interviewId ?? this.interviewId,
      company: company ?? this.company,
      role: role ?? this.role,
      panel: panel ?? this.panel,
      roundTypes: roundTypes ?? this.roundTypes,
      currentRound: currentRound ?? this.currentRound,
      currentQuestion: currentQuestion ?? this.currentQuestion,
      activePanelist: activePanelist ?? this.activePanelist,
      currentQuestion_text: currentQuestion_text ?? this.currentQuestion_text,
      currentQuestion_audio: currentQuestion_audio ?? this.currentQuestion_audio,
      lastTranscript: lastTranscript ?? this.lastTranscript,
      lastEvaluation: lastEvaluation ?? this.lastEvaluation,
      report: report ?? this.report,
      errorMessage: errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────────

class InterviewNotifier extends StateNotifier<InterviewState> {
  final ApiService _api;
  InterviewNotifier(this._api) : super(const InterviewState());

  Future<void> setupInterview({
    required String userId,
    required String company,
    required String role,
    required String jdText,
    required int panelistCount,
    required List<String> roundTypes,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _api.post('/interview/setup', {
        'user_id': userId,
        'company': company,
        'role': role,
        'jd_text': jdText,
        'panelist_count': panelistCount,
        'round_types': roundTypes,
      });
      final panelists = (res['panel'] as List)
          .map((p) => PanelistConfig.fromJson(p))
          .toList();
      state = state.copyWith(
        phase: InterviewPhase.panelReady,
        interviewId: res['interview_id'],
        company: company,
        role: role,
        panel: panelists,
        roundTypes: List<String>.from(res['round_types']),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> startRound(int roundNumber) async {
    state = state.copyWith(isLoading: true, currentRound: roundNumber);
    try {
      final res = await _api.post('/interview/start', {
        'interview_id': state.interviewId,
        'round_number': roundNumber,
      });
      final panelist = PanelistConfig.fromJson(res['active_panelist']);
      state = state.copyWith(
        phase: InterviewPhase.roundActive,
        currentRound: roundNumber,
        currentQuestion: 1,
        activePanelist: panelist,
        currentQuestion_text: res['opening_question'],
        currentQuestion_audio: res['opening_audio_base64'],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<Map<String, dynamic>?> submitTurn(String audioBase64) async {
    if (state.interviewId == null || state.activePanelist == null) return null;
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.post('/interview/turn', {
        'interview_id': state.interviewId,
        'round_number': state.currentRound,
        'question_number': state.currentQuestion,
        'panelist_id': state.activePanelist!.id,
        'audio_base64': audioBase64,
      });
      final roundComplete = res['round_complete'] as bool? ?? false;
      state = state.copyWith(
        currentQuestion: state.currentQuestion + 1,
        currentQuestion_text: res['next_question'] ?? '',
        currentQuestion_audio: res['next_audio_base64'],
        lastTranscript: res['transcript'],
        lastEvaluation: res['panelist_evaluation'],
        phase: roundComplete ? InterviewPhase.roundEnded : InterviewPhase.roundActive,
        isLoading: false,
      );
      return res;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  Future<void> endInterview() async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.post('/interview/end', {
        'interview_id': state.interviewId,
        'user_id': await _api.currentUserId(),
      });
      state = state.copyWith(
        phase: InterviewPhase.completed,
        report: res,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void reset() => state = const InterviewState();
}

// ── Providers ──────────────────────────────────────────────────────────────────

final interviewProvider =
    StateNotifierProvider<InterviewNotifier, InterviewState>((ref) {
  return InterviewNotifier(ref.watch(apiServiceProvider));
});
