import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/streak_provider.dart';
import '../../../../core/router/route_names.dart';

/// Home-screen banner prompting the user to reconcile today. Turns green once
/// today's reconciliation is done. Hidden until the streak data resolves.
class ReconcileBanner extends ConsumerWidget {
  const ReconcileBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(streakDataStreamProvider);
    final streak = async.valueOrNull;
    if (streak == null) return const SizedBox.shrink();

    final done = streak.hasReconciledToday;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: done
          ? _DoneBanner(streakDays: streak.currentStreak)
          : _PromptBanner(
              onTap: () => context.push(RouteNames.reconcile),
            ),
    );
  }
}

class _PromptBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _PromptBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Keep your streak alive!',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF92400E))),
                  SizedBox(height: 2),
                  Text("Reconcile today's accounts",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF92400E))),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Reconcile Now',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded,
                      size: 14, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoneBanner extends StatelessWidget {
  final int streakDays;
  const _DoneBanner({required this.streakDays});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F4EC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBE7CE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF2E7D32), size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Reconciled today!',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2E7D32))),
          ),
          Text('🔥 Streak: $streakDays days',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E7D32))),
        ],
      ),
    );
  }
}
