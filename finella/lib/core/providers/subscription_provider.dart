import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_providers.dart';

enum SubscriptionTier { free, premium }

class SubscriptionState {
  final SubscriptionTier tier;
  final DateTime? expiresAt;

  const SubscriptionState({this.tier = SubscriptionTier.free, this.expiresAt});

  bool get isPremium => tier == SubscriptionTier.premium;
}

/// SharedPreferences is still provided by main.dart. Premium no longer reads
/// from it: the entitlement is written by the server after a verified payment.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override sharedPreferencesProvider in main');
});

/// Premium status from users/{uid}/billing/entitlement. Only the server can
/// write this document (see firestore.rules), so it cannot be granted locally.
final subscriptionProvider = StreamProvider<SubscriptionState>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const SubscriptionState());

  final db = ref.watch(firestoreProvider);
  return db
      .collection('users')
      .doc(uid)
      .collection('billing')
      .doc('entitlement')
      .snapshots()
      .map((snap) {
    final expiresAt = (snap.data()?['expiresAt'] as Timestamp?)?.toDate();
    final active = expiresAt != null && expiresAt.isAfter(DateTime.now());
    return SubscriptionState(
      tier: active ? SubscriptionTier.premium : SubscriptionTier.free,
      expiresAt: expiresAt,
    );
  });
});

/// True while the user has an active premium pass. Free until the first
/// entitlement loads, so premium never shows before the server confirms it.
final isPremiumProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionProvider).valueOrNull?.isPremium ?? false;
});
