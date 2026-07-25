import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/router/route_names.dart';
import '../models/category_stat.dart';
import '../providers/insights_provider.dart';

// ── Format helpers ────────────────────────────────────────────
String _formatAmount(double amount) {
  if (amount >= 100000) {
    return '₹${(amount / 100000).toStringAsFixed(1)}L';
  }
  final s = amount.toInt().toString();
  if (s.length > 3) {
    return '₹${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
  }
  return '₹$s';
}

String _monthName(DateTime dt) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  return '${months[dt.month - 1]} ${dt.year}';
}

// ── Insight card styling ──────────────────────────────────────
class _InsightStyle {
  final Color borderColor;
  final Color iconBg;
  final Color iconColor;
  final IconData icon;

  const _InsightStyle({
    required this.borderColor,
    required this.iconBg,
    required this.iconColor,
    required this.icon,
  });
}

_InsightStyle _styleFor(InsightCardType t) => switch (t) {
      InsightCardType.pattern => const _InsightStyle(
          borderColor: Color(0xFFD4AF37),
          iconBg: Color(0xFFFEF9C3),
          iconColor: Color(0xFFB45309),
          icon: Icons.bar_chart_rounded,
        ),
      InsightCardType.forecast => const _InsightStyle(
          borderColor: Color(0xFF3B82F6),
          iconBg: Color(0xFFEFF6FF),
          iconColor: Color(0xFF1D4ED8),
          icon: Icons.trending_up_rounded,
        ),
      InsightCardType.behavior => const _InsightStyle(
          borderColor: Color(0xFF8B5CF6),
          iconBg: Color(0xFFF5F3FF),
          iconColor: Color(0xFF6D28D9),
          icon: Icons.psychology_rounded,
        ),
      InsightCardType.saving => const _InsightStyle(
          borderColor: Color(0xFF2E7D32),
          iconBg: Color(0xFFF0FDF4),
          iconColor: Color(0xFF065F46),
          icon: Icons.check_circle_outline_rounded,
        ),
    };

// ── Screen ────────────────────────────────────────────────────
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(insightsProvider);
    final notifier = ref.read(insightsProvider.notifier);
    final isPremium = ref.watch(isPremiumProvider);

    final stats = state.selectedTab == 'expenses'
        ? state.expenseStats
        : state.incomeStats;
    final total = state.selectedTab == 'expenses'
        ? state.totalExpense
        : state.totalIncome;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF4),
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  // ── HEADER ──────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Insights',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                          if (isPremium)
                            const Icon(Icons.auto_awesome,
                                color: Color(0xFFD4AF37), size: 22),
                        ],
                      ),
                    ),
                  ),

                  // ── MONTH SELECTOR ───────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left,
                                color: Color(0xFF374151)),
                            onPressed: notifier.previousMonth,
                            splashRadius: 20,
                          ),
                          Text(
                            _monthName(state.selectedMonth),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right,
                                color: Color(0xFF374151)),
                            onPressed: notifier.nextMonth,
                            splashRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── TAB TOGGLE ───────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          children: [
                            _TabBtn(
                              label: 'Expenses',
                              active: state.selectedTab == 'expenses',
                              onTap: () => notifier.selectTab('expenses'),
                            ),
                            _TabBtn(
                              label: 'Income',
                              active: state.selectedTab == 'income',
                              onTap: () => notifier.selectTab('income'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 14)),

                  // ── DONUT CHART CARD ─────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FAF4),
                          border: Border.all(color: const Color(0xFFE4F0DE)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: stats.isEmpty
                            ? const SizedBox(
                                height: 200,
                                child: Center(child: Text('No data')),
                              )
                            : SizedBox(
                                height: 220,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    PieChart(
                                      PieChartData(
                                        sectionsSpace: 3,
                                        centerSpaceRadius: 68,
                                        sections: stats
                                            .map(
                                              (cat) => PieChartSectionData(
                                                value: cat.percentage,
                                                color: cat.color,
                                                radius: 48,
                                                showTitle: true,
                                                title:
                                                    '${cat.percentage.toInt()}%',
                                                titleStyle: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                                titlePositionPercentageOffset:
                                                    0.6,
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'Total',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatAmount(total),
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 14)),

                  // ── CATEGORY LIST ────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          for (var i = 0; i < stats.length; i++)
                            _CategoryItem(
                              cat: stats[i],
                              showDivider: i != stats.length - 1,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // ── LOCKED SECTION (FREE) ────────────────────
                  if (!isPremium)
                    SliverToBoxAdapter(
                      child: _LockedSection(
                        onUnlock: () => context.push(RouteNames.premium),
                      ),
                    ),

                  // ── PREMIUM INSIGHTS SECTION ─────────────────
                  if (isPremium) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Row(
                          children: const [
                            Text(
                              'Premium Insights',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.auto_awesome,
                                size: 16, color: Color(0xFFD4AF37)),
                          ],
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final insight = state.aiInsights[i];
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            child: _PremiumInsightCard(insight: insight),
                          );
                        },
                        childCount: state.aiInsights.length,
                      ),
                    ),
                  ],

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
      ),
    );
  }
}

// ── Tab button ────────────────────────────────────────────────
class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF2E7D32) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Category list item ────────────────────────────────────────
class _CategoryItem extends StatelessWidget {
  final CategoryStat cat;
  final bool showDivider;

  const _CategoryItem({required this.cat, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    final txLabel = cat.transactionCount == 1 ? 'transaction' : 'transactions';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cat.bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(cat.icon, color: cat.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${cat.transactionCount} $txLabel · ${cat.percentage.toInt()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatAmount(cat.amount),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
            ],
          ),
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(left: 56),
            child: Divider(
                height: 1, thickness: 1, color: Color(0xFFC8E6C9)),
          ),
      ],
    );
  }
}

// ── Locked section (free users) ───────────────────────────────
class _LockedSection extends StatelessWidget {
  final VoidCallback onUnlock;

  const _LockedSection({required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Patterns locked
            _LockedBlock(title: 'AI Patterns'),
            const SizedBox(height: 16),
            // Spending Forecasts locked
            _LockedBlock(title: 'Spending Forecasts'),
            const SizedBox(height: 20),
            // Unlock CTA
            Center(
              child: GestureDetector(
                onTap: onUnlock,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Unlock with Premium',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_outward_rounded,
                        size: 16, color: Color(0xFF2E7D32)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedBlock extends StatelessWidget {
  final String title;

  const _LockedBlock({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lock_outline,
                size: 16, color: Color(0xFF6B7280)),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Three blurred preview cards
        Row(
          children: List.generate(3, (i) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1D5DB),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Container(
                          height: 5,
                          width: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1D5DB),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Container(
                          height: 5,
                          width: 35,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1D5DB),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Container(
                          height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFFC4C9D4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── Premium insight card ──────────────────────────────────────
class _PremiumInsightCard extends StatelessWidget {
  final InsightCard insight;

  const _PremiumInsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final s = _styleFor(insight.type);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF3F4F6)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colored left accent bar
          Container(width: 3, color: s.borderColor),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: s.iconBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(s.icon, color: s.iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          insight.body,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
