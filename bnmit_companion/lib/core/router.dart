import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bnmit_companion/providers/auth_provider.dart';
import 'package:bnmit_companion/screens/splash_screen.dart';
import 'package:bnmit_companion/screens/login_screen.dart';
import 'package:bnmit_companion/screens/dashboard_screen.dart';
import 'package:bnmit_companion/screens/attendance_screen.dart';
import 'package:bnmit_companion/screens/marks_screen.dart';
import 'package:bnmit_companion/screens/settings_screen.dart';
import 'package:bnmit_companion/screens/shell_screen.dart';
import 'package:bnmit_companion/screens/exam_history_screen.dart';
import 'package:bnmit_companion/screens/eresults_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull?.isAuthenticated ?? false;
      final isLoading = authState.isLoading;
      final isSplash = state.matchedLocation == '/splash';
      final isLogin = state.matchedLocation == '/login';

      if (isSplash) return null;
      if (isLoading) {
        return isLogin ? null : '/splash';
      }
      if (!isLoggedIn && !isLogin) return '/login';
      if (isLoggedIn && isLogin) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const DashboardScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          ),
          GoRoute(
            path: '/attendance',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const AttendanceScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          ),
          GoRoute(
            path: '/marks',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const MarksScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const SettingsScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          ),
          GoRoute(
            path: '/exam-history',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const ExamHistoryScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          ),
          GoRoute(
            path: '/eresults',
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const EResultsScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          ),
        ],
      ),
    ],
  );
});
