import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/streak_provider.dart';
import '../../../core/router/route_names.dart';

class StreakScreen extends ConsumerWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FAF4),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Color(0xFF111827),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your Streak',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2E7D32),
              ),
            ),
            SizedBox(width: 6),
            Text('🔥', style: TextStyle(fontSize: 20)),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 0. RECONCILE TODAY BUTTON ────────────────
            _ReconcileButton(reconciledToday: streak.hasReconciledToday),
            const SizedBox(height: 14),

            // ── 1. STREAK HERO CARD ──────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${streak.totalDays}',
                            style: const TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '/250 Days',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Daily Streak',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text('🔥',
                      style: TextStyle(fontSize: 52)),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── 2. PROGRESS BAR ──────────────────────────
            Stack(
              children: [
                Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: streak.progress.clamp(0.04, 1.0),
                  child: Container(
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        '${streak.percentage}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Center(
              child: Text(
                '${streak.daysRemaining} days to go!',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── 3. REWARD PROMISE ────────────────────────
            Center(
              child: Text(
                'Reconcile 250 days this year and get FREE:\n'
                'Next Year Premium + Tax Returns Filing!',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF374151),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 16),

            // ── 4. HEATMAP CARD ──────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  _buildHeatmap(streak.openedDates),

                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFF3F4F6)),
                  const SizedBox(height: 8),

                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatChip(
                        emoji: '🔥',
                        label: 'Current',
                        value: '${streak.currentStreak} days',
                      ),
                      Container(
                        width: 1,
                        height: 28,
                        color: const Color(0xFFE5E7EB),
                      ),
                      _StatChip(
                        emoji: '🏆',
                        label: 'Longest',
                        value: '${streak.longestStreak} days',
                      ),
                      Container(
                        width: 1,
                        height: 28,
                        color: const Color(0xFFE5E7EB),
                      ),
                      _StatChip(
                        emoji: '📅',
                        label: 'Total',
                        value: '${streak.totalDays} days',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── 5. MILESTONE REWARD CARDS ────────────────
            const Text(
              'Reward Milestones',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 10),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _MilestoneCard(
                    days: 50,
                    title: '50 Days',
                    subtitle: 'Exclusive Badge',
                    emoji: '🎖️',
                    isReached: streak.totalDays >= 50,
                    color: const Color(0xFFCD7F32),
                  ),
                  const SizedBox(width: 12),
                  _MilestoneCard(
                    days: 100,
                    title: '100 Days',
                    subtitle: 'Cashback Reward',
                    emoji: '💰',
                    isReached: streak.totalDays >= 100,
                    color: const Color(0xFF22C55E),
                  ),
                  const SizedBox(width: 12),
                  _MilestoneCard(
                    days: 250,
                    title: '250 Days',
                    subtitle: 'Free Premium\n+ Tax Returns',
                    emoji: '⭐',
                    isReached: streak.totalDays >= 250,
                    color: const Color(0xFFD4AF37),
                    isHighlighted: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Heatmap (13 weeks × 7 days) ──────────────────────────
  Widget _buildHeatmap(List<DateTime> openedDates) {
    final today = DateTime.now();
    final todayNorm =
        DateTime(today.year, today.month, today.day);

    final openedSet = openedDates.map((d) {
      final n = DateTime(d.year, d.month, d.day);
      return '${n.year}-${n.month}-${n.day}';
    }).toSet();

    final weeks = <Widget>[];

    // Build 13 columns (weeks), oldest on left
    for (int week = 12; week >= 0; week--) {
      final dayCells = <Widget>[];
      for (int day = 6; day >= 0; day--) {
        final date = todayNorm
            .subtract(Duration(days: week * 7 + day));
        final key = '${date.year}-${date.month}-${date.day}';
        final wasOpened = openedSet.contains(key);
        final isFuture = date.isAfter(todayNorm);
        final isToday = date == todayNorm;

        Color cellColor;
        if (isFuture) {
          cellColor = const Color(0xFFF3F4F6);
        } else if (wasOpened) {
          cellColor = _heatmapColor(date, todayNorm);
        } else {
          cellColor = const Color(0xFFF3F4F6);
        }

        dayCells.add(
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              color: cellColor,
              borderRadius: BorderRadius.circular(3),
              border: isToday
                  ? Border.all(
                      color: const Color(0xFF2E7D32),
                      width: 1.5,
                    )
                  : null,
            ),
          ),
        );
      }
      weeks.add(Column(children: dayCells));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day-of-week labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: const [
            _DayLabel('M'),
            _DayLabel('T'),
            _DayLabel('W'),
            _DayLabel('T'),
            _DayLabel('F'),
            _DayLabel('S'),
            _DayLabel('S'),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: weeks,
        ),
        const SizedBox(height: 8),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text(
              'Less  ',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF9CA3AF),
              ),
            ),
            for (final c in const [
              Color(0xFFF3F4F6),
              Color(0xFF9FE1CB),
              Color(0xFF4CAF85),
              Color(0xFF1A7A50),
              Color(0xFF2E7D32),
            ])
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            const Text(
              '  More',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _heatmapColor(DateTime date, DateTime today) {
    final diff = today.difference(date).inDays;
    if (diff < 7)  return const Color(0xFF2E7D32); // darkest
    if (diff < 21) return const Color(0xFF1A7A50);
    if (diff < 42) return const Color(0xFF4CAF85);
    return const Color(0xFF9FE1CB);               // lightest
  }
}

// ── Reconcile-today button ────────────────────────────────────
class _ReconcileButton extends StatelessWidget {
  final bool reconciledToday;
  const _ReconcileButton({required this.reconciledToday});

  @override
  Widget build(BuildContext context) {
    if (reconciledToday) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.check_circle_rounded, size: 20),
          label: const Text('Reconciled Today!'),
          style: ElevatedButton.styleFrom(
            disabledBackgroundColor: const Color(0xFFD1FADF),
            disabledForegroundColor: const Color(0xFF2E7D32),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () => context.push(RouteNames.reconcile),
        icon: const Text('🎯', style: TextStyle(fontSize: 16)),
        label: const Text("Reconcile Today's Accounts"),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0A3D2E),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ── Day-of-week header label ──────────────────────────────────
class _DayLabel extends StatelessWidget {
  final String label;
  const _DayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 17,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Color(0xFF9CA3AF),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Stat chip (current / longest / total) ─────────────────────
class _StatChip extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;

  const _StatChip({
    required this.emoji,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF9CA3AF),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Milestone reward card ─────────────────────────────────────
class _MilestoneCard extends StatelessWidget {
  final int days;
  final String title;
  final String subtitle;
  final String emoji;
  final bool isReached;
  final Color color;
  final bool isHighlighted;

  const _MilestoneCard({
    required this.days,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.isReached,
    required this.color,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isReached
            ? color.withValues(alpha: 0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlighted
              ? color
              : isReached
                  ? color.withValues(alpha: 0.4)
                  : const Color(0xFFE5E7EB),
          width: isHighlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isReached ? color : const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF9CA3AF),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(emoji, style: const TextStyle(fontSize: 40)),
          if (isReached) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Achieved!',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              '$days days',
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFFD1D5DB),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
