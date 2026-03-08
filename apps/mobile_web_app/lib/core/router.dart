import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/profile/profile_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/session/session_screen.dart';
import '../screens/session/feedback_screen.dart';
import '../screens/progress/progress_screen.dart';
import '../screens/interview/interview_setup_screen.dart';
import '../screens/interview/interview_panel_screen.dart';
import '../screens/interview/interview_session_screen.dart';
import '../screens/interview/interview_report_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      // ── Auth ─────────────────────────────────────────────────────────────
      GoRoute(path: '/login', builder: (ctx, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (ctx, _) => const SignupScreen()),

      // ── Main Shell ───────────────────────────────────────────────────────
      GoRoute(
        path: '/home',
        builder: (ctx, _) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'session',
            builder: (ctx, state) {
              final sessionId = state.uri.queryParameters['sessionId'] ?? '';
              return SessionScreen(sessionId: sessionId);
            },
            routes: [
              GoRoute(
                path: 'feedback',
                builder: (ctx, state) {
                  final extra = state.extra as Map<String, dynamic>? ?? {};
                  return FeedbackScreen(data: extra);
                },
              ),
            ],
          ),
          GoRoute(path: 'progress', builder: (ctx, _) => const ProgressScreen()),
          GoRoute(path: 'profile', builder: (ctx, _) => const ProfileScreen()),
        ],
      ),

      // ── Interview ────────────────────────────────────────────────────────
      GoRoute(
        path: '/interview',
        builder: (ctx, _) => const InterviewSetupScreen(),
        routes: [
          GoRoute(path: 'panel', builder: (ctx, _) => const InterviewPanelScreen()),
          GoRoute(path: 'session', builder: (ctx, _) => const InterviewSessionScreen()),
          GoRoute(path: 'report', builder: (ctx, _) => const InterviewReportScreen()),
        ],
      ),
    ],
  );
});
