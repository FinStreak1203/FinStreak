import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SubscriptionTier { free, premium }

class SubscriptionState {
  final SubscriptionTier tier;

  const SubscriptionState({this.tier = SubscriptionTier.free});

  bool get isPremium => tier == SubscriptionTier.premium;

  SubscriptionState copyWith({SubscriptionTier? tier}) =>
      SubscriptionState(tier: tier ?? this.tier);
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override sharedPreferencesProvider in main');
});

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  final SharedPreferences _prefs;

  SubscriptionNotifier(this._prefs) : super(const SubscriptionState()) {
    _loadFromPrefs();
  }

  void _loadFromPrefs() {
    final tierStr = _prefs.getString('subscription_tier') ?? 'free';
    final tier = tierStr == 'premium' ? SubscriptionTier.premium : SubscriptionTier.free;
    state = SubscriptionState(tier: tier);
  }

  Future<void> upgradeToPremium() async {
    await _prefs.setString('subscription_tier', 'premium');
    state = state.copyWith(tier: SubscriptionTier.premium);
  }

  Future<void> downgradeToFree() async {
    await _prefs.setString('subscription_tier', 'free');
    state = state.copyWith(tier: SubscriptionTier.free);
  }
}

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SubscriptionNotifier(prefs);
});

final isPremiumProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionProvider).isPremium;
});
