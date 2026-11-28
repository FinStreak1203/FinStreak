import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/bank_assets.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/services/category_classifier.dart';
import '../../../../core/services/email_parser_service.dart';
import '../../../../core/services/gmail_auth_service.dart';
import '../../../../core/services/gmail_service.dart';
import '../../../../shared/widgets/merchant_transaction_row.dart';
import '../../../accounts/models/bank_model.dart';
import '../../models/detected_account.dart';

const _kPrimary = Color(0xFF2E7D32);
const _kDarkGreen = Color(0xFF0A3D2E);
const _kBg = Color(0xFFF7FAF4);

enum _Stage { connect, loading, results, empty, importing, success, error }

class _Selectable {
  final ParsedTransaction tx;
  bool selected;
  _Selectable(this.tx) : selected = true;
}

class EmailImportScreen extends ConsumerStatefulWidget {
  const EmailImportScreen({super.key});

  @override
  ConsumerState<EmailImportScreen> createState() => _EmailImportScreenState();
}

class _EmailImportScreenState extends ConsumerState<EmailImportScreen> {
  _Stage _stage = _Stage.connect;
  List<_Selectable> _items = [];
  int _importedCount = 0;
  DateTime? _selectedDay; // null = last 90 days

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final connected =
        await ref.read(gmailAuthServiceProvider).isGmailConnected();
    if (!mounted) return;
    if (connected) {
      _loadEmails();
    } else {
      setState(() => _stage = _Stage.connect);
    }
  }

  Future<void> _connect() async {
    setState(() => _stage = _Stage.loading);
    final granted =
        await ref.read(gmailAuthServiceProvider).requestGmailPermission();
    if (!mounted) return;
    if (granted) {
      ref.invalidate(gmailConnectedProvider); // refresh Settings badge
      _loadEmails();
    } else {
      setState(() => _stage = _Stage.connect);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gmail access was not granted'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    await ref.read(gmailAuthServiceProvider).revokeGmailPermission();
    ref.invalidate(gmailConnectedProvider); // refresh Settings badge
    if (!mounted) return;
    setState(() {
      _items = [];
      _stage = _Stage.connect;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gmail disconnected'),
        backgroundColor: Color(0xFF6B7280),
      ),
    );
  }

  Future<void> _loadEmails() async {
    setState(() => _stage = _Stage.loading);
    try {
      final gmail = ref.read(gmailServiceProvider);
      final emails = await gmail.fetchBankEmails(day: _selectedDay);

      // Ids of emails whose imported transaction still exists — the DB is the
      // source of truth. An email is only "already imported" if it's flagged
      // processed AND its transaction is still present; if the user deleted the
      // transaction, treat the email as fresh so it can be re-imported (and
      // self-heal a stale processed flag left by an earlier delete).
      final existingEmailIds = <String>{};
      try {
        for (final t in await ref.read(transactionDaoProvider).getAllTransactions()) {
          final sid = t.sourceEmailId;
          if (sid != null && sid.isNotEmpty) existingEmailIds.add(sid);
        }
      } catch (_) {}

      final fresh = <Map<String, dynamic>>[];
      for (final e in emails) {
        final id = (e['id'] ?? '').toString();
        if (id.isEmpty) continue;
        if (existingEmailIds.contains(id)) continue; // already imported & kept
        if (await gmail.isAlreadyProcessed(id)) {
          // Flagged processed but no transaction exists → it was deleted.
          // Clear the orphaned flag and re-offer it.
          await gmail.clearProcessed(id);
        }
        fresh.add(e);
      }

      final parsed = ref.read(emailParserServiceProvider).parseAll(fresh);
      if (!mounted) return;
      if (parsed.isEmpty) {
        setState(() => _stage = _Stage.empty);
        return;
      }

      // Offer to create any new accounts these transactions reference.
      await _maybeCreateDetectedAccounts(parsed);
      if (!mounted) return;

      setState(() {
        _items = parsed.map((t) => _Selectable(t)).toList();
        _stage = _Stage.results;
      });
    } catch (_) {
      if (mounted) setState(() => _stage = _Stage.error);
    }
  }

  /// Detects accounts referenced by [parsed] that aren't in the DB yet and
  /// creates them automatically, so every imported transaction links to a real
  /// account (and shows up bank-wise on the Accounts screen). A brief snackbar
  /// reports how many were added.
  Future<void> _maybeCreateDetectedAccounts(
      List<ParsedTransaction> parsed) async {
    final accountDao = ref.read(accountDaoProvider);

    final seen = <String>{};
    final newAccounts = <DetectedAccount>[];
    for (final t in parsed) {
      final number = t.accountNumber;
      if (number == null || number.isEmpty) continue;
      final key = '${t.bankName}_$number';
      if (!seen.add(key)) continue;

      final exists = await accountDao.findByBankAndNumber(t.bankName, number);
      if (exists != null) continue;

      newAccounts.add(DetectedAccount(
        bankName: t.bankName,
        accountNumber: number,
        accountType: t.accountType ?? 'bank',
        imagePath: BankAssets.getImagePath(t.bankName),
      ));
    }

    if (newAccounts.isEmpty) return;

    var created = 0;
    for (final a in newAccounts) {
      try {
        await accountDao.insertAccount(
          AccountsCompanion.insert(
            name: a.displayName, // "HDFC XX0229"
            type: a.accountType,
            balance: 0,
            bankName: Value(a.bankName),
            accountNumber: Value(a.accountNumber),
            imagePath: Value(a.imagePath),
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
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _import() async {
    final selected = _items.where((s) => s.selected).toList();
    if (selected.isEmpty) return;
    setState(() => _stage = _Stage.importing);

    final dao = ref.read(transactionDaoProvider);
    final accountDao = ref.read(accountDaoProvider);
    final gmail = ref.read(gmailServiceProvider);

    debugPrint('=== SAVING TO FIRESTORE ===');
    debugPrint('Transaction count: ${selected.length}');
    debugPrint('UID: ${ref.read(currentUidProvider)}');

    // Content-level dedup: collect UPI refs already in the DB so we don't import
    // the same transaction twice (also covers the same alert arriving twice).
    final seenUpiRefs = <String>{};
    try {
      final existing = await dao.getAllTransactions();
      for (final tx in existing) {
        if (tx.upiRef != null && tx.upiRef!.isNotEmpty) {
          seenUpiRefs.add(tx.upiRef!);
        }
      }
    } catch (_) {
      // If the lookup fails, fall back to the email-id dedup only.
    }

    var count = 0;
    var skipped = 0;
    for (final s in selected) {
      try {
        final t = s.tx;
        final ref0 = t.upiRef;

        // Skip if a transaction with this UPI reference already exists.
        if (ref0 != null && ref0.isNotEmpty && seenUpiRefs.contains(ref0)) {
          debugPrint('Skipped duplicate (UPI $ref0)');
          await gmail.markAsProcessed(t.emailId); // don't re-fetch it
          skipped++;
          continue;
        }

        // Link to the matching account if one exists (auto-created or manual),
        // otherwise fall back to a label derived from the bank/card.
        final account =
            await accountDao.findByBankAndNumber(t.bankName, t.accountNumber);
        final accountId = account?.id.toString() ??
            t.accountDisplayName.toLowerCase().replaceAll(' ', '_');
        final accountName = account?.name ?? t.accountDisplayName;

        // Offline categorisation: match the merchant against the local rules
        // so the transaction shows the right icon/colour (icons resolve from
        // categoryId). No match → keep the parser's label + generic 'other'.
        final parserCategory = (t.category != null && t.category!.isNotEmpty)
            ? t.category!
            : 'Other';
        var categoryId = 'other';
        var categoryName = parserCategory;
        final localCat = CategoryClassifier.classify(t.merchant);
        if (localCat != null) {
          categoryId = localCat.id;
          categoryName = localCat.name;
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
            upiRef: Value(ref0),
            instrumentType: Value(t.instrumentType),
            cardNumber: Value(t.accountNumber),
            isRecurring: Value(t.isRecurring),
            currency: Value(t.currency),
          ),
        );
        if (ref0 != null && ref0.isNotEmpty) seenUpiRefs.add(ref0);
        await gmail.markAsProcessed(t.emailId);
        count++;
      } catch (e) {
        debugPrint('Firestore save error for one row: $e ❌');
      }
    }
    debugPrint('=== SAVED TO FIRESTORE ✅ === '
        '($count saved, $skipped duplicate of ${selected.length})');
    if (!mounted) return;
    setState(() {
      _importedCount = count;
      _stage = _Stage.success;
    });
  }

  /// Combines the card number and UPI reference into the saved memo so both are
  /// persisted on the transaction.
  String _buildMemo(ParsedTransaction t) {
    final parts = <String>[];
    if (t.accountNumber != null && t.accountNumber!.isNotEmpty) {
      parts.add('Card ${t.accountNumber}');
    }
    if (t.memo != null && t.memo!.isNotEmpty) {
      parts.add(t.memo!);
    }
    return parts.isEmpty ? 'Imported from Gmail' : parts.join(' · ');
  }

  int get _selectedCount => _items.where((s) => s.selected).length;

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
        title: const Text(
          'Email Import',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2E7D32),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: Color(0xFF111827)),
            onSelected: (v) {
              if (v == 'disconnect') _disconnect();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'disconnect',
                child: Row(
                  children: [
                    Icon(Icons.link_off_rounded,
                        size: 18, color: Color(0xFFEF4444)),
                    SizedBox(width: 10),
                    Text('Disconnect Gmail'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: switch (_stage) {
        _Stage.connect => _ConnectView(onConnect: _connect),
        _Stage.loading => const _LoadingView(message: 'Reading bank emails...'),
        _Stage.importing =>
          const _LoadingView(message: 'Importing transactions...'),
        _Stage.empty => Column(
            children: [
              _dateFilterBar(),
              Expanded(
                child: _EmptyView(
                  onRetry: _loadEmails,
                  subtitle: _selectedDay == null
                      ? 'From the last 90 days'
                      : 'On ${_selectedDay!.day} ${_months[_selectedDay!.month]} ${_selectedDay!.year}',
                ),
              ),
            ],
          ),
        _Stage.error => _ErrorView(onRetry: _loadEmails),
        _Stage.results => _buildResults(),
        _Stage.success => _SuccessView(
            count: _importedCount,
            onView: () => context.go(RouteNames.activity),
          ),
      },
    );
  }

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _kPrimary),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() =>
        _selectedDay = DateTime(picked.year, picked.month, picked.day));
    _loadEmails();
  }

  void _clearDay() {
    if (_selectedDay == null) return;
    setState(() => _selectedDay = null);
    _loadEmails();
  }

  /// Chip row: tap to pick a day, ✕ to go back to the last-30-days default.
  Widget _dateFilterBar() {
    final d = _selectedDay;
    final label = d == null
        ? 'Last 90 days'
        : '${d.day} ${_months[d.month]} ${d.year}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Row(
        children: [
          InkWell(
            onTap: _pickDay,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0EC),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 15, color: _kPrimary),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more_rounded,
                      size: 16, color: _kPrimary),
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

  /// Parsed transactions sorted newest-first, with a month-label string
  /// inserted before the first transaction of each month.
  List<Object> _groupedItems() {
    final sorted = [..._items]
      ..sort((a, b) => b.tx.date.compareTo(a.tx.date));
    final out = <Object>[];
    DateTime? lastMonth;
    for (final s in sorted) {
      final m = DateTime(s.tx.date.year, s.tx.date.month);
      if (m != lastMonth) {
        out.add(monthSectionLabel(s.tx.date));
        lastMonth = m;
      }
      out.add(s);
    }
    return out;
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
                child: Text(
                  '${_items.length} transactions found',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
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
                        color: _kPrimary, fontWeight: FontWeight.w700)),
              ),
              TextButton(
                onPressed: () => setState(() {
                  for (final s in _items) {
                    s.selected = false;
                  }
                }),
                child: const Text('Deselect',
                    style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.white,
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _groupedItems().length,
              itemBuilder: (_, i) {
                final item = _groupedItems()[i];
                if (item is String) {
                  return MerchantSectionHeader(label: item);
                }
                final s = item as _Selectable;
                return _TxRow(
                  item: s,
                  onChanged: (v) => setState(() => s.selected = v),
                );
              },
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _selectedCount > 0 ? _import : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  disabledBackgroundColor: const Color(0xFF9CA3AF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  'Import Selected ($_selectedCount)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Stage views ───────────────────────────────────────────────
class _ConnectView extends StatelessWidget {
  final VoidCallback onConnect;
  const _ConnectView({required this.onConnect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F0EC),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mark_email_read_outlined,
                size: 48, color: _kPrimary),
          ),
          const SizedBox(height: 24),
          const Text(
            'Import from Gmail',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'FinStreak will read only bank transaction emails. '
            'Personal emails are never accessed.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: onConnect,
              icon: const Icon(Icons.link_rounded, color: Colors.white),
              label: const Text(
                'Connect Gmail Account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  final String message;
  const _LoadingView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: _kPrimary),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onRetry;
  final String subtitle;
  const _EmptyView({required this.onRetry, this.subtitle = 'From the last 90 days'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 56, color: Color(0xFFD1D5DB)),
          const SizedBox(height: 16),
          const Text('No new bank transactions found',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280))),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 20),
          TextButton(
            onPressed: onRetry,
            child: const Text('Check again',
                style: TextStyle(color: _kPrimary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 56, color: Color(0xFFEF4444)),
          const SizedBox(height: 16),
          const Text('Could not read your emails',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280))),
          const SizedBox(height: 20),
          TextButton(
            onPressed: onRetry,
            child: const Text('Try again',
                style: TextStyle(color: _kPrimary, fontWeight: FontWeight.w700)),
          ),
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                size: 56, color: _kPrimary),
          ),
          const SizedBox(height: 24),
          Text(
            '$count transaction${count == 1 ? '' : 's'} imported!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: onView,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kDarkGreen,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text(
                'View Transactions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Selectable transaction row ────────────────────────────────
class _TxRow extends StatelessWidget {
  final _Selectable item;
  final ValueChanged<bool> onChanged;
  const _TxRow({required this.item, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = item.tx;
    final name =
        t.merchant?.isNotEmpty == true ? t.merchant! : t.accountDisplayName;
    // Line 2 = bank name; line 3 = account / card number.
    final acct = t.accountNumber;
    final subtitle = (acct != null && acct.isNotEmpty)
        ? (t.accountType == 'credit_card' ? 'Credit Card $acct' : 'A/c $acct')
        : null;

    return MerchantTransactionRow(
      name: name,
      category: t.bankName,
      subtitle: subtitle,
      amount: t.amount,
      currency: t.currency,
      isIncome: t.type == 'income',
      date: t.date,
      logoAsset: bankImagePathForName(t.bankName),
      source: 'email',
      redExpense: true, // debit → red, credit → green
      onTap: () => onChanged(!item.selected),
      leading: SizedBox(
        width: 28,
        height: 28,
        child: Checkbox(
          value: item.selected,
          onChanged: (v) => onChanged(v ?? false),
          activeColor: _kPrimary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
