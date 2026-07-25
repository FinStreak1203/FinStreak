import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/streak_service.dart';
import 'database_providers.dart';

/// Firestore-backed streak service (scoped to the signed-in user).
final streakServiceProvider = Provider<StreakService>((ref) {
  return StreakService(
    ref.watch(firestoreProvider),
    ref.watch(currentUidProvider),
    ref.watch(transactionDaoProvider),
    ref.watch(accountDaoProvider),
  );
});

/// Live stream of the streak document.
final streakDataStreamProvider = StreamProvider<StreakData>((ref) {
  return ref.watch(streakServiceProvider).watch();
});

/// Synchronous view of the streak (empty while loading) — keeps the existing
/// streak screen and home widgets simple.
final streakProvider = Provider<StreakData>((ref) {
  return ref.watch(streakDataStreamProvider).valueOrNull ??
      const StreakData.empty();
});
