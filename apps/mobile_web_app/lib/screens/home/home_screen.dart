import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/progress_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final history = ref.watch(sessionHistoryProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1a2744)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        profile.when(
                          data: (p) => Text(
                            'Hello, ${p?['full_name']?.split(' ').first ?? 'Student'}! 👋',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                          loading: () => const SizedBox(height: 28, width: 160, child: LinearProgressIndicator()),
                          error: (_, __) => const Text('Hello!', style: TextStyle(color: Colors.white, fontSize: 22)),
                        ),
                        const Text("Ready to practise?", style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                    // Streak badge
                    profile.when(
                      data: (p) => _StreakBadge(streak: p?['daily_streak'] ?? 0),
                      loading: () => const SizedBox(),
                      error: (_, __) => const SizedBox(),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Today's Score summary (from last session)
                history.when(
                  data: (sessions) => sessions.isEmpty ? const SizedBox() : _LastSessionCard(session: sessions.first),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
                const SizedBox(height: 24),

                // Primary CTA: Start Daily Session
                _CTAButton(
                  label: 'Start Daily Practice',
                  icon: Icons.mic_rounded,
                  gradient: const LinearGradient(colors: [AppColors.primaryBlue, AppColors.accentBlue]),
                  onTap: () => context.push('/home/session'),
                ),
                const SizedBox(height: 16),

                // Secondary CTA: View Progress
                _CTAButton(
                  label: 'View Progress',
                  icon: Icons.bar_chart_rounded,
                  gradient: const LinearGradient(colors: [Color(0xFF16A34A), Color(0xFF22C55E)]),
                  onTap: () => context.push('/home/progress'),
                ),
                const SizedBox(height: 32),

                // Recent Sessions
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Recent Sessions', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                  TextButton(onPressed: () => context.push('/home/progress'), child: const Text('See All', style: TextStyle(color: AppColors.accentBlue))),
                ]),
                const SizedBox(height: 12),
                history.when(
                  data: (sessions) => sessions.isEmpty
                      ? Center(child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('No sessions yet. Start your first one!', style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center)))
                      : Column(
                          children: sessions.take(3).map((s) => _SessionListItem(session: s)).toList(),
                        ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e', style: const TextStyle(color: AppColors.errorRed)),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _BottomNav(currentIndex: 0),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFD97706), Color(0xFFF59E0B)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        const Text('🔥', style: TextStyle(fontSize: 18)),
        const SizedBox(width: 4),
        Text('$streak day${streak == 1 ? '' : 's'}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class _CTAButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;
  const _CTAButton({required this.label, required this.icon, required this.gradient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: gradient.colors.first.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          const Spacer(),
          const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
        ]),
      ),
    );
  }
}

class _LastSessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  const _LastSessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final score = (session['overall_score'] as num?)?.toDouble() ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentBlue.withOpacity(0.3)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Last Session Score', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text('${score.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
        ])),
        SizedBox(width: 60, height: 60,
          child: CircularProgressIndicator(value: score / 100, strokeWidth: 6,
            color: score >= 70 ? AppColors.successGreen : AppColors.warningOrange,
            backgroundColor: AppColors.darkCard)),
      ]),
    );
  }
}

class _SessionListItem extends StatelessWidget {
  final Map<String, dynamic> session;
  const _SessionListItem({required this.session});

  @override
  Widget build(BuildContext context) {
    final score = (session['overall_score'] as num?)?.toDouble() ?? 0;
    final date = session['started_at'] != null
        ? DateTime.tryParse(session['started_at'] as String)
        : null;
    final dateStr = date != null ? '${date.day}/${date.month}/${date.year}' : 'Unknown';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.mic, color: AppColors.accentBlue)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(dateStr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          Text('${session['turns_count'] ?? 0} turns • ${session['level_at_session'] ?? ''}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ])),
        Text('${score.toStringAsFixed(0)}%',
            style: TextStyle(color: score >= 70 ? AppColors.successGreen : AppColors.warningOrange,
                fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  const _BottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      backgroundColor: AppColors.darkSurface,
      selectedItemColor: AppColors.accentBlue,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.mic_rounded), label: 'Practice'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Progress'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
      ],
      onTap: (i) {
        switch (i) {
          case 0: context.go('/home');
          case 1: context.push('/home/session');
          case 2: context.push('/home/progress');
          case 3: context.push('/home/profile');
        }
      },
    );
  }
}
