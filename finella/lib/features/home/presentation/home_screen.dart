// Old home sections (balance hero, AI insights, goals, reconcile, etc.) are
// commented out below — kept for reuse — so these imports / helpers stay even
// though they're only referenced inside the comment block.
// ignore_for_file: unused_import, unused_element, unused_local_variable

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/app_database.dart' show Transaction;
import '../../../core/models/app_models.dart';
import '../../../core/services/streak_service.dart' show StreakData;
import '../../accounts/viewmodel/accounts_view_model.dart';
import '../../../shared/widgets/merchant_transaction_row.dart'
    show formatIndianAmount;
import '../../../core/providers/database_providers.dart';
import '../../../core/providers/streak_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../transactions/presentation/new_transaction_screen.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/finella_colors.dart';
import '../../../shared/widgets/ai_insight_card.dart';
import '../../../shared/widgets/balance_hero_card.dart';
import '../../../shared/widgets/bills_alert.dart';
import '../../../shared/widgets/goal_ring_card.dart';
import '../../../shared/widgets/locked_ai_card.dart';
import '../../../shared/widgets/smart_pills.dart';
import '../../../shared/widgets/spending_bars.dart';
import '../../../shared/widgets/streak_row.dart';
import '../../streak/presentation/widgets/reconcile_banner.dart';
import '../../streak/presentation/widgets/streak_recovery.dart';
import '../../../shared/widgets/transaction_detail_sheet.dart';
import '../../../shared/widgets/tx_list_card.dart';
import '../../auth/viewmodel/auth_view_model.dart';
import '../../budgets/viewmodel/budgets_view_model.dart';
import '../providers/home_provider.dart';
import 'widgets/budgets_preview.dart';

