import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'providers/meals_provider.dart';
import 'screens/auth/auth_forms.dart';
import 'screens/camera/camera_screen.dart';
import 'screens/coach/coach_screen.dart';
import 'screens/cook/cook_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/detail/meal_detail_screen.dart';
import 'screens/goal_edit/goal_edit_screen.dart';
import 'screens/meals/meals_screen.dart';
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
import 'screens/settings/settings_screen.dart';
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
    // StatefulShellRoute, not ShellRoute: each tab keeps its own Navigator and
    // the four live inside an IndexedStack, so switching tabs shows a screen
    // that is still there rather than building a new one. Two things that were
    // wrong before follow from that:
    //   * the calories ring replayed its entrance animation on every return,
    //     because DashboardScreen was recreated and initState ran again;
    //   * the branch swap is instantaneous, so two headers can no longer be
    //     on screen at once mid-slide.
    // Data stays live regardless — every screen reads Riverpod providers, which
    // outlive the widgets and rebuild the visible tab when a meal is logged.
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          DashboardShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/meals',
              builder: (context, state) => const MealsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/progress',
              builder: (context, state) => const ProgressScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
    // Outside the shell: signing in replaces the account, so it must not sit
    // inside a tab whose state belongs to the old one.
    GoRoute(
      path: '/sign-in',
      builder: (context, state) => const SignInScreen(),
    ),
    GoRoute(
      path: '/goal-edit',
      builder: (context, state) => const GoalEditScreen(),
    ),
    GoRoute(
      path: '/camera',
      builder: (context, state) => const CameraScreen(),
    ),
    // Outside the shell: the coach is no longer a tab, so it is pushed over
    // the current one like the camera and the paywall. Inside the shell it
    // would paint a nav strip with no tab selected.
    GoRoute(
      path: '/coach',
      builder: (context, state) => const CoachScreen(),
    ),
    GoRoute(
      path: '/cook',
      builder: (context, state) => const CookScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    // Meal detail is addressed by slot + row id rather than by passing the
    // entry object, so the screen always reads the live row out of
    // mealsProvider and cannot render a stale copy after an edit.
    GoRoute(
      path: '/meal/:type/:id',
      builder: (context, state) {
        final type = MealType.values.firstWhere(
          (t) => t.name == state.pathParameters['type'],
          orElse: () => MealType.lunch,
        );
        return MealDetailScreen(
          mealType: type,
          entryId: state.pathParameters['id'] ?? '',
        );
      },
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
