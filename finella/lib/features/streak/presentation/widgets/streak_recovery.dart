import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/streak_provider.dart';
import '../../../../core/providers/subscription_provider.dart';
import '../../../../core/router/route_names.dart';

const _kGreen = Color(0xFF2E7D32);
const _kGold = Color(0xFFD4AF37);

/// Called on app open. If the streak has lapsed, offers premium recovery
/// (or an upgrade prompt for free users); otherwise resets the streak.
///
/// Returns without doing anything when the streak is intact.
Future<void> maybeOfferStreakRecovery(
  BuildContext context,
  WidgetRef ref,
) async {
  final service = ref.read(streakServiceProvider);
  final data = await service.get();
  if (!service.isStreakBroken(data)) return;
  if (!context.mounted) return;

  final isPremium = ref.read(isPremiumProvider);

  // ── Free user → upgrade prompt, then reset on decline ───────
  if (!isPremium) {
    final upgrade = await _showUpgradeDialog(context);
    if (upgrade == true) {
      if (context.mounted) context.push(RouteNames.premium);
      return; // leave the streak as-is; re-offered on next open once premium
    }
    await service.resetStreakIfBroken();
    return;
  }

  // ── Premium but recovery already spent this month → reset ───
  if (!service.recoveryAvailable(data)) {
    await service.resetStreakIfBroken();
    return;
  }

  // ── Premium with a recovery available → offer it ────────────
  final use = await _showRecoveryDialog(context, data.currentStreak);
  if (use == true) {
    final ok = await service.useStreakRecovery(isPremium: true);
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔥 Streak recovered!'),
          backgroundColor: _kGreen,
          duration: Duration(seconds: 2),
        ),
      );
    }
  } else {
    await service.resetStreakIfBroken();
  }
}

Future<bool?> _showRecoveryDialog(BuildContext context, int streakDays) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: const [
          Text('🛟', style: TextStyle(fontSize: 22)),
          SizedBox(width: 8),
          Text('Use streak recovery?',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827))),
        ],
      ),
      content: Text(
        'Your streak lapsed. You have 1 recovery this month — use it to save '
        'your $streakDays-day streak.',
        style: const TextStyle(
            fontSize: 14, height: 1.5, color: Color(0xFF4B5563)),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('No Thanks',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kGreen,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text('Use Recovery',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

Future<bool?> _showUpgradeDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: const [
          Text('💔', style: TextStyle(fontSize: 22)),
          SizedBox(width: 8),
          Text('Streak lapsed',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827))),
        ],
      ),
      content: const Text(
        'Upgrade to Premium to recover a missed day — you get 1 streak '
        'recovery every month.',
        style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF4B5563)),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Not now',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kGold,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text('Go Premium',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}
