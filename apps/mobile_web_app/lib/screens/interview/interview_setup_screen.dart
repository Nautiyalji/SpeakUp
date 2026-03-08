import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/interview_provider.dart';
import '../../providers/auth_provider.dart';

class InterviewSetupScreen extends ConsumerStatefulWidget {
  const InterviewSetupScreen({super.key});

  @override
  ConsumerState<InterviewSetupScreen> createState() =>
      _InterviewSetupScreenState();
}

class _InterviewSetupScreenState extends ConsumerState<InterviewSetupScreen> {
  final _companyCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _jdCtrl = TextEditingController();
  int _panelistCount = 2;
  final Set<String> _selectedRounds = {'hr', 'technical'};

  final _roundOptions = const [
    {'key': 'hr', 'label': 'HR Round', 'icon': Icons.people},
    {'key': 'technical', 'label': 'Technical', 'icon': Icons.code},
    {'key': 'case_study', 'label': 'Case Study', 'icon': Icons.analytics},
  ];

  @override
  void dispose() {
    _companyCtrl.dispose();
    _roleCtrl.dispose();
    _jdCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_companyCtrl.text.trim().isEmpty || _roleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company and role are required.')),
      );
      return;
    }
    final profile = ref.read(profileProvider).value;
    if (profile == null) return;

    await ref.read(interviewProvider.notifier).setupInterview(
          userId: profile['id'],
          company: _companyCtrl.text.trim(),
          role: _roleCtrl.text.trim(),
          jdText: _jdCtrl.text.trim(),
          panelistCount: _panelistCount,
          roundTypes: _selectedRounds.toList(),
        );

    if (!mounted) return;
    final state = ref.read(interviewProvider);
    if (state.phase == InterviewPhase.panelReady) {
      context.push('/interview/panel');
    } else if (state.errorMessage != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(state.errorMessage!)));
    }
  }

  @override
  Widget build(BuildContext context) {
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
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                leading: BackButton(color: color.onSurface),
                title: Text('Mock Interview',
                    style: TextStyle(
                        color: color.onSurface, fontWeight: FontWeight.bold)),
                centerTitle: true,
              ),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Header card
                    _GlassCard(
                      child: Column(
                        children: [
                          const Text('🎯', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 8),
                          Text('Interview Setup',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: color.onSurface)),
                          const SizedBox(height: 4),
                          Text('Configure your mock interview panel',
                              style: TextStyle(
                                  color: color.onSurface.withOpacity(0.6))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Company & Role
                    _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel('Target Company & Role'),
                          const SizedBox(height: 12),
                          _Field(
                              controller: _companyCtrl,
                              label: 'Company Name',
                              hint: 'e.g. Google, Microsoft…',
                              icon: Icons.business),
                          const SizedBox(height: 12),
                          _Field(
                              controller: _roleCtrl,
                              label: 'Job Role',
                              hint: 'e.g. Software Engineer, PM…',
                              icon: Icons.work),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Round types
                    _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel('Interview Rounds'),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _roundOptions.map((opt) {
                              final key = opt['key'] as String;
                              final selected = _selectedRounds.contains(key);
                              return FilterChip(
                                label: Text(opt['label'] as String),
                                avatar: Icon(opt['icon'] as IconData,
                                    size: 16,
                                    color: selected
                                        ? Colors.white
                                        : color.primary),
                                selected: selected,
                                onSelected: (v) => setState(() {
                                  if (v) {
                                    _selectedRounds.add(key);
                                  } else if (_selectedRounds.length > 1) {
                                    _selectedRounds.remove(key);
                                  }
                                }),
                                selectedColor: color.primary,
                                labelStyle: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : color.onSurface),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Panelist count
                    _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel('Panel Size'),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [1, 2, 3].map((n) {
                              final sel = _panelistCount == n;
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _panelistCount = n),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: sel
                                          ? color.primary
                                          : color.surface.withOpacity(0.5),
                                      border: Border.all(
                                          color: sel
                                              ? color.primary
                                              : color.outline,
                                          width: 2),
                                    ),
                                    child: Center(
                                      child: Text('$n',
                                          style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: sel
                                                  ? Colors.white
                                                  : color.onSurface)),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text('panelists',
                                style: TextStyle(
                                    color: color.onSurface.withOpacity(0.5))),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // JD paste
                    _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel('Job Description (Optional)'),
                          const SizedBox(height: 4),
                          Text(
                              'Paste the JD so panelists can ask role-specific questions',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: color.onSurface.withOpacity(0.5))),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _jdCtrl,
                            maxLines: 6,
                            decoration: InputDecoration(
                              hintText: 'Paste job description here…',
                              filled: true,
                              fillColor: color.surface.withOpacity(0.3),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none),
                              hintStyle: TextStyle(
                                  color: color.onSurface.withOpacity(0.4)),
                            ),
                            style: TextStyle(color: color.onSurface),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Generate button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color.primary, color.secondary],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                                color: color.primary.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8))
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28))),
                          onPressed: state.isLoading ? null : _generate,
                          child: state.isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('Generate My Panel',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: Theme.of(context).colorScheme.primary));
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;

  const _Field(
      {required this.controller,
      required this.label,
      required this.hint,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: color.primary, size: 20),
        filled: true,
        fillColor: color.surface.withOpacity(0.3),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        labelStyle: TextStyle(color: color.onSurface.withOpacity(0.6)),
        hintStyle: TextStyle(color: color.onSurface.withOpacity(0.3)),
      ),
      style: TextStyle(color: color.onSurface),
    );
  }
}
