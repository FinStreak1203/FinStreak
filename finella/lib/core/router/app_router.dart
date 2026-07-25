import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/database_providers.dart';
import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/activity/presentation/activity_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/budgets/presentation/budgets_screen.dart';
import '../../features/email_import/presentation/screens/email_import_screen.dart';
import '../../features/pdf_import/presentation/screens/pdf_import_screen.dart';
import '../../features/ai/presentation/finella_ai_screen.dart';
import '../../features/goals/presentation/goals_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/insights/presentation/insights_screen.dart';
import '../../features/more/presentation/more_screen.dart';
import '../../features/premium/presentation/premium_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/sms_import/presentation/screens/sms_import_screen.dart';
import '../../features/streak/models/reconcile_result.dart';
import '../../features/streak/presentation/screens/reconcile_screen.dart';
import '../../features/streak/presentation/screens/reconcile_success_screen.dart';
import '../../features/streak/presentation/screens/reconcile_mismatch_screen.dart';
import '../../features/streak/presentation/streak_screen.dart';
import '../../features/transactions/presentation/new_transaction_screen.dart';
import 'route_names.dart';
import 'scaffold_with_bottom_nav.dart';

// Exposed so any widget can push a full-screen route on the root navigator
// directly — bypassing GoRouter's branch-context resolution which can fail
// after all 5 tabs have been visited (all branch navigators alive at once).
final appRootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // Rebuild a fresh router per signed-in user so navigation resets to Home on
  // every login (otherwise the old router reopens wherever the last session
  // left off — e.g. Settings after a sign-out from there).
  ref.watch(currentUidProvider);

  final router = GoRouter(
    navigatorKey: appRootNavigatorKey,
    initialLocation: RouteNames.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            ScaffoldWithBottomNav(navigationShell: shell),
        // Branch order MUST match the bottom-nav tab order:
        // 0 Home · 1 Txns(Activity) · 2 FIN AI · 3 Insights · 4 More
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: RouteNames.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RouteNames.activity,
              builder: (context, state) => const ActivityScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RouteNames.ai,
              builder: (context, state) => const FinellaAiScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RouteNames.insights,
              builder: (context, state) => const InsightsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RouteNames.more,
              builder: (context, state) => const MoreScreen(),
            ),
          ]),
        ],
      ),
      // Goals lost its own tab — now reachable from the "More" hub as a
      // full-screen route on the root navigator.
      GoRoute(
        parentNavigatorKey: appRootNavigatorKey,
        path: RouteNames.goals,
        builder: (context, state) => const GoalsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: appRootNavigatorKey,
        path: RouteNames.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: appRootNavigatorKey,
        path: RouteNames.accounts,
        builder: (context, state) => const AccountsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: appRootNavigatorKey,
        path: RouteNames.budgets,
        builder: (context, state) => const BudgetsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: appRootNavigatorKey,
        path: RouteNames.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        parentNavigatorKey: appRootNavigatorKey,
        path: RouteNames.emailImport,
        builder: (context, state) => const EmailImportScreen(),
      ),
      GoRoute(
        parentNavigatorKey: appRootNavigatorKey,
        path: RouteNames.smsImport,
        builder: (context, state) => const SmsImportScreen(),
      ),
      GoRoute(
        parentNavigatorKey: appRootNavigatorKey,
        path: RouteNames.pdfImport,
        builder: (context, state) => const PdfImportScreen(),
      ),
      GoRoute(
        parentNavigatorKey: appRootNavigatorKey,
        path: RouteNames.premium,
        pageBuilder: (context, state) => const MaterialPage(
          fullscreenDialog: true,
          child: PremiumScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: appRootNavigatorKey,
        path: RouteNames.newTransaction,
        builder: (context, state) => const NewTransactionScreen(),
      ),
      GoRoute(
        parentNavigatorKey: appRootNavigatorKey,
        path: RouteNames.streak,
        builder: (context, state) => const StreakScreen(),
      ),
      GoRoute(
        parentNavigatorKey: appRootNavigatorKey,
        path: RouteNames.reconcile,
        builder: (context, state) => const ReconcileScreen(),
      ),
      GoRoute(
        parentNavigatorKey: appRootNavigatorKey,
        path: RouteNames.reconcileSuccess,
        builder: (context, state) =>
            ReconcileSuccessScreen(result: state.extra as ReconcileResult),
      ),
      GoRoute(
        parentNavigatorKey: appRootNavigatorKey,
        path: RouteNames.reconcileMismatch,
        builder: (context, state) =>
            ReconcileMismatchScreen(result: state.extra as ReconcileResult),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
