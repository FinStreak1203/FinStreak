import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/bank_assets.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/services/category_classifier.dart';
import '../../../../core/services/email_parser_service.dart' show ParsedTransaction;
import '../../../../core/services/sms_service.dart';
import '../../../accounts/models/bank_model.dart';
import '../../../transactions/presentation/widgets/bank_logo.dart';

const _kGreen = Color(0xFF2E7D32);
const _kBg = Color(0xFFF7FAF4);

enum _Stage { permission, loading, results, empty, importing, success, denied }

class _Selectable {
  final ParsedTransaction tx;
  bool selected = true;
  _Selectable(this.tx);
}

class SmsImportScreen extends ConsumerStatefulWidget {
  const SmsImportScreen({super.key});

  @override
  ConsumerState<SmsImportScreen> createState() => _SmsImportScreenState();
}

class _SmsImportScreenState extends ConsumerState<SmsImportScreen> {
  _Stage _stage = _Stage.loading;
  List<_Selectable> _items = [];
  int _importedCount = 0;
  DateTime? _selectedDay; // null = last 90 days

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final granted = await ref.read(smsServiceProvider).isGranted();
    if (!mounted) return;
    if (granted) {
      _load();
    } else {
      setState(() => _stage = _Stage.permission);
    }
  }

  Future<void> _requestAccess() async {
    setState(() => _stage = _Stage.loading);
    final granted = await ref.read(smsServiceProvider).requestPermission();
    if (!mounted) return;
    if (granted) {
      _load();
    } else {
      setState(() => _stage = _Stage.denied);
    }
  }

  Future<void> _load() async {
    setState(() => _stage = _Stage.loading);
    try {
      final parsed =
          await ref.read(smsServiceProvider).parseAllBankSMS(day: _selectedDay);
      // Auto-create any new bank accounts these SMS reference (like Gmail).
      await _maybeCreateDetectedAccounts(parsed);
      if (!mounted) return;
      // Dedup: drop SMS already imported (matched by sourceEmailId == smsId).
      final dao = ref.read(transactionDaoProvider);
      final existing = await dao.getAllTransactions();
      final seenIds = existing
          .map((t) => t.sourceEmailId)
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toSet();
      // Cross-source dedup: a reference already imported from EMAIL or SMS.
      final seenRefs = existing
          .map((t) => t.upiRef)
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toSet();
      // Content signatures of already-imported rows — for txns without a ref.
      final seenContent = existing
          .map((t) => _contentKey(t.type, t.amount, t.date, t.payee, t.cardNumber))
          .toSet();
      // Mandates already saved (deduped by their UMN).
      final seenUmns = (await ref.read(recurringDaoProvider).getAll())
          .map((m) => m.umn)
          .where((s) => s.isNotEmpty)
          .toSet();
      // Keep new items only — skip ones already imported (by id / ref / UMN)
      // and collapse in-batch duplicates (a transaction shares a upiRef; a
      // mandate shares its UMN, carried in upiVpa).
      final fresh = <ParsedTransaction>[];
      final batchKeys = <String>{};
      for (final t in parsed) {
        if (seenIds.contains(t.emailId)) continue;
        if (t.category == 'UPI Mandate Setup') {
          final umn = t.upiVpa ?? '';
          if (umn.isNotEmpty &&
              (seenUmns.contains(umn) || !batchKeys.add('umn:$umn'))) {
            continue;
          }
        } else {
          final r = t.upiRef;
          if (r != null && r.isNotEmpty) {
            if (seenRefs.contains(r) || !batchKeys.add('ref:$r')) continue;
          } else {
            // No reference (e.g. a card "spent" alert) — dedup by a content
            // signature so the same transaction can't appear multiple times.
            final ck = _contentKey(
                t.type, t.amount, t.date, t.merchant, t.accountNumber);
            if (seenContent.contains(ck) || !batchKeys.add('content:$ck')) {
              continue;
            }
          }
        }
        fresh.add(t);
      }

      if (!mounted) return;
      setState(() {
        _items = fresh.map((t) => _Selectable(t)).toList();
        _stage = fresh.isEmpty ? _Stage.empty : _Stage.results;
      });
    } catch (_) {
      if (mounted) setState(() => _stage = _Stage.empty);
    }
  }

  /// Creates any bank accounts referenced by [parsed] that aren't in the DB
  /// yet (same flow as the Gmail import). Deduped by bank + masked number, so
  /// re-scanning or an already-imported account never adds a duplicate.
  Future<void> _maybeCreateDetectedAccounts(
      List<ParsedTransaction> parsed) async {
    final accountDao = ref.read(accountDaoProvider);
    final seen = <String>{};
    var created = 0;
    for (final t in parsed) {
      final number = t.accountNumber;
      if (number == null || number.isEmpty) continue;
      final key = '${t.bankName.toLowerCase()}_${number.toLowerCase()}';
      if (!seen.add(key)) continue; // de-dupe within this batch
      if (await accountDao.findByBankAndNumber(t.bankName, number) != null) {
        continue; // already exists (incl. accounts from the Gmail import)
      }
      try {
        await accountDao.insertAccount(
          AccountsCompanion.insert(
            name: '${t.bankName} $number',
            type: t.accountType == 'credit_card' ? 'credit_card' : 'bank',
            balance: 0,
            bankName: Value(t.bankName),
            accountNumber: Value(number),
            imagePath: Value(BankAssets.getImagePath(t.bankName)),
          ),
        );
        created++;
      } catch (_) {
        // Skip a failed account; the rest still proceed.
      }
    }
    if (created > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $created new account${created == 1 ? '' : 's'}'),
          backgroundColor: _kGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  int get _selectedCount => _items.where((s) => s.selected).length;

  /// A content signature used to dedup transactions that carry no UPI
  /// reference (e.g. card "spent" alerts). Kept comparable across the parsed
  /// model (merchant / accountNumber) and the stored row (payee / cardNumber).
  String _contentKey(String type, double amount, DateTime date, String? merchant,
      String? acct) {
    final m = (merchant ?? '').toLowerCase().trim();
    final a = (acct ?? '').toLowerCase().trim();
    return '$type|${amount.toStringAsFixed(2)}|'
        '${date.year}-${date.month}-${date.day}|$m|$a';
  }

  /// Persists the UPI reference and VPA in the memo (no dedicated columns).
  String _buildMemo(ParsedTransaction t) {
    final parts = <String>[];
    if (t.upiRef != null && t.upiRef!.isNotEmpty) parts.add('Ref: ${t.upiRef}');
    if (t.upiVpa != null && t.upiVpa!.isNotEmpty) parts.add(t.upiVpa!);
    return parts.isEmpty ? 'Imported from SMS' : parts.join(' · ');
  }

  Future<void> _import() async {
    final selected = _items.where((s) => s.selected).toList();
    if (selected.isEmpty) return;
    setState(() => _stage = _Stage.importing);

    final dao = ref.read(transactionDaoProvider);
    final accountDao = ref.read(accountDaoProvider);
    final recurringDao = ref.read(recurringDaoProvider);

    // Re-read existing dedup keys (in case of re-entry). Tracks both the SMS/
    // email id and the reference, so the same txn can't import from both.
    final seen = <String>{};
    final seenRefs = <String>{};
    final seenContent = <String>{};
    try {
      for (final t in await dao.getAllTransactions()) {
        if (t.sourceEmailId != null && t.sourceEmailId!.isNotEmpty) {
          seen.add(t.sourceEmailId!);
        }
        if (t.upiRef != null && t.upiRef!.isNotEmpty) {
          seenRefs.add(t.upiRef!);
        }
        seenContent
            .add(_contentKey(t.type, t.amount, t.date, t.payee, t.cardNumber));
      }
    } catch (_) {}

    var count = 0;
    for (final s in selected) {
      try {
        final t = s.tx;

        // Mandate setup → Recurring Payments list (NOT an expense / txn).
        if (t.category == 'UPI Mandate Setup') {
          final added = await recurringDao.addIfNew(
            name: (t.merchant != null && t.merchant!.isNotEmpty)
                ? t.merchant!
                : t.bankName,
            amount: t.amount,
            bankName: t.bankName,
            umn: t.upiVpa ?? '',
          );
          if (added) count++;
          continue;
        }

        if (seen.contains(t.emailId)) continue;
        final ref = t.upiRef;
        final ck =
            _contentKey(t.type, t.amount, t.date, t.merchant, t.accountNumber);
        if (ref != null && ref.isNotEmpty) {
          if (seenRefs.contains(ref)) continue;
        } else if (seenContent.contains(ck)) {
          // No reference — skip a duplicate by content signature.
          continue;
        }
        // Mark seen so in-batch duplicates can't insert twice.
        seen.add(t.emailId);
        if (ref != null && ref.isNotEmpty) seenRefs.add(ref);
        seenContent.add(ck);

        final account =
            await accountDao.findByBankAndNumber(t.bankName, t.accountNumber);
        final accountId = account?.id.toString() ??
            t.bankName.toLowerCase().replaceAll(' ', '_');
        final accountName = account?.name ?? t.bankName;

        // Offline categorisation (same matcher as the email import).
        var categoryId = 'other';
        var categoryName =
            (t.category != null && t.category!.isNotEmpty) ? t.category! : 'Other';
        final cat = CategoryClassifier.classify(t.merchant);
        if (cat != null) {
          categoryId = cat.id;
          categoryName = cat.name;
        }

        await dao.insertTransaction(
          TransactionsCompanion.insert(
            type: t.type,
            amount: t.amount,
            categoryId: categoryId,
            categoryName: categoryName,
            accountId: accountId,
            accountName: accountName,
            date: t.date,
            payee: Value(t.merchant ?? ''),
            memo: Value(_buildMemo(t)),
            sourceEmailId: Value(t.emailId),
            upiRef: Value(t.upiRef),
            instrumentType: Value(t.instrumentType),
            cardNumber: Value(t.accountNumber),
            isRecurring: Value(t.isRecurring),
            currency: Value(t.currency),
            source: const Value('sms'),
          ),
        );
        seen.add(t.emailId);
        if (t.upiRef != null && t.upiRef!.isNotEmpty) seenRefs.add(t.upiRef!);
        count++;
      } catch (_) {
        // skip a failed row; continue
      }
    }

    if (!mounted) return;
    setState(() {
      _importedCount = count;
      _stage = _Stage.success;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('SMS Import',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E7D32))),
            SizedBox(width: 6),
            Text('📱', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
      body: switch (_stage) {
        _Stage.permission => _PermissionView(onAllow: _requestAccess),
        _Stage.denied => _DeniedView(onRetry: _requestAccess),
        _Stage.loading => const _LoadingView(),
        _Stage.importing => const _LoadingView(message: 'Importing...'),
        _Stage.empty => Column(
            children: [
              _dateFilterBar(),
              Expanded(child: _EmptyView(onRetry: _load)),
            ],
          ),
        _Stage.success => _SuccessView(
            count: _importedCount,
            onView: () => context.go(RouteNames.activity),
          ),
        _Stage.results => _buildResults(),
      },
    );
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _kGreen),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() =>
        _selectedDay = DateTime(picked.year, picked.month, picked.day));
    _load();
  }

  void _clearDay() {
    if (_selectedDay == null) return;
    setState(() => _selectedDay = null);
    _load();
  }

  /// Chip row: tap to pick a day, ✕ to return to the last-90-days default.
  Widget _dateFilterBar() {
    final d = _selectedDay;
    final label =
        d == null ? 'Last 90 days' : '${d.day} ${_months[d.month]} ${d.year}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Row(
        children: [
          InkWell(
            onTap: _pickDay,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0EC),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 15, color: _kGreen),
                  const SizedBox(width: 6),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _kGreen)),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more_rounded,
                      size: 16, color: _kGreen),
                ],
              ),
            ),
          ),
          if (d != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: _clearDay,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded,
                    size: 18, color: Color(0xFF9CA3AF)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResults() {
    return Column(
      children: [
        _dateFilterBar(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Flexible(
                child: Text('${_items.length} transactions found',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827))),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  for (final s in _items) {
                    s.selected = true;
                  }
                }),
                child: const Text('Select All',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kGreen)),
              ),
              TextButton(
                onPressed: () => setState(() {
                  for (final s in _items) {
                    s.selected = false;
                  }
                }),
                child: const Text('Deselect',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280))),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            itemCount: _items.length,
            itemBuilder: (_, i) => _row(_items[i]),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _selectedCount > 0 ? _import : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  disabledBackgroundColor: const Color(0xFF9CA3AF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text('Import Selected ($_selectedCount)',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(_Selectable s) {
    final t = s.tx;
    final isIncome = t.type == 'income';
    final logo = bankImagePathForName(t.bankName);
    final months = const [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateLabel = '${months[t.date.month]} ${t.date.day}';
    final label = (t.merchant != null && t.merchant!.trim().isNotEmpty)
        ? t.merchant!.trim()
        : t.bankName;

    return GestureDetector(
      onTap: () => setState(() => s.selected = !s.selected),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: s.selected ? _kGreen : const Color(0xFFEFF1F0),
              width: s.selected ? 1.4 : 1),
        ),
        child: Row(
          children: [
            Icon(
              s.selected
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              color: s.selected ? _kGreen : const Color(0xFFD1D5DB),
              size: 22,
            ),
            const SizedBox(width: 10),
            // Bank logo on the left (same as the email import rows).
            if (logo != null)
              BankLogo(imagePath: logo, size: 38)
            else
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance_rounded,
                    size: 20, color: Color(0xFF6B7280)),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827))),
                  const SizedBox(height: 3),
                  Text('${t.bankName} · $dateLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF))),
                  if (t.accountNumber != null && t.accountNumber!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      t.accountType == 'credit_card'
                          ? 'Credit Card ${t.accountNumber}'
                          : 'A/c ${t.accountNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${isIncome ? '+' : '-'}₹${t.amount.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isIncome
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFEF4444)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stage views ───────────────────────────────────────────────
class _PermissionView extends StatelessWidget {
  final VoidCallback onAllow;
  const _PermissionView({required this.onAllow});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📱', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 20),
          const Text('Import from SMS',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827))),
          const SizedBox(height: 10),
          const Text(
            'Finella reads only bank transaction SMS messages. '
            'Personal messages are never accessed.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, height: 1.5, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onAllow,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Allow SMS Access',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeniedView extends StatelessWidget {
  final VoidCallback onRetry;
  const _DeniedView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sms_failed_outlined,
              size: 56, color: Color(0xFFD1D5DB)),
          const SizedBox(height: 16),
          const Text('SMS permission denied',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151))),
          const SizedBox(height: 6),
          const Text(
            'Enable SMS permission in system settings to import transactions.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: _kGreen,
              side: const BorderSide(color: _kGreen, width: 1.4),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  final String message;
  const _LoadingView({this.message = 'Reading bank SMS...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: _kGreen),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151))),
          const SizedBox(height: 4),
          const Text('Last 30 days',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 56, color: Color(0xFFD1D5DB)),
          const SizedBox(height: 12),
          const Text('No new bank SMS',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280))),
          const SizedBox(height: 4),
          const Text('From the last 30 days',
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: const Text('Refresh')),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final int count;
  final VoidCallback onView;
  const _SuccessView({required this.count, required this.onView});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded, size: 72, color: _kGreen),
          const SizedBox(height: 16),
          Text('$count transaction${count == 1 ? '' : 's'} imported!',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827))),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onView,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('View Transactions',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
