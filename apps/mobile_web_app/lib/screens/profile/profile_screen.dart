import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  String? _accent;
  String? _level;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider).valueOrNull;
    if (profile != null) {
      _nameCtrl.text = profile['full_name'] ?? '';
      _accent = profile['target_accent'] ?? AppConstants.accents[0];
      _level = profile['current_level'] ?? AppConstants.levels[0];
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: const BackButton(color: Colors.white),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Sign Out', style: TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e', style: const TextStyle(color: AppColors.errorRed)),
          data: (p) {
            // Initialise fields on first load
            if (_accent == null) {
              _accent = p?['target_accent'] ?? AppConstants.accents[0];
              _level = p?['current_level'] ?? AppConstants.levels[0];
              _nameCtrl.text = p?['full_name'] ?? '';
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Center(child: Column(children: [
                  Container(
                    width: 80, height: 80,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [AppColors.primaryBlue, AppColors.accentBlue])),
                    child: Center(child: Text(
                      (_nameCtrl.text.isNotEmpty ? _nameCtrl.text[0] : 'S').toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    )),
                  ),
                  const SizedBox(height: 12),
                  Text(user?.email ?? '', style: const TextStyle(color: AppColors.textSecondary)),
                ])),
                const SizedBox(height: 32),

                // Stats
                Row(children: [
                  _StatBox(label: 'Streak', value: '${p?['daily_streak'] ?? 0}🔥'),
                  const SizedBox(width: 12),
                  _StatBox(label: 'Total Sessions', value: '${p?['total_sessions'] ?? 0}'),
                ]),
                const SizedBox(height: 28),

                // Settings
                const Text('Settings', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outlined, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _accent,
                  dropdownColor: AppColors.darkCard,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Target Accent'),
                  items: AppConstants.accents.map((a) => DropdownMenuItem(value: a,
                      child: Text(a, style: const TextStyle(color: Colors.white)))).toList(),
                  onChanged: (v) => setState(() => _accent = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _level,
                  dropdownColor: AppColors.darkCard,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Your Level'),
                  items: AppConstants.levels.map((l) => DropdownMenuItem(value: l,
                      child: Text(l, style: const TextStyle(color: Colors.white)))).toList(),
                  onChanged: (v) => setState(() => _level = v),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Changes'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      await ref.read(apiServiceProvider).updateProfile(userId, {
        'full_name': _nameCtrl.text.trim(),
        'target_accent': _accent,
        'level': _level,
      });
      ref.invalidate(profileProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated!'), backgroundColor: AppColors.successGreen),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ]),
    ));
  }
}
