import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/category_options.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/category_dao.dart';
import '../../../core/database/recurring_dao.dart';
import '../../../core/providers/database_providers.dart';
import '../../transactions/presentation/category_picker_sheet.dart';
import '../models/activity_models.dart';

class ActivityState {
  final String selectedFilter;
  final String searchQuery;
  final List<TransactionDisplay> allTransactions;
  final List<TransactionDisplay> filtered;
  final List<RecurringPayment> recurring;
  final List<AiAlert> aiAlerts;
  final bool isLoading;

  const ActivityState({
    this.selectedFilter = 'All',
    this.searchQuery = '',
    this.allTransactions = const [],
    this.filtered = const [],
    this.recurring = const [],
    this.aiAlerts = const [],
    this.isLoading = true,
  });

  ActivityState copyWith({
    String? selectedFilter,
    String? searchQuery,
    List<TransactionDisplay>? allTransactions,
    List<TransactionDisplay>? filtered,
    List<RecurringPayment>? recurring,
    List<AiAlert>? aiAlerts,
    bool? isLoading,
  }) =>
      ActivityState(
        selectedFilter: selectedFilter ?? this.selectedFilter,
        searchQuery: searchQuery ?? this.searchQuery,
        allTransactions: allTransactions ?? this.allTransactions,
        filtered: filtered ?? this.filtered,
        recurring: recurring ?? this.recurring,
        aiAlerts: aiAlerts ?? this.aiAlerts,
        isLoading: isLoading ?? this.isLoading,
      );
}

class ActivityNotifier extends StateNotifier<ActivityState> {
  final Ref _ref;
  List<Transaction> _lastTxs = const [];
  List<RecurringMandate> _mandates = const [];
  Map<String, CustomCategory> _customById = const {};

  ActivityNotifier(this._ref) : super(const ActivityState()) {
    _ref.listen<AsyncValue<List<Transaction>>>(
      allTransactionsProvider,
      (_, next) => next.whenData(_setTransactions),
      fireImmediately: true,
    );
    // Custom categories drive the icon/colour of rows using a user category.
    _ref.listen<AsyncValue<List<CustomCategory>>>(
      customCategoriesProvider,
      (_, next) => next.whenData((cats) {
        _customById = {for (final c in cats) c.id: c};
        if (_lastTxs.isNotEmpty) _setTransactions(_lastTxs);
      }),
      fireImmediately: true,
    );
    _ref.listen<AsyncValue<List<RecurringMandate>>>(
      recurringMandatesProvider,
      (_, next) => next.whenData((m) {
        _mandates = m;
        _rebuildRecurring();
      }),
      fireImmediately: true,
    );
    _loadStaticData();
  }

  void _loadStaticData() {
    state = state.copyWith(
      aiAlerts: const [
        AiAlert(
          type: AiAlertType.anomaly,
          title: 'Anomaly Detected:',
          body: '₹8,500 charged at unknown merchant - Tap to review',
        ),
        AiAlert(
          type: AiAlertType.subscription,
          title: 'Subscription Intelligence:',
          body: '3 unused subscriptions costing ₹1,200/month',
        ),
        AiAlert(
          type: AiAlertType.duplicate,
          title: 'Duplicate Payment:',
          body: 'Netflix charged twice this month (₹499 x2)',
        ),
      ],
    );
  }

  void _setTransactions(List<Transaction> txs) {
    _lastTxs = txs;
    // Map each transfer's ref → destination account name (from the _in row),
    // so the displayed transfer_out row can show "From → To".
    final transferDest = <String, String>{};
    for (final t in txs) {
      if (t.type == 'transfer_in' && t.transferRef != null) {
        transferDest[t.transferRef!] = t.accountName;
      }
    }

    final displays = txs
        // Show only the transfer_out side; hide transfer_in to avoid dupes.
        .where((t) => t.type != 'transfer_in')
        .map((t) => _toDisplay(t, transferDest))
        .toList();
    final filtered = _applyFilter(displays, state.selectedFilter, state.searchQuery);
    state = state.copyWith(
      allTransactions: displays,
      filtered: filtered,
      isLoading: false,
    );
    _rebuildRecurring();
  }

