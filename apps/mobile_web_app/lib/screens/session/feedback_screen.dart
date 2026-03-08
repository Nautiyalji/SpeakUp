import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

class FeedbackScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  const FeedbackScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final scores = data['final_scores'] as Map<String, dynamic>? ?? {};
    final feedback = data['feedback'] as Map<String, dynamic>? ?? {};

    final overall = (scores['overall'] as num?)?.toDouble() ?? 0;
    final headline = feedback['headline'] as String? ?? 'Great session!';
    final strengths = List<String>.from(feedback['strengths'] ?? []);
    final improvements = List<String>.from(feedback['improvements'] ?? []);
    final exercises = List<String>.from(feedback['daily_exercises'] ?? []);
    final motivation = feedback['motivational_message'] as String? ?? '';
    final nextFocus = feedback['next_session_focus'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Session Complete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall Score Ring
            Center(child: Column(children: [
              SizedBox(
                width: 130, height: 130,
                child: Stack(alignment: Alignment.center, children: [
                  CircularProgressIndicator(
                    value: overall / 100, strokeWidth: 10,
                    color: overall >= 70 ? AppColors.successGreen : AppColors.warningOrange,
                    backgroundColor: AppColors.darkCard,
                  ),
                  Text('${overall.toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                ]),
              ),
              const SizedBox(height: 16),
              Text(headline, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              if (motivation.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 8),
                    child: Text(motivation, textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary, height: 1.4))),
            ])),
            const SizedBox(height: 32),

            // Score breakdown
            _SectionTitle('Your Scores'),
            const SizedBox(height: 12),
            _ScoreGrid(scores: scores),
            const SizedBox(height: 24),

            // Strengths
            if (strengths.isNotEmpty) ...[
              _SectionTitle('✅ Strengths'),
              const SizedBox(height: 10),
              ...strengths.map((s) => _ListItem(s, color: AppColors.successGreen)),
              const SizedBox(height: 20),
            ],

            // Improvements
            if (improvements.isNotEmpty) ...[
              _SectionTitle('💡 Areas to Improve'),
              const SizedBox(height: 10),
              ...improvements.map((s) => _ListItem(s, color: AppColors.warningOrange)),
              const SizedBox(height: 20),
            ],

            // Daily exercises
            if (exercises.isNotEmpty) ...[
              _SectionTitle('🏋️ Daily Exercises'),
              const SizedBox(height: 10),
              ...exercises.asMap().entries.map((e) => _ListItem('${e.key + 1}. ${e.value}', color: AppColors.accentBlue)),
              const SizedBox(height: 20),
            ],

            // Next focus
            if (nextFocus.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryBlue.withOpacity(0.4)),
                ),
                child: Row(children: [
                  const Icon(Icons.flag_rounded, color: AppColors.primaryBlue),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Next Session Focus', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    Text(nextFocus, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ])),
                ]),
              ),
            const SizedBox(height: 32),

            // Done button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.home_rounded),
                label: const Text('Back to Home'),
                onPressed: () => context.go('/home'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Text(title,
      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold));
}

class _ListItem extends StatelessWidget {
  final String text;
  final Color color;
  const _ListItem(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 7, right: 10),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white, height: 1.4))),
      ]),
    );
  }
}

class _ScoreGrid extends StatelessWidget {
  final Map<String, dynamic> scores;
  const _ScoreGrid({required this.scores});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Grammar', scores['grammar'], AppColors.successGreen),
      ('Vocabulary', scores['vocabulary'], AppColors.accentBlue),
      ('Confidence', scores['confidence'], const Color(0xFFD97706)),
      ('Fluency', scores['fluency'], const Color(0xFF9333EA)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.8,
      children: items.map((item) {
        final val = (item.$2 as num?)?.toDouble() ?? 0;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: item.$3.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: item.$3.withOpacity(0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${val.toStringAsFixed(0)}%', style: TextStyle(color: item.$3, fontSize: 24, fontWeight: FontWeight.w800)),
            Text(item.$1, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ]),
        );
      }).toList(),
    );
  }
}
