import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../providers/session_provider.dart';
import '../../services/audio_service.dart';
import '../../core/constants.dart';

class SessionScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const SessionScreen({super.key, this.sessionId = ''});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> with TickerProviderStateMixin {
  final AudioService _audio = AudioService();
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.22).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_initialized) {
        _initialized = true;
        final granted = await _audio.requestMicPermission();
        if (!granted && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Microphone permission required for practice sessions.'),
          ));
          return;
        }
        await _audio.openRecorder();
        await ref.read(sessionProvider.notifier).startSession();
        // Play greeting audio when session starts
        final state = ref.read(sessionProvider);
        if (state.greetingAudio != null) {
          await _audio.playBase64Audio(state.greetingAudio!);
        }
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    final isProcessing = session.phase == SessionPhase.processing ||
        session.phase == SessionPhase.starting;
    final isRecording = _audio.isRecording;
    final canRecord = session.phase == SessionPhase.recording ||
        session.phase == SessionPhase.feedback;
    final canEnd = session.turnNumber >= 2;

    // Navigate to feedback when session ends
    ref.listen(sessionProvider, (prev, next) {
      if (next.phase == SessionPhase.ended && next.finalResult != null) {
        context.pushReplacement('/home/session/feedback', extra: next.finalResult);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Session · Turn ${session.turnNumber} / ${AppConstants.sessionTurnLimit}',
            style: const TextStyle(color: Colors.white, fontSize: 15)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textSecondary),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (canEnd)
            TextButton(
              onPressed: isProcessing ? null : () => ref.read(sessionProvider.notifier).endSession(),
              child: const Text('End Session', style: TextStyle(color: AppColors.accentBlue)),
            ),
        ],
      ),
      body: Column(
        children: [
          // AI Message Bubble
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                reverse: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Coach bubble
                    _AiBubble(
                      text: isProcessing
                          ? 'Analysing your response...'
                          : (session.phase == SessionPhase.feedback && session.lastTurnResult != null)
                              ? (session.lastTurnResult!['ai_response']?['response_text'] ?? '')
                              : (session.greeting ?? 'Starting session...'),
                      isLoading: isProcessing,
                    ),
                    // Turn feedback scores
                    if (session.phase == SessionPhase.feedback && session.lastTurnResult != null)
                      _ScoreRow(turn: session.lastTurnResult!),
                    // Next exercise prompt
                    if (session.currentExercise != null && !isProcessing)
                      _ExerciseCard(exercise: session.currentExercise!),
                  ],
                ),
              ),
            ),
          ),

          // Mic button area
          Padding(
            padding: const EdgeInsets.only(bottom: 48),
            child: Column(
              children: [
                if (session.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(session.error!, style: const TextStyle(color: AppColors.errorRed)),
                  ),
                // Pulsing mic button
                GestureDetector(
                  onTap: canRecord && !isProcessing ? _onMicTap : null,
                  child: AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, child) => Transform.scale(
                      scale: isRecording ? _pulseAnim.value : 1.0,
                      child: child,
                    ),
                    child: Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: isRecording
                              ? [AppColors.errorRed, const Color(0xFFFF6B6B)]
                              : isProcessing
                                  ? [AppColors.textSecondary, AppColors.textSecondary]
                                  : [AppColors.primaryBlue, AppColors.accentBlue],
                        ),
                        boxShadow: [BoxShadow(
                          color: (isRecording ? AppColors.errorRed : AppColors.primaryBlue).withOpacity(0.4),
                          blurRadius: 20, spreadRadius: 4,
                        )],
                      ),
                      child: isProcessing
                          ? const Center(child: SizedBox(width: 28, height: 28,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                          : Icon(isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                              color: Colors.white, size: 40),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isProcessing ? 'Processing...' : isRecording ? 'Tap to stop' : 'Tap to speak',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onMicTap() async {
    if (_audio.isRecording) {
      // Stop and submit
      final b64 = await _audio.stopRecordingAsBase64();
      if (b64 != null) {
        await ref.read(sessionProvider.notifier).submitTurn(b64);
        // Play AI response audio
        final state = ref.read(sessionProvider);
        if (state.lastTurnResult?['ai_audio_base64'] != null) {
          await _audio.playBase64Audio(state.lastTurnResult!['ai_audio_base64']);
        }
      }
    } else {
      try {
        await _audio.startRecording();
        setState(() {}); // Refresh UI to show recording state
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to start recording: ${e.toString()}'),
            backgroundColor: AppColors.errorRed,
          ));
        }
      }
    }
  }
}

// ── Subwidgets ────────────────────────────────────────────────────────────────

class _AiBubble extends StatelessWidget {
  final String text;
  final bool isLoading;
  const _AiBubble({required this.text, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40, height: 40,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primaryBlue),
          child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
            ),
            child: isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5)),
          ),
        ),
      ],
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final Map<String, dynamic> turn;
  const _ScoreRow({required this.turn});

  @override
  Widget build(BuildContext context) {
    final scores = [
      ('Grammar', turn['grammar_score'], AppColors.successGreen),
      ('Vocab', turn['vocabulary_score'], AppColors.accentBlue),
      ('Confidence', turn['confidence_score'], const Color(0xFFD97706)),
      ('Fluency', turn['fluency_score'], const Color(0xFF9333EA)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: scores.map((s) => _ScorePill(label: s.$1, score: s.$2, color: s.$3)).toList(),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final String label;
  final dynamic score;
  final Color color;
  const _ScorePill({required this.label, required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    final val = (score as num?)?.toDouble() ?? 0;
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.4))),
        child: Text('${val.toStringAsFixed(0)}%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
    ]);
  }
}

class _ExerciseCard extends StatelessWidget {
  final String exercise;
  const _ExerciseCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentBlue.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.lightbulb_outline, color: AppColors.accentBlue, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(exercise, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4))),
      ]),
    );
  }
}
