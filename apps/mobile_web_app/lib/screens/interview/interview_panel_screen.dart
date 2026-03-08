import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/interview_provider.dart';

class InterviewPanelScreen extends ConsumerWidget {
  const InterviewPanelScreen({super.key});

  static const _archetypeColors = {
    'hr_generalist': Color(0xFF4CAF50),
    'technical_lead': Color(0xFF2196F3),
    'senior_engineer': Color(0xFF9C27B0),
    'culture_fit': Color(0xFFFF9800),
    'director': Color(0xFFE91E63),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(interviewProvider);
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.surface, const Color(0xFF0F0F23)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                        icon: Icon(Icons.arrow_back, color: color.onSurface),
                        onPressed: () => context.pop()),
                    Expanded(
                      child: Text('Your Interview Panel',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: color.onSurface)),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Company + role header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: color.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Text('🏢', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(state.company,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: color.onSurface)),
                            Text(state.role,
                                style: TextStyle(
                                    color: color.primary, fontSize: 13)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                            '${state.roundTypes.length} Rounds',
                            style: TextStyle(
                                color: color.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Panelist list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: state.panel.length,
                  itemBuilder: (ctx, i) {
                    final p = state.panel[i];
                    final accentColor = _archetypeColors[p.archetype] ??
                        color.primary;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: accentColor.withOpacity(0.3),
                              width: 1.5),
                        ),
                        child: Row(
                          children: [
                            // Avatar
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    accentColor,
                                    accentColor.withOpacity(0.6)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Center(
                                child: Text(p.emoji,
                                    style: const TextStyle(fontSize: 26)),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: color.onSurface)),
                                  Text(p.title,
                                      style: TextStyle(
                                          color: accentColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(p.personality,
                                      style: TextStyle(
                                          color: color.onSurface
                                              .withOpacity(0.5),
                                          fontSize: 12)),
                                  if (p.funFact.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: accentColor.withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(p.funFact,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: accentColor
                                                  .withOpacity(0.8))),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: accentColor),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Round info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: state.roundTypes.asMap().entries.map((e) {
                        final labels = {
                          'hr': '🤝 HR',
                          'technical': '💻 Tech',
                          'case_study': '📊 Case'
                        };
                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          child: Chip(
                            label: Text(
                                labels[e.value] ?? e.value.toUpperCase(),
                                style: const TextStyle(fontSize: 11)),
                            backgroundColor:
                                color.primary.withOpacity(0.15),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Begin button
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [color.primary, color.secondary]),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                            color: color.primary.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8))
                      ],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28))),
                      onPressed: () {
                        ref
                            .read(interviewProvider.notifier)
                            .startRound(1);
                        context.push('/interview/session');
                      },
                      icon: const Icon(Icons.play_arrow, color: Colors.white),
                      label: const Text('Begin Round 1',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