  /// Recurring Payments list = set-up mandates (subscriptions) + distinct
  /// actual recurring debits. Rebuilt whenever mandates or transactions change.
  void _rebuildRecurring() {
    final cards = <RecurringPayment>[];
    final seen = <String>{};

    // 1. Standing mandates (no debit yet — the subscriptions you authorised).
    for (final m in _mandates) {
      final name = m.name.isNotEmpty ? m.name : m.bankName;
      if (!seen.add(name.toLowerCase())) continue;
      cards.add(RecurringPayment(
        name: name,
        description: 'UPI Mandate · ${m.bankName}',
        amount: m.amount,
        nextPayment: 'Auto-pay',
        brandColor: _brandColor(name),
        brandInitial: _initial(name),
      ));
    }

    // 2. Actual recurring debits (EMI / autopay that already charged).
    for (final t in _lastTxs) {
      if (!t.isRecurring || t.type != 'expense') continue;
      final name = t.payee.isNotEmpty ? t.payee : t.categoryName;
      if (!seen.add(name.toLowerCase())) continue;
      cards.add(RecurringPayment(
        name: name,
        description: 'Recurring · ${t.accountName}',
        amount: t.amount,
        nextPayment: 'Monthly',
        brandColor: _brandColor(name),
        brandInitial: _initial(name),
      ));
    }

    state = state.copyWith(recurring: cards);
  }

  static const _palette = [
    Color(0xFFEF4444), Color(0xFF22C55E), Color(0xFF3B82F6),
    Color(0xFF7C3AED), Color(0xFFF59E0B), Color(0xFF14B8A6),
  ];
  Color _brandColor(String s) =>
      _palette[s.isEmpty ? 0 : s.codeUnits.fold(0, (a, c) => a + c) % _palette.length];
  String _initial(String s) => s.isNotEmpty ? s[0].toUpperCase() : '?';

  TransactionDisplay _toDisplay(Transaction t, Map<String, String> transferDest) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateLabel = '${months[t.date.month]} ${t.date.day}';

    // 'sms' is explicit; 'email' is inferred from an import provenance id;
    // everything else is manual (no badge).
    final String? source = t.source == 'sms'
        ? 'sms'
        : ((t.sourceEmailId != null && t.sourceEmailId!.isNotEmpty)
            ? 'email'
            : null);

    if (t.type == 'transfer_out') {
      return TransactionDisplay(
        id: t.id.toString(),
        name: 'Transfer',
        category: 'Transfer',
        account: t.accountName,
        dateLabel: dateLabel,
        date: t.date,
        amount: t.amount,
        isIncome: false,
        iconBg: const Color(0xFFE3F0FC),
        icon: Icons.swap_horiz_rounded,
        isTransfer: true,
        transferTo: t.transferRef != null ? transferDest[t.transferRef!] : null,
        source: source,
        currency: t.currency,
      );
    }

    IconData icon = Icons.more_horiz_rounded;
    Color iconBg = const Color(0xFFF3F4F6);

    final custom = _customById[t.categoryId];
    if (custom != null) {
      icon = categoryIconFor(custom.iconKey);
      iconBg = categoryColorFor(custom.colorKey).bg;
    } else if (t.type == 'income') {
      icon = Icons.account_balance_rounded;
      iconBg = const Color(0xFFF0FDF4);
    } else {
      for (final cat in allCategories) {
        if (cat.id == t.categoryId) {
          icon = cat.icon;
          iconBg = cat.bgColor;
          break;
        }
      }
    }

    return TransactionDisplay(
      id: t.id.toString(),
      name: t.payee.isNotEmpty ? t.payee : t.categoryName,
      category: t.categoryName,
      account: t.accountName,
      dateLabel: dateLabel,
      date: t.date,
      amount: t.amount,
      isIncome: t.type == 'income',
      iconBg: iconBg,
      icon: icon,
      source: source,
      currency: t.currency,
    );
  }

  List<TransactionDisplay> _applyFilter(
    List<TransactionDisplay> all,
    String filter,
    String query,
  ) {
    var result = all;
    if (filter != 'All') {
      result = result.where((t) {
        switch (filter) {
          case 'Food':
            return t.category.contains('Food');
          case 'Travel':
            return t.category.contains('Travel');
          case 'EMI':
            return t.category.contains('EMI');
          case 'Shopping':
            return t.category.contains('Shopping');
          case 'Income':
            return t.isIncome && !t.isTransfer;
          case 'Expenses':
            return !t.isIncome && !t.isTransfer;
          default:
            return true;
        }
      }).toList();
    }
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      result = result
          .where((t) =>
              t.name.toLowerCase().contains(q) ||
              t.category.toLowerCase().contains(q))
          .toList();
    }
    return result;
  }

  void selectFilter(String filter) {
    state = state.copyWith(
      selectedFilter: filter,
      filtered: _applyFilter(state.allTransactions, filter, state.searchQuery),
    );
  }

  void search(String query) {
    state = state.copyWith(
      searchQuery: query,
      filtered: _applyFilter(state.allTransactions, state.selectedFilter, query),
    );
  }
}

final activityProvider =
    StateNotifierProvider<ActivityNotifier, ActivityState>(
  (ref) => ActivityNotifier(ref),
);
