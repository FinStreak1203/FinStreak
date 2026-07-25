import 'package:flutter/material.dart';
import '../../models/goal_model.dart';
import 'milestone_badge.dart';
import 'premium_ai_card.dart';

class GoalCard extends StatelessWidget {
  final GoalModel goal;
  final bool isPremium;

  const GoalCard({super.key, required this.goal, required this.isPremium});

  String _fmt(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(0)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + percentage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                goal.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              Text(
                '${goal.percentage.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Saved / Target
          Row(
            children: [
              Text(
                _fmt(goal.savedAmount),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const Text(
                ' saved of ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              Text(
                _fmt(goal.targetAmount),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: goal.percentage / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
            ),
          ),
          const SizedBox(height: 6),

          // Remaining
          Text(
            '${_fmt(goal.remainingAmount)} remaining',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 14),

          // Milestone badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              MilestoneBadge(
                  emoji: '🥉', label: 'Bronze', percent: 10, reached: goal.bronzeReached),
              MilestoneBadge(
                  emoji: '🥈', label: 'Silver', percent: 20, reached: goal.silverReached),
              MilestoneBadge(
                  emoji: '🥇', label: 'Gold', percent: 50, reached: goal.goldReached),
              MilestoneBadge(
                  emoji: '💎', label: 'Diamond', percent: 90, reached: goal.diamondReached),
              MilestoneBadge(
                  emoji: '🏆', label: 'Trophy', percent: 100, reached: goal.trophyReached),
            ],
          ),

          // Premium AI tips
          if (isPremium) ...[
            if (goal.aiTip != null)
              PremiumAiCard(
                  icon: Icons.lightbulb_outline, text: goal.aiTip!),
            if (goal.aiTimeline != null)
              PremiumAiCard(
                  icon: Icons.auto_awesome, text: goal.aiTimeline!),
          ],
        ],
      ),
    );
  }
}
