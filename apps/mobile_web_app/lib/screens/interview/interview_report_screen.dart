import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../providers/interview_provider.dart';

class InterviewReportScreen extends ConsumerWidget {
  const InterviewReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(interviewProvider);
    final report = state.report;
    final color = Theme.of(context).colorScheme;

    if (report == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final competency = report['competency_scores'] ?? {};
    final summaries = report['panelist_summaries'] as List? ?? [];

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.darkSurface,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Interview Report', style: TextStyle(fontWeight: FontWeight.bold)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryBlue, AppColors.darkBg],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Overall Score', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      Text('${report['overall_score']}%', 
                           style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.go('/home'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Recommendation Box
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.assignment_ind, color: AppColors.accentBlue),
                          const SizedBox(width: 8),
                          const Text('Recommendation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const Spacer(),
                          _Tag(
                            label: report['recommendation'] ?? 'Maybe',
                            color: _getRecColor(report['recommendation']),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(report['recommendation_reason'] ?? '', 
                           style: const TextStyle(color: Colors.white70, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Competency Scores
                const Text('Competency Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                const SizedBox(height: 12),
                _CompetencyGrid(scores: competency),
                const SizedBox(height: 24),

                // Strengths & Gaps
                Row(
                  children: [
                    Expanded(child: _ListCard(title: 'Strengths', items: report['strengths'], icon: Icons.check_circle, color: AppColors.successGreen)),
                    const SizedBox(width: 12),
                    Expanded(child: _ListCard(title: 'Gaps', items: report['gaps'], icon: Icons.warning, color: AppColors.warningOrange)),
                  ],
                ),
                const SizedBox(height: 24),

                // Panelist Feedback
                const Text('Panelist Feedback', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                const SizedBox(height: 12),
                ...summaries.map((s) => _PanelistSummaryCard(summary: s)).toList(),
                const SizedBox(height: 40),

                ElevatedButton(
                  onPressed: () {
                    ref.read(interviewProvider.notifier).reset();
                    context.go('/home');
                  },
                  child: const Text('Back to Dashboard'),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRecColor(String? rec) {
    if (rec?.contains('Yes') ?? false) return AppColors.successGreen;
    if (rec?.contains('No') ?? false) return AppColors.errorRed;
    return AppColors.warningOrange;
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: child,
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

class _CompetencyGrid extends StatelessWidget {
  final Map<String, dynamic> scores;
  const _CompetencyGrid({required this.scores});
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: scores.entries.map((e) {
        return _Card(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(e.key.toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text('${e.value}%', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ListCard extends StatelessWidget {
  final String title;
  final dynamic items;
  final IconData icon;
  final Color color;
  const _ListCard({required this.title, required this.items, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    final list = items as List? ?? [];
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 16), const SizedBox(width: 6), Text(title, style: const TextStyle(fontWeight: FontWeight.bold))]),
          const SizedBox(height: 12),
          ...list.take(3).map((it) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('• $it', style: const TextStyle(color: Colors.white60, fontSize: 12)),
          )),
        ],
      ),
    );
  }
}

class _PanelistSummaryCard extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _PanelistSummaryCard({required this.summary});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _Card(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(summary['panelist_name'] ?? 'Interviewer', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(summary['note'] ?? '', style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accentBlue.withOpacity(0.1)),
              child: Center(child: Text('${summary['score']}%', style: const TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold, fontSize: 12))),
            ),
          ],
        ),
      ),
    );
  }
}
