import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../providers/interview_provider.dart';
import '../../services/audio_service.dart';

class InterviewSessionScreen extends ConsumerStatefulWidget {
  const InterviewSessionScreen({super.key});

  @override
  ConsumerState<InterviewSessionScreen> createState() => _InterviewSessionScreenState();
}

class _InterviewSessionScreenState extends ConsumerState<InterviewSessionScreen> with TickerProviderStateMixin {
  final AudioService _audio = AudioService();
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_initialized) {
        _initialized = true;
        final granted = await _audio.requestMicPermission();
        if (!granted && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Microphone permission required for interviews.'),
          ));
          return;
        }
        await _audio.openRecorder();
        final state = ref.read(interviewProvider);
        if (state.currentQuestion_audio != null) {
          await _audio.playBase64Audio(state.currentQuestion_audio!);
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

  Future<void> _onMicTap() async {
    final state = ref.read(interviewProvider);
    if (_audio.isRecording) {
      final b64 = await _audio.stopRecordingAsBase64();
      if (b64 != null) {
        final res = await ref.read(interviewProvider.notifier).submitTurn(b64);
        if (res != null && res['next_audio_base64'] != null) {
          await _audio.playBase64Audio(res['next_audio_base64']);
        }
      }
    } else {
      await _audio.startRecording();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(interviewProvider);
    final isRecording = _audio.isRecording;
    final isProcessing = state.isLoading;
    final panelist = state.activePanelist;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Round ${state.currentRound} · Q${state.currentQuestion}',
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // Active Panelist Info
          if (panelist != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [AppColors.primaryBlue, AppColors.accentBlue]),
                    ),
                    child: Center(child: Text(panelist.emoji, style: const TextStyle(fontSize: 30))),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(panelist.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        Text(panelist.title, style: const TextStyle(color: AppColors.accentBlue, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    // Question text
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.darkSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Text(
                        state.currentQuestion_text,
                        style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.5, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Last transcript (if any)
                    if (state.lastTranscript != null)
                      Opacity(
                        opacity: 0.7,
                        child: Text('Your Answer: ${state.lastTranscript}',
                            style: const TextStyle(color: AppColors.textOnDark, fontSize: 14, fontStyle: FontStyle.italic)),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom interaction area
          Padding(
            padding: const EdgeInsets.only(bottom: 60),
            child: Column(
              children: [
                if (state.phase == InterviewPhase.roundEnded)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: ElevatedButton(
                      onPressed: () {
                        if (state.currentRound < state.roundTypes.length) {
                          ref.read(interviewProvider.notifier).startRound(state.currentRound + 1);
                        } else {
                          ref.read(interviewProvider.notifier).endInterview();
                          context.pushReplacement('/interview/report');
                        }
                      },
                      child: Text(state.currentRound < state.roundTypes.length ? 'Next Round' : 'Finish Interview'),
                    ),
                  )
                else
                  Column(
                    children: [
                      GestureDetector(
                        onTap: isProcessing ? null : _onMicTap,
                        child: AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (_, child) => Transform.scale(
                            scale: isRecording ? _pulseAnim.value : 1.0,
                            child: child,
                          ),
                          child: Container(
                            width: 80, height: 80,
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
                                color: (isRecording ? AppColors.errorRed : AppColors.primaryBlue).withOpacity(0.3),
                                blurRadius: 15, spreadRadius: 2,
                              )],
                            ),
                            child: isProcessing
                                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                                : Icon(isRecording ? Icons.stop : Icons.mic, color: Colors.white, size: 36),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isProcessing ? 'Processing...' : isRecording ? 'Tap to stop' : 'Tap to answer',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
