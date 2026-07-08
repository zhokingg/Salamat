import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/camera/camera_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/onboarding/activity_screen.dart';
import 'screens/onboarding/building_screen.dart';
import 'screens/onboarding/celebration_screen.dart';
import 'screens/onboarding/comparison_screen.dart';
import 'screens/onboarding/familiarity_screen.dart';
import 'screens/onboarding/gender_screen.dart';
import 'screens/onboarding/goal_screen.dart';
import 'screens/onboarding/long_term_screen.dart';
import 'screens/onboarding/name_screen.dart';
import 'screens/onboarding/plan_ready_screen.dart';
import 'screens/onboarding/social_proof_screen.dart';
import 'screens/onboarding/summary_screen.dart';
import 'screens/onboarding/target_screen.dart';
import 'screens/onboarding/weight_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/onboarding/year_screen.dart';
import 'screens/onboarding/yes_question_screen.dart';
import 'screens/paywall/paywall_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/progress/progress_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'widgets/dashboard_shell.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    // ---- Onboarding (S1 → S16) ----
    GoRoute(
      path: '/onboarding/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/onboarding/name',
      builder: (context, state) => const NameScreen(),
    ),
    GoRoute(
      path: '/onboarding/goal',
      builder: (context, state) => const GoalScreen(),
    ),
    GoRoute(
      path: '/onboarding/gender',
      builder: (context, state) => const GenderScreen(),
    ),
    GoRoute(
      path: '/onboarding/year',
      builder: (context, state) => const YearScreen(),
    ),
    GoRoute(
      path: '/onboarding/weight',
      builder: (context, state) => const WeightScreen(),
    ),
    GoRoute(
      path: '/onboarding/target',
      builder: (context, state) => const TargetWeightScreen(),
    ),
    GoRoute(
      path: '/onboarding/celebration',
      builder: (context, state) => const CelebrationScreen(),
    ),
    GoRoute(
      path: '/onboarding/long-term',
      builder: (context, state) => const LongTermScreen(),
    ),
    GoRoute(
      path: '/onboarding/familiarity',
      builder: (context, state) => const FamiliarityScreen(),
    ),
    GoRoute(
      path: '/onboarding/activity',
      builder: (context, state) => const ActivityScreen(),
    ),
    GoRoute(
      path: '/onboarding/summary',
      builder: (context, state) => const SummaryScreen(),
    ),
    GoRoute(
      path: '/onboarding/yes/lose',
      builder: (context, state) =>
          const YesQuestionScreen(question: YesQuestion.lose),
    ),
    GoRoute(
      path: '/onboarding/yes/order',
      builder: (context, state) =>
          const YesQuestionScreen(question: YesQuestion.order),
    ),
    GoRoute(
      path: '/onboarding/yes/health',
      builder: (context, state) =>
          const YesQuestionScreen(question: YesQuestion.health),
    ),
    GoRoute(
      path: '/onboarding/comparison',
      builder: (context, state) => const ComparisonScreen(),
    ),
    GoRoute(
      path: '/onboarding/social-proof',
      builder: (context, state) => const SocialProofScreen(),
    ),
    GoRoute(
      path: '/onboarding/building',
      builder: (context, state) => const BuildingScreen(),
    ),
    GoRoute(
      path: '/onboarding/plan',
      builder: (context, state) => const PlanReadyScreen(),
    ),
    // ---- Main app ----
    ShellRoute(
      builder: (context, state, child) => DashboardShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/progress',
          builder: (context, state) => const ProgressScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/camera',
      builder: (context, state) => const CameraScreen(),
    ),
    GoRoute(
      path: '/paywall',
      builder: (context, state) => const PaywallScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('Route not found: ${state.uri}')),
  ),
);