String _formatK(double amount) {
  if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)}L';
  if (amount >= 1000) return '₹${(amount / 1000).toStringAsFixed(1)}K';
  return '₹${amount.toInt()}';
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Daily maintenance on app open: lapse the streak if a day was missed and
    // (re)schedule the 9 PM reminder — skipping today if already reconciled.
    WidgetsBinding.instance.addPostFrameCallback((_) => _runDailyMaintenance());
  }

  Future<void> _runDailyMaintenance() async {
    if (ref.read(currentUidProvider) == null) return;
    // If the streak lapsed, offer premium recovery (or reset it); otherwise
    // this is a no-op.
    if (mounted) await maybeOfferStreakRecovery(context, ref);
    final data = await ref.read(streakServiceProvider).get();
    await NotificationService.instance.scheduleDailyReconcileReminder(
      reconciledToday: data.hasReconciledToday,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(isPremiumProvider);
    final homeState = ref.watch(homeProvider);
    final streak = ref.watch(streakProvider);
    final accountsState = ref.watch(accountsStateProvider);
    final rawTxs = ref.watch(allTransactionsProvider).valueOrNull ?? [];
    final recentBudgets = ref.watch(recentBudgetsProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final greetingName =
        (profile != null && profile.firstName.trim().isNotEmpty)
            ? profile.firstName.trim()
            : 'there';

    return Scaffold(
      backgroundColor: FinellaColors.background,
      floatingActionButton: FloatingActionButton(
        heroTag: 'home_fab',
        backgroundColor: FinellaColors.primary,
        onPressed: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const NewTransactionScreen(),
          ),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(homeProvider.notifier).loadHomeData(homeState.selectedMonth),
          child: homeState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── NEW: TOP APP BAR (avatar + greeting + bell) ──
                      _buildAppBar(greetingName, homeState.billsDueCount),

                      // ── NEW: FINSCO SCORE RING ──
                      _buildScoreSection(homeState.aiScore),

                      // ── NEW: ACCOUNT CARDS (Bank / Credit / Loans) ──
                      _buildAccountCards(accountsState),

                      // ── NEW: LIQUID NET WORTH ──
                      _buildNetWorthCard(accountsState, rawTxs),

                      // ── NEW: R STREAK CALENDAR ──
                      _buildStreakCard(streak),

                      const SizedBox(height: 24),

                      /* ═══════════ MOVED OFF HOME — kept for reuse ═══════════
                         Home now shows only the 5 new sections above. The old
                         sections below are commented out (NOT deleted) so they
                         can be relocated later:
                           • Balance hero card  → ActivityScreen
                           • AI Insights preview → InsightsScreen
                           • Goals preview       → GoalsScreen
                           • Reconcile banner    → SettingsScreen

                      // SECTION 2: STREAK ROW
                      StreakRow(
                        currentDay: streak.currentStreak,
                        totalDays: 250,
                        isPremium: isPremium,
                        onTap: () => context.push(RouteNames.streak),
                      ),
                      const SizedBox(height: 10),

                      // SECTION 2b: DAILY RECONCILE BANNER
                      const ReconcileBanner(),

                      // SECTION 3: BALANCE HERO CARD
                      BalanceHeroCard(
                        balance: homeState.balance,
                        income: homeState.totalIncome,
                        expense: homeState.totalExpense,
                        dailyChange: homeState.dailyChange,
                        isPremium: isPremium,
                        aiScore: isPremium ? homeState.aiScore : null,
                        prediction: isPremium ? homeState.prediction : null,
                      ),
                      const SizedBox(height: 10),

                      // SECTION 4: SMART PILLS
                      SmartPills(
                        savedAmount: _formatK(homeState.savedAmount),
                        goalsActive: homeState.goals.length,
                        streakDays: streak.currentStreak,
                      ),
                      const SizedBox(height: 10),

                      // SECTION 5: BILLS ALERT
                      if (homeState.billsDueCount > 0) ...[
                        BillsAlertCard(
                          billCount: homeState.billsDueCount,
                          totalAmount: homeState.billsDueAmount,
                          isPremium: isPremium,
                          onReview: () => context.go(RouteNames.activity),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // SECTION 6: AI INSIGHTS (PREMIUM ONLY)
                      if (isPremium) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: const [
                              Text('AI Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: FinellaColors.textDark)),
                              SizedBox(width: 6),
                              Icon(Icons.auto_awesome, size: 14, color: FinellaColors.gold),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Column(
                            children: [
                              AiInsightCard(type: InsightType.warn, title: 'Food delivery up 40% this week', body: 'Cook 3 meals to save ₹2,500'),
                              AiInsightCard(type: InsightType.save, title: 'Cancel Hotstar + switch Spotify', body: 'Save ₹5,188/year combined'),
                              AiInsightCard(type: InsightType.goal, title: 'Emergency Fund hits Gold milestone', body: 'At current pace — just 6 weeks!'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // SECTION 7: GOALS
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Your Goals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: FinellaColors.textDark)),
                            GestureDetector(
                              onTap: () => context.go(RouteNames.goals),
                              child: const Text('See All →', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: FinellaColors.primary)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: isPremium ? 205 : 170,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          itemCount: homeState.goals.length,
                          separatorBuilder: (ctx, i) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final goal = homeState.goals[i];
                            return GoalRingCard(
                              name: goal.name,
                              savedAmount: goal.saved,
                              targetAmount: goal.target,
                              isPremium: isPremium,
                              aiTip: isPremium ? goal.aiTip : null,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // SECTION 8: WEEKLY SPENDING
                      WeeklySpendingBars(
                        weeklyTotal: homeState.weeklyTotal,
                        categories: homeState.weeklySpending,
                      ),
                      const SizedBox(height: 10),

                      // SECTION 9: LOCKED AI (FREE ONLY)
                      if (!isPremium) ...[
                        LockedAiCard(
                          teaserText: 'You could save ₹4,800 this month...',
                          onUpgrade: () => context.push(RouteNames.premium),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // SECTION 10: RECENT TRANSACTIONS
                      TransactionListCard(
                        transactions: homeState.recentTransactions,
                        onSeeAll: () => context.go(RouteNames.activity),
                        onRowTap: (txData) {
                          final raw = rawTxs.where(
                            (t) => t.id.toString() == txData.id,
                          ).firstOrNull;
                          if (raw != null) {
                            showTransactionDetail(
                              context: context,
                              ref: ref,
                              transaction: raw,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // SECTION 11: BUDGETS PREVIEW (last 3)
                      BudgetsPreview(
                        budgets: recentBudgets,
                        onSeeAll: () => context.push(RouteNames.budgets),
                        onTap: (_) => context.push(RouteNames.budgets),
                      ),
                      const SizedBox(height: 80),
                      ═══════════ end MOVED OFF HOME ═══════════ */
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  // ════════════════ NEW WHITE & GREEN HOME SECTIONS ════════════════

  Widget _buildAppBar(String name, int billsDue) {
    final display = (name.isEmpty || name == 'there') ? 'FinStreak User' : name;
    final initial = display[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8F0E4), width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => context.push(RouteNames.profile),
            behavior: HitTestBehavior.opaque,
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50), shape: BoxShape.circle),
                child: Center(
                  child: Text(initial,
                      style: const TextStyle(
                          fontFamily: 'OpenSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(width: 9),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Welcome back',
                      style: TextStyle(
                          fontFamily: 'OpenSans',
                          fontSize: 11,
                          color: Color(0xFF999999))),
                  Row(children: [
                    Text(display,
                        style: const TextStyle(
                            fontFamily: 'OpenSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111111))),
                    const SizedBox(width: 3),
                    const Icon(Icons.keyboard_arrow_down,
                        size: 16, color: Color(0xFF111111)),
                  ]),
                ],
              ),
            ]),
          ),
          // Trailing action buttons grouped together on the right.
          Row(mainAxisSize: MainAxisSize.min, children: [
          // Notification bell (with a dot when bills are due).
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF2E7D32),
            ),
            child: Stack(children: [
              const Center(
                  child: Icon(Icons.notifications_outlined,
                      size: 17, color: Colors.white)),
              if (billsDue > 0)
                Positioned(
                  top: 5,
                  right: 6,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF5350),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF2E7D32), width: 1.5),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 2),
          // Settings button.
          GestureDetector(
            onTap: () => context.push(RouteNames.settings),
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF2E7D32),
              ),
              child: const Center(
                  child: Icon(Icons.settings_outlined,
                      size: 17, color: Colors.white)),
            ),
          ),
          ]),
        ],
      ),
    );
  }

  Widget _buildScoreSection(int score) {
    final label = score >= 80
        ? 'Excellent'
        : score >= 60
            ? 'Good'
            : score >= 40
                ? 'Fair'
                : 'Needs work';
    final topPct = (100 - score).clamp(1, 99);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8F0E4), width: 0.5)),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50), shape: BoxShape.circle)),
          const SizedBox(width: 5),
          const Text('FINSCO · FINANCIAL HEALTH SCORE',
              style: TextStyle(
                  fontFamily: 'OpenSans',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Color(0xFF4CAF50))),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: 110,
          height: 110,
          child: CustomPaint(
            painter: _ScoreRingPainter(score / 100),
            child: Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$score',
                    style: const TextStyle(
                        fontFamily: 'OpenSans',
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A3A1A))),
                Text(label,
                    style: const TextStyle(
                        fontFamily: 'OpenSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4CAF50))),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: const Color(0xFFEAF5E4),
              borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50), shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text('Top $topPct% of users',
                style: const TextStyle(
                    fontFamily: 'OpenSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2E7D32))),
          ]),
        ),
      ]),
    );
  }

  Widget _buildAccountCards(AccountsState acc) {
    final byType = <String, double>{};
    final countByType = <String, int>{};
    for (final s in acc.accounts) {
      byType[s.type] = (byType[s.type] ?? 0) + s.currentBalance;
      countByType[s.type] = (countByType[s.type] ?? 0) + 1;
    }
    final cards = <Widget>[];
    void add(String type, String tag, String sub, IconData icon,
        {required bool liability}) {
      if (!byType.containsKey(type)) return;
      final total = byType[type]!;
      // Liabilities (credit/loans) always read as debt; asset accounts take the
      // real sign of their balance (an overdrawn bank reads negative/red).
      final positive = liability ? false : total >= 0;
      cards.add(_accountCard(
        tag: tag,
        sub: sub,
        total: total,
        count: countByType[type]!,
        icon: icon,
        positive: positive,
        liability: liability,
      ));
    }

    add('bank', 'BANK ACCOUNTS', 'Total Balance',
        Icons.account_balance_outlined,
        liability: false);
    add('cash', 'CASH', 'Total Balance', Icons.payments_outlined,
        liability: false);
    add('credit_card', 'CREDIT CARDS', 'Total Outstanding',
        Icons.credit_card_outlined,
        liability: true);
    for (final t in byType.keys) {
      if (['bank', 'cash', 'credit_card'].contains(t)) continue;
      add(t, t.replaceAll('_', ' ').toUpperCase(), 'Total Outstanding',
          Icons.account_balance_wallet_outlined,
          liability: true);
    }

    if (cards.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          cards[i],
        ],
      ]),
    );
  }

  Widget _accountCard({
    required String tag,
    required String sub,
    required double total,
    required int count,
    required IconData icon,
    required bool positive,
    required bool liability,
  }) {
    final amtColor =
        positive ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F);
    final iconBg =
        positive ? const Color(0xFFEAF5E4) : const Color(0xFFFEF0EE);
    final iconColor =
        positive ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F);
    final amt =
        '${positive ? '' : '−'}₹${formatIndianAmount(total.abs())}';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4F0DE), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration:
              BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tag,
                  style: const TextStyle(
                      fontFamily: 'OpenSans',
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Color(0xFF999999))),
              Text(sub,
                  style: const TextStyle(
                      fontFamily: 'OpenSans',
                      fontSize: 10,
                      color: Color(0xFFAAAAAA))),
              const SizedBox(height: 1),
              Text(amt,
                  style: TextStyle(
                      fontFamily: 'OpenSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: amtColor)),
              const SizedBox(height: 1),
              Text(
                  positive ? '+ Positive Balance' : '+ Negative Balance',
                  style: TextStyle(
                      fontFamily: 'OpenSans',
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: positive
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFEF5350))),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('BALANCE',
                style: TextStyle(
                    fontFamily: 'OpenSans',
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: Color(0xFFBBBBBB))),
            const SizedBox(height: 1),
            Text(amt,
                style: TextStyle(
                    fontFamily: 'OpenSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: amtColor)),
            const SizedBox(height: 2),
            Text('$count account${count == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontFamily: 'OpenSans',
                    fontSize: 9,
                    color: Color(0xFFCCCCCC))),
          ],
        ),
        const SizedBox(width: 6),
        const Text('›', style: TextStyle(fontSize: 18, color: Color(0xFFCCCCCC))),
      ]),
    );
  }

  Widget _buildNetWorthCard(AccountsState acc, List<Transaction> txs) {
    // Net worth as the provider computes it (assets − liabilities), shown with
    // its real sign so an overdrawn / debt-heavy position reads negative.
    final netWorth = acc.totalAmount;
    final trend = _netWorthTrend(txs, netWorth);
    final change =
        trend.length >= 2 ? trend.last - trend[trend.length - 2] : 0.0;
    final prev = trend.length >= 2 ? trend[trend.length - 2].abs() : 0.0;
    final pct = prev > 0 ? (change / prev) * 100 : 0.0;
    final up = change >= 0;
    final changeColor =
        up ? const Color(0xFF4CAF50) : const Color(0xFFD32F2F);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4F0DE), width: 1),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Text('LIQUID NET WORTH',
                    style: TextStyle(
                        fontFamily: 'OpenSans',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Color(0xFF999999))),
                const SizedBox(width: 5),
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFCCCCCC))),
                  child: const Center(
                    child: Text('i',
                        style: TextStyle(
                            fontFamily: 'OpenSans',
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFAAAAAA))),
                  ),
                ),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: const Color(0xFFEAF5E4),
                    borderRadius: BorderRadius.circular(8)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('12 Months',
                      style: TextStyle(
                          fontFamily: 'OpenSans',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E7D32))),
                  SizedBox(width: 3),
                  Icon(Icons.keyboard_arrow_down,
                      size: 12, color: Color(0xFF2E7D32)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
              '${netWorth < 0 ? '−' : ''}₹${formatIndianAmount(netWorth.abs())}',
              style: TextStyle(
                  fontFamily: 'OpenSans',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: netWorth < 0
                      ? const Color(0xFFD32F2F)
                      : const Color(0xFF1A3A1A))),
          const SizedBox(height: 2),
          Text(
              '${up ? '↑' : '↓'} ₹${formatIndianAmount(change.abs())} '
              '(${pct.abs().toStringAsFixed(2)}%) vs last month',
              style: TextStyle(
                  fontFamily: 'OpenSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: changeColor)),
          const SizedBox(height: 10),
          SizedBox(height: 60, child: _netWorthChart(trend)),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _monthLabels()
                .map((l) => Text(l,
                    style: const TextStyle(
                        fontFamily: 'OpenSans',
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFCCCCCC))))
                .toList(),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => context.push(RouteNames.accounts),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                  color: const Color(0xFFEAF5E4),
                  borderRadius: BorderRadius.circular(9)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('View details',
                    style: TextStyle(
                        fontFamily: 'OpenSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E7D32))),
                SizedBox(width: 4),
                Text('›', style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32))),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// X-axis labels for the 12-month net-worth window — every other month plus
  /// the current month (e.g. JUN AUG OCT DEC FEB APR MAY).
  List<String> _monthLabels() {
    const abbr = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    final now = DateTime.now();
    return [
      for (final i in [0, 2, 4, 6, 8, 10, 11])
        abbr[DateTime(now.year, now.month - 11 + i, 1).month - 1],
    ];
  }

  /// Approximate 12-month liquid net-worth trend from transaction history
  /// (running income − expense per month), anchored so the last point equals
  /// the real current net worth.
  List<double> _netWorthTrend(List<Transaction> txs, double current) {
    final now = DateTime.now();
    final pts = <double>[];
    for (var m = 11; m >= 0; m--) {
      final end = DateTime(now.year, now.month - m + 1, 1);
      var v = 0.0;
      for (final t in txs) {
        if (t.date.isBefore(end)) {
          v += (t.type == 'income' || t.type == 'transfer_in')
              ? t.amount
              : -t.amount;
        }
      }
      pts.add(v);
    }
    final offset = current - (pts.isNotEmpty ? pts.last : 0);
    return [for (final p in pts) p + offset];
  }

  Widget _netWorthChart(List<double> trend) {
    if (trend.isEmpty) return const SizedBox.shrink();
    return LineChart(LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (var i = 0; i < trend.length; i++) FlSpot(i.toDouble(), trend[i])
          ],
          isCurved: true,
          color: const Color(0xFF4CAF50),
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF4CAF50).withValues(alpha: 0.2),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    ));
  }

  Widget _buildStreakCard(StreakData streak) {
    final now = DateTime.now();
    final logged = streak.openedDates
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();
    var loggedThisMonth = 0;
    for (final d in logged) {
      if (d.year == now.year && d.month == now.month) loggedThisMonth++;
    }
    final consistency =
        now.day > 0 ? ((loggedThisMonth / now.day) * 100).round() : 0;
    const monthsFull = [
      'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4F0DE), width: 1),
      ),
      padding: const EdgeInsets.all(13),
      child: Column(children: [
        Row(children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
                color: const Color(0xFFEAF5E4),
                borderRadius: BorderRadius.circular(7)),
            child: const Icon(Icons.calendar_today_outlined,
                size: 14, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 7),
          const Text('R STREAK',
              style: TextStyle(
                  fontFamily: 'OpenSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: Color(0xFF1A3A1A))),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('FINANCIAL CONSISTENCY',
                    style: TextStyle(
                        fontFamily: 'OpenSans',
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: Color(0xFFBBBBBB))),
                const SizedBox(height: 2),
                Text('$consistency%',
                    style: const TextStyle(
                        fontFamily: 'OpenSans',
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.0,
                        color: Color(0xFF4CAF50))),
                const SizedBox(height: 4),
                const Text('Keep showing up.\nConsistency builds wealth.',
                    style: TextStyle(
                        fontFamily: 'OpenSans',
                        fontSize: 10,
                        color: Color(0xFFAAAAAA),
                        height: 1.4)),
                const SizedBox(height: 7),
                _legend(const Color(0xFF4CAF50), 'Logged'),
                const SizedBox(height: 3),
                _legend(const Color(0xFFEF5350), 'Missed'),
                const SizedBox(height: 3),
                _legend(Colors.transparent, 'Today', outlined: true),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(children: [
              Text('${monthsFull[now.month - 1]} ${now.year}',
                  style: const TextStyle(
                      fontFamily: 'OpenSans',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A3A1A))),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                    .map((d) => Text(d,
                        style: const TextStyle(
                            fontFamily: 'OpenSans',
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFBBBBBB))))
                    .toList(),
              ),
              const SizedBox(height: 4),
              _calendarGrid(now, logged),
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _calendarGrid(DateTime now, Set<DateTime> logged) {
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final leading = DateTime(now.year, now.month, 1).weekday - 1; // Mon=0
    final cells = leading + daysInMonth;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: cells,
      itemBuilder: (ctx, i) {
        if (i < leading) return const SizedBox.shrink();
        final day = i - leading + 1;
        final date = DateTime(now.year, now.month, day);
        Color bg = Colors.transparent;
        Color textColor = const Color(0xFFCCCCCC);
        Border? border;
        var fw = FontWeight.w700;
        if (day == now.day) {
          border = Border.all(color: const Color(0xFF4CAF50), width: 1.5);
          textColor = const Color(0xFF2E7D32);
          fw = FontWeight.w700;
        } else if (logged.contains(date)) {
          bg = const Color(0xFFEAF5E4);
          textColor = const Color(0xFF2E7D32);
        } else if (date.isBefore(DateTime(now.year, now.month, now.day))) {
          bg = const Color(0xFFFEF0EE);
          textColor = const Color(0xFFD32F2F);
        }
        return Container(
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(5), border: border),
          child: Center(
            child: Text('$day',
                style: TextStyle(
                    fontFamily: 'OpenSans',
                    fontSize: 11,
                    fontWeight: fw,
                    color: textColor)),
          ),
        );
      },
    );
  }

  Widget _legend(Color color, String label, {bool outlined = false}) {
    return Row(children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color,
          shape: BoxShape.circle,
          border: outlined
              ? Border.all(color: const Color(0xFFBBBBBB), width: 1.5)
              : null,
        ),
      ),
      const SizedBox(width: 5),
      Text(label,
          style: const TextStyle(
              fontFamily: 'OpenSans', fontSize: 10, color: Color(0xFF999999))),
    ]);
  }
}

/// FINSCO score ring — green progress arc on a pale track.
class _ScoreRingPainter extends CustomPainter {
  final double progress; // 0..1
  _ScoreRingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 6;
    final track = Paint()
      ..color = const Color(0xFFE8F5E0)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = const Color(0xFF4CAF50)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    const start = -1.5707963; // -90° (top)
    final sweep = (progress.clamp(0.0, 1.0)) * 6.2831853;
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius), start, sweep, false, fill);
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) => old.progress != progress;
}
