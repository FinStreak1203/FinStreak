import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/providers/onboarding_provider.dart';
import 'core/providers/subscription_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/services/sms_realtime_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/signup_screen.dart';
import 'features/auth/viewmodel/auth_view_model.dart';
import 'features/onboarding/presentation/onboarding_welcome_screen.dart';
import 'features/onboarding/presentation/onboarding_currency_screen.dart';
import 'features/onboarding/presentation/onboarding_create_pin_screen.dart';
import 'features/onboarding/presentation/onboarding_confirm_pin_screen.dart';
import 'features/onboarding/presentation/onboarding_add_account_screen.dart';
import 'firebase_options.dart';

// OAuth *web* client id (client_type 3 in google-services.json) — required so
// Google Sign-In returns an id token Firebase can consume on Android.
const _googleServerClientId =
    '503765405760-sckgpslkpeh6egqso83q5u7u2i77l4he.apps.googleusercontent.com';

// Signed-out router — Login ↔ Sign-up only, never the main app.
final _authRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
  ],
);

// Onboarding-only router — never shows the main bottom nav
final _onboardingRouter = GoRouter(
  initialLocation: '/welcome',
  routes: [
    GoRoute(
      path: '/welcome',
      builder: (_, _) => const OnboardingWelcomeScreen(),
    ),
    GoRoute(
      path: '/currency',
      builder: (_, _) => const OnboardingCurrencyScreen(),
    ),
    GoRoute(
      path: '/create-pin',
      builder: (_, _) => const OnboardingCreatePinScreen(),
    ),
    GoRoute(
      path: '/confirm-pin',
      builder: (_, s) =>
          OnboardingConfirmPinScreen(pin: s.extra as String),
    ),
    GoRoute(
      path: '/add-account',
      builder: (_, _) => const OnboardingAddAccountScreen(),
    ),
  ],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('══ FLUTTER ERROR ══════════════════════════════════════');
    debugPrint('Exception: ${details.exception}');
    debugPrint('Stack:\n${details.stack}');
    debugPrint('═══════════════════════════════════════════════════════');
    FlutterError.presentError(details);
  };

  // Load the Gemini API key (and any other secrets) from the bundled .env.
  // Wrapped so a missing/unbundled .env never blocks app startup — Gemini
  // calls simply fall back to their non-AI defaults if the key is absent.
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('dotenv load failed (AI features disabled): $e');
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await GoogleSignIn.instance.initialize(
    serverClientId: _googleServerClientId,
  );

  // Local notifications for the daily reconcile reminder. Scheduling happens
  // later (Home/after reconcile) once we know if today is already reconciled.
  await NotificationService.instance.init();
  await NotificationService.instance.requestPermissions();

  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const FinellaApp(),
    ),
  );
}

class FinellaApp extends ConsumerWidget {
  const FinellaApp({super.key});

  // Brief splash while a provider resolves.
  Widget _splash() => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
          ),
        ),
      );

  MaterialApp _authApp() => MaterialApp.router(
        title: 'Finella',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        routerConfig: _authRouter,
      );

  MaterialApp _onboardingApp() => MaterialApp.router(
        title: 'Finella',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        routerConfig: _onboardingRouter,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final onboardingDone = ref.watch(onboardingCompleteProvider);
    final router = ref.watch(routerProvider);

    // ── Gate 1: authentication ──────────────────────────────
    return authState.when(
      loading: _splash,
      // Auth couldn't resolve → let the user sign in.
      error: (_, _) => _authApp(),
      data: (user) {
        if (user == null) return _authApp();

        // ── Gate 2: onboarding (signed-in users only) ───────
        return onboardingDone.when(
          loading: _splash,
          error: (_, _) => _onboardingApp(),
          data: (isDone) {
            if (!isDone) return _onboardingApp();
            // Returning, signed-in user — main app with full theming.
            // Wrapped so the real-time bank-SMS listener starts exactly once
            // for the signed-in, onboarded session.
            return _RealtimeSmsGate(
              child: MaterialApp.router(
                title: 'Finella',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.theme,
                darkTheme: AppTheme.theme, // force the white & green light theme
                themeMode: ThemeMode.light,
                routerConfig: router,
              ),
            );
          },
        );
      },
    );
  }
}

/// Starts the real-time bank-SMS listener for the signed-in, onboarded session
/// and drains any background-captured SMS on launch and on every resume (so
/// transactions captured while the app was closed land as soon as it reopens).
/// Renders the main app unchanged.
class _RealtimeSmsGate extends ConsumerStatefulWidget {
  final Widget child;
  const _RealtimeSmsGate({required this.child});

  @override
  ConsumerState<_RealtimeSmsGate> createState() => _RealtimeSmsGateState();
}

class _RealtimeSmsGateState extends ConsumerState<_RealtimeSmsGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Fire-and-forget; start() also drains the background queue.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(smsRealtimeServiceProvider).start();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back to the foreground → save anything captured while away.
    if (state == AppLifecycleState.resumed) {
      ref.read(smsRealtimeServiceProvider).drainPending();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
