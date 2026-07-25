import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../shared/widgets/merchant_transaction_row.dart';
import '../../../shared/widgets/transaction_detail_sheet.dart';
import '../../transactions/presentation/new_transaction_screen.dart';
import '../models/activity_models.dart';
import '../providers/activity_provider.dart';
import 'widgets/ai_alert_row.dart';
import 'widgets/recurring_payment_card.dart';
import 'widgets/transaction_row.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activityProvider);
    final notifier = ref.read(activityProvider.notifier);
    final isPremium = ref.watch(isPremiumProvider);
    final rawTxs = ref.watch(allTransactionsProvider).valueOrNull ?? [];

    const freeFilters = ['All', 'Food', 'Travel', 'EMI', 'Shopping', 'Others'];
    const premiumFilters = [
      'All',
      'Income',
      'Expenses',
      'Pending',
      'Premium Alerts',
      'Custom',
    ];
    final filters = isPremium ? premiumFilters : freeFilters;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF4),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium badge
          if (isPremium)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '99% AI Categorized',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Header (free only)
          if (!isPremium)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: const Text(
                  'Activity',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
            ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                onChanged: notifier.search,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
                decoration: const InputDecoration(
                  hintText: 'Search transactions',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9CA3AF),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Color(0xFF9CA3AF),
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Filter chips
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filters.length,
              itemBuilder: (ctx, i) {
                final f = filters[i];
                final isActive = state.selectedFilter == f;
                return GestureDetector(
                  onTap: () => notifier.selectFilter(f),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF2E7D32)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFE5E7EB),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      f,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? Colors.white
                            : const Color(0xFF374151),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Transaction list
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF2E7D32),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _buildItems(state, isPremium).length,
                    itemBuilder: (ctx, i) {
                      final items = _buildItems(state, isPremium);
                      final item = items[i];

                      if (item is _MonthHeader) {
                        return MerchantSectionHeader(label: item.label);
                      } else if (item is TransactionDisplay) {
                        final raw = rawTxs
                            .where((t) => t.id.toString() == item.id)
                            .firstOrNull;
                        return TransactionRow(
                          tx: item,
                          onTap: raw == null
                              ? null
                              : () => showTransactionDetail(
                                    context: context,
                                    ref: ref,
                                    transaction: raw,
                                  ),
                        );
                      } else if (item is AiAlert) {
                        return AiAlertRow(alert: item);
                      } else if (item is String &&
                          item == '__recurring__') {
                        return _buildRecurringSection(state.recurring);
                      }
                      return const SizedBox.shrink();
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'activity_fab',
        backgroundColor: const Color(0xFF2E7D32),
        onPressed: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const NewTransactionScreen(),
          ),
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 24),
      ),
    );
  }

  List<dynamic> _buildItems(ActivityState state, bool isPremium) {
    final items = <dynamic>[];

    if (isPremium) {
      final txs = state.filtered;
      final alerts = state.aiAlerts;

      if (txs.isNotEmpty) items.add(txs[0]);
      if (alerts.isNotEmpty) items.add(alerts[0]);
      if (txs.length > 1) items.add(txs[1]);
      if (alerts.length > 1) items.add(alerts[1]);
      if (txs.length > 2) items.add(txs[2]);
      if (alerts.length > 2) items.add(alerts[2]);
      for (int i = 3; i < txs.length; i++) {
        items.add(txs[i]);
      }
    } else {
      items.addAll(state.filtered);
    }

    if (state.recurring.isNotEmpty) {
      items.add('__recurring__');
    }

    // Insert a month header before the first transaction of each month.
    final result = <dynamic>[];
    DateTime? lastMonth;
    for (final item in items) {
      if (item is TransactionDisplay) {
        final m = DateTime(item.date.year, item.date.month);
        if (m != lastMonth) {
          result.add(_MonthHeader(monthSectionLabel(item.date)));
          lastMonth = m;
        }
      }
      result.add(item);
    }
    return result;
  }

  Widget _buildRecurringSection(List<RecurringPayment> recurring) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recurring Payments',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: recurring.length,
              itemBuilder: (ctx, i) =>
                  RecurringPaymentCard(payment: recurring[i]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Marker for a month section header in the activity list (e.g. "JUNE 2026").
class _MonthHeader {
  final String label;
  const _MonthHeader(this.label);
}
