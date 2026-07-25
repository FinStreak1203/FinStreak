/// Outcome of a reconcile attempt, passed to the success / mismatch screens.
class ReconcileResult {
  final double expected;
  final double actual;
  final int previousStreak;
  final int newStreak;

  const ReconcileResult({
    required this.expected,
    required this.actual,
    required this.previousStreak,
    required this.newStreak,
  });

  /// Signed gap (actual − expected); ~0 on a successful reconcile.
  double get difference => actual - expected;
}
