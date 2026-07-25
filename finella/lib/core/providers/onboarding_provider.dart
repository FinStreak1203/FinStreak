import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/viewmodel/auth_view_model.dart';
import 'subscription_provider.dart';

/// SharedPreferences key for a user's onboarding flag.
String onboardingKey(String uid) => 'onboarding_complete_$uid';

/// Returns true once the *current user* has completed onboarding.
///
/// Stored per-uid so every account goes through onboarding (PIN, first
/// account) the first time it signs in. Re-evaluated when the user changes
/// or after the flag is set.
final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return false;
  return prefs.getBool(onboardingKey(uid)) ?? false;
});
