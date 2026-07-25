import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/bank_assets.dart';
import '../../../core/constants/transaction_tags.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/services/category_classifier.dart';
import '../../../core/services/sms_parser_service.dart';
import '../../accounts/models/bank_model.dart';
import 'category_picker_sheet.dart';
import 'widgets/bank_selector_sheet.dart';
import 'widgets/bank_logo.dart';
import 'widgets/tag_selector_sheet.dart';

class NewTransactionScreen extends ConsumerStatefulWidget {
  final Transaction? editTransaction;
  const NewTransactionScreen({super.key, this.editTransaction});

  @override
  ConsumerState<NewTransactionScreen> createState() =>
      _NewTransactionScreenState();
}

class _NewTransactionScreenState
    extends ConsumerState<NewTransactionScreen> {
  String _type = 'expense';
  late TextEditingController _amountCtrl;
  late FocusNode _amountFocus;
  String? _selectedAccountId;
  String? _selectedAccountName;
  String? _selectedAccountImage;
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  // True once the user picks a category by hand — stops payee auto-fill from
  // overriding their choice.
  bool _categoryManuallySet = false;
  DateTime _selectedDate = DateTime.now();
  TransactionTag _selectedTag = defaultTag;
  Account? _fromAccount;
  Account? _toAccount;
  final _payeeCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  // "Quick add from text" — paste a bank SMS / free text to auto-fill.
  final _quickTextCtrl = TextEditingController();

  double get _amount => double.tryParse(_amountCtrl.text) ?? 0;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: '0');
    _amountFocus = FocusNode();

    final tx = widget.editTransaction;
    if (tx != null) {
      _type = tx.type;
      _amountCtrl.text = tx.amount == tx.amount.truncateToDouble()
          ? tx.amount.toInt().toString()
          : tx.amount.toString();
      _selectedAccountId = tx.accountId;
      _selectedAccountName = tx.accountName;
      _selectedAccountImage = bankImagePathFor(tx.accountId);
      _selectedCategoryId = tx.categoryId;
      _selectedCategoryName = tx.categoryName;
      _categoryManuallySet = true; // keep the saved category when editing
      _selectedDate = tx.date;
      _selectedTag = tagById(tx.tag) ?? defaultTag;
      _payeeCtrl.text = tx.payee;
      _memoCtrl.text = tx.memo;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _amountFocus.dispose();
    _payeeCtrl.dispose();
    _memoCtrl.dispose();
    _quickTextCtrl.dispose();
    super.dispose();
  }

  Color get _typeColor => switch (_type) {
        'income' => const Color(0xFF22C55E),
        'transfer' => const Color(0xFF1565C0),
        _ => const Color(0xFFEF4444),
      };

  // ── Pickers ─────────────────────────────────────────────

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF7FAF4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, controller) => CategoryPickerSheet(
          scrollCtrl: controller,
          type: _type,
          onSelect: (id, name) => setState(() {
            _selectedCategoryId = id;
            _selectedCategoryName = name;
            _categoryManuallySet = true;
          }),
        ),
      ),
    );
  }

  void _showAccountPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => BankSelectorSheet(
        onSelect: (id, name, imagePath) => setState(() {
          _selectedAccountId = id;
          _selectedAccountName = name;
          _selectedAccountImage = imagePath;
        }),
      ),
    );
  }

  Account? _accountById(String id) {
    final accounts = ref.read(allAccountsProvider).valueOrNull ?? const [];
    for (final a in accounts) {
      if (a.id.toString() == id) return a;
    }
    return null;
  }

  void _showTransferAccountPicker({required bool isFrom}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => BankSelectorSheet(
        // Hide the "From" account from the "To" list (no self-transfer).
        excludeAccountId: isFrom ? null : _fromAccount?.id.toString(),
        onSelect: (id, name, imagePath) {
          final acc = _accountById(id);
          if (acc == null) return;
          setState(() {
            if (isFrom) {
              _fromAccount = acc;
              // Clear "To" if it now collides with the new "From".
              if (_toAccount?.id == acc.id) _toAccount = null;
            } else {
              _toAccount = acc;
            }
          });
        },
      ),
    );
  }

  Future<void> _showTagPicker() async {
    final picked = await showModalBottomSheet<TransactionTag>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TagSelectorSheet(selectedTagId: _selectedTag.id),
    );
    if (picked != null) setState(() => _selectedTag = picked);
  }

  Future<void> _showDatePickerDialog() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
              primary: Color(0xFF2E7D32)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (d.year == yesterday.year &&
        d.month == yesterday.month &&
        d.day == yesterday.day) {
      return 'Yesterday';
    }
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month]} ${d.day}';
  }

  /// Auto-selects a category from the typed payee (e.g. "Swiggy" → Food &
  /// Drink) until the user picks one by hand. Transfers have no category.
  void _onPayeeChanged(String value) {
    if (_categoryManuallySet || _type == 'transfer') return;
    final match = CategoryClassifier.classify(value);
    if (match == null || match.id == _selectedCategoryId) return;
    // Only apply a category that's valid for the current type (e.g. don't put
    // an expense category on an income transaction).
    final pool = _type == 'income' ? incomeCategories : allCategories;
    if (!pool.any((c) => c.id == match.id)) return;
    setState(() {
      _selectedCategoryId = match.id;
      _selectedCategoryName = match.name;
    });
  }

  // ── Quick add from text ─────────────────────────────────

  /// Parses the pasted/typed text with [SmsParserService] and fills the form.
  /// Populates only — the user reviews and taps Save (parsing is best-effort).
  void _autoFillFromText() {
    final text = _quickTextCtrl.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();

    // sender is empty (free text has no DLT id) — parseSMS reads the body for
    // amount / direction / merchant / date.
    final parsed = ref.read(smsParserServiceProvider).parseSMS(
          body: text,
          sender: '',
          smsId: '',
          date: DateTime.now(),
        );
    if (parsed == null || parsed.amount <= 0) {
      _error("Couldn't read a transaction — check the text or fill manually.");
      return;
    }

    setState(() {
      _amountCtrl.text = parsed.amount == parsed.amount.truncateToDouble()
          ? parsed.amount.toInt().toString()
          : parsed.amount.toString();
      // SMS yields expense/income only (never transfer).
      if (parsed.type == 'income' || parsed.type == 'expense') {
        _type = parsed.type;
      }
      _selectedDate = parsed.date;
      _payeeCtrl.text = parsed.merchant ?? '';
      // Reset the category so the classifier can re-pick for this payee/type.
      _categoryManuallySet = false;
      _selectedCategoryId = null;
      _selectedCategoryName = null;
    });
    // Auto-categorise from the merchant (honours the reset flag above).
    _onPayeeChanged(_payeeCtrl.text);
    // Fallback category so Save isn't blocked — a person-to-person transfer has
    // no merchant category. The user can still change it.
    if (_selectedCategoryId == null) {
      setState(() {
        _selectedCategoryId = _type == 'income' ? 'income_other' : 'other';
        _selectedCategoryName = 'Other';
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Filled from text — review & save'),
        backgroundColor: Color(0xFF2E7D32),
        duration: Duration(seconds: 1),
      ),
    );

    // Detect the bank from the text body (the parser can't, with no sender),
    // then select or auto-create the matching account. Fire-and-forget; it
    // updates the Account row + shows a snackbar when a new account is added.
    _resolveAccount(text, parsed.accountNumber);
  }

  /// Bank keyword found in the text → its canonical display name (matches the
  /// names used by the SMS/Email import, so accounts line up). Ordered
  /// specific-first so a short code never shadows a longer phrase.
  static const Map<String, String> _bankNames = {
    'state bank': 'State Bank of India', 'sbi': 'State Bank of India',
    'hdfc': 'HDFC Bank',
    'icici': 'ICICI Bank',
    'axis': 'Axis Bank',
    'kotak': 'Kotak Mahindra Bank',
    'yes bank': 'YES Bank',
    'idbi': 'IDBI Bank',
    'canara': 'Canara Bank',
    'punjab national': 'Punjab National Bank', 'pnb': 'Punjab National Bank',
    'bank of baroda': 'Bank of Baroda',
    'union bank': 'Union Bank of India',
    'indusind': 'IndusInd Bank',
    'idfc': 'IDFC First Bank',
    'federal': 'Federal Bank',
    'rbl': 'RBL Bank',
    'bank of india': 'Bank of India',
    'indian bank': 'Indian Bank',
    'central bank': 'Central Bank of India',
  };

  /// Detects the bank named in [text]. If a matching account exists it's
  /// selected; otherwise the account is created (added to the Accounts screen)
  /// and then selected. [accountNumber] (e.g. "XX7169") is used in the new
  /// account's name when the text carried one.
  Future<void> _resolveAccount(String text, String? accountNumber) async {
    final t = text.toLowerCase();
    String? kw;
    String? bankName;
    for (final e in _bankNames.entries) {
      if (t.contains(e.key)) {
        kw = e.key;
        bankName = e.value;
        break;
      }
    }
    if (bankName == null) return;
    final bank = bankName; // non-null capture (promotion fails inside closures)

    // 1. Already have an account for this bank? Select it.
    final bn = bank.toLowerCase();
    final accounts = ref.read(allAccountsProvider).valueOrNull ?? const [];
    for (final a in accounts) {
      final hay = '${a.name} ${a.bankName ?? ''}'.toLowerCase();
      if (hay.contains(bn) || hay.contains(kw!)) {
        setState(() {
          _selectedAccountId = a.id.toString();
          _selectedAccountName = a.name;
          _selectedAccountImage = bankImagePathForName(a.name);
        });
        return;
      }
    }

    // 2. None exists → create it, then select it.
    final name = (accountNumber != null && accountNumber.isNotEmpty)
        ? '$bank $accountNumber'
        : bank;
    try {
      final id = await ref.read(accountDaoProvider).insertAccount(
            AccountsCompanion.insert(
              name: name,
              type: 'bank',
              balance: 0,
              bankName: Value(bank),
              accountNumber: (accountNumber != null && accountNumber.isNotEmpty)
                  ? Value(accountNumber)
                  : const Value.absent(),
              imagePath: Value(BankAssets.getImagePath(bank)),
            ),
          );
      if (!mounted) return;
      setState(() {
        _selectedAccountId = id.toString();
        _selectedAccountName = name;
        _selectedAccountImage =
            bankImagePathForName(bank) ?? BankAssets.getImagePath(bank);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $bank to your accounts'),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Auto-create account failed: $e');
    }
  }

  // ── Save ────────────────────────────────────────────────

  void _error(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }

  Future<void> _saveTransaction() async {
    if (_type == 'transfer') {
      await _saveTransfer();
      return;
    }

    if (_amount <= 0) return;
    if (_selectedCategoryId == null) {
      _error('Please select a category');
      return;
    }

    final dao = ref.read(transactionDaoProvider);
    final edit = widget.editTransaction;

    if (edit != null) {
      // UPDATE existing transaction — keep id, createdAt, isRecurring
      await dao.updateTransaction(
        edit.copyWith(
          type: _type,
          amount: _amount,
          categoryId: _selectedCategoryId!,
          categoryName: _selectedCategoryName!,
          accountId: _selectedAccountId ?? edit.accountId,
          accountName: _selectedAccountName ?? edit.accountName,
          date: _selectedDate,
          payee: _payeeCtrl.text,
          memo: _memoCtrl.text,
          tag: Value(_type == 'transfer' ? null : _selectedTag.id),
        ),
      );
    } else {
      // INSERT new transaction
      await dao.insertTransaction(
        TransactionsCompanion.insert(
          type: _type,
          amount: _amount,
          categoryId: _selectedCategoryId!,
          categoryName: _selectedCategoryName!,
          accountId: _selectedAccountId ?? 'hdfc',
          accountName: _selectedAccountName ?? 'HDFC',
          date: _selectedDate,
          payee: Value(_payeeCtrl.text),
          memo: Value(_memoCtrl.text),
          tag: Value(_type == 'transfer' ? null : _selectedTag.id),
        ),
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(edit != null ? 'Transaction updated!' : 'Transaction saved!'),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 1),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveTransfer() async {
    // ── Validation ──────────────────────────────────────────
    if (_amount <= 0) {
      _error('Enter an amount greater than 0');
      return;
    }
    if (_fromAccount == null) {
      _error('Please select a "From" account');
      return;
    }
    if (_toAccount == null) {
      _error('Please select a "To" account');
      return;
    }
    if (_fromAccount!.id == _toAccount!.id) {
      _error('From and To accounts cannot be the same');
      return;
    }

    // Soft warning only — user can still proceed.
    if (_amount > _fromAccount!.balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient balance in ${_fromAccount!.name}'),
          backgroundColor: const Color(0xFFF59E0B),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    final dao = ref.read(transactionDaoProvider);
    final ref0 = const Uuid().v4();
    final from = _fromAccount!;
    final to = _toAccount!;
    final memo = _memoCtrl.text;

    // Debit from source.
    await dao.insertTransaction(
      TransactionsCompanion.insert(
        type: 'transfer_out',
        amount: _amount,
        categoryId: 'transfer',
        categoryName: 'Transfer',
        accountId: from.id.toString(),
        accountName: from.name,
        date: _selectedDate,
        memo: Value(memo),
        transferRef: Value(ref0),
      ),
    );
    // Credit to destination.
    await dao.insertTransaction(
      TransactionsCompanion.insert(
        type: 'transfer_in',
        amount: _amount,
        categoryId: 'transfer',
        categoryName: 'Transfer',
        accountId: to.id.toString(),
        accountName: to.name,
        date: _selectedDate,
        memo: Value(memo),
        transferRef: Value(ref0),
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transfer saved!'),
          backgroundColor: Color(0xFF2E7D32),
          duration: Duration(seconds: 1),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(allAccountsProvider).valueOrNull ?? const [];
    // Default the "From" account to the first one once accounts load.
    if (_type == 'transfer' && _fromAccount == null && accounts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _fromAccount == null) {
          setState(() => _fromAccount = accounts.first);
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF4),
      // true so the scroll region shrinks when the keyboard opens and the
      // focused field (e.g. the quick-add text box) scrolls into view above it.
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FAF4),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded,
              color: Color(0xFF111827), size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.editTransaction != null ? 'Edit Transaction' : 'New Transaction',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2E7D32),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Scrollable region shrinks when keyboard opens — no overflow
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
          // ── 1. Type selector ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: const Color(0xFFE5E7EB), width: 1),
              ),
              child: Row(
                children: [
                  // FIX: Expanded is placed HERE, not inside _TypeTab
                  Expanded(
                    child: _TypeTab(
                      label: 'Expense',
                      isActive: _type == 'expense',
                      activeColor: const Color(0xFFEF4444),
                      onTap: () => setState(() {
                        if (_type != 'expense') {
                          _type = 'expense';
                          _selectedCategoryId = null;
                          _selectedCategoryName = null;
                          _categoryManuallySet = false;
                        }
                      }),
                    ),
                  ),
                  Expanded(
                    child: _TypeTab(
                      label: 'Income',
                      isActive: _type == 'income',
                      activeColor: const Color(0xFF22C55E),
                      onTap: () => setState(() {
                        if (_type != 'income') {
                          _type = 'income';
                          _selectedCategoryId = null;
                          _selectedCategoryName = null;
                          _categoryManuallySet = false;
                        }
                      }),
                    ),
                  ),
                  Expanded(
                    child: _TypeTab(
                      label: 'Transfer',
                      isActive: _type == 'transfer',
                      activeColor: const Color(0xFF1565C0),
                      onTap: () => setState(() {
                        if (_type != 'transfer') {
                          _type = 'transfer';
                          _selectedCategoryId = null;
                          _selectedCategoryName = null;
                          _categoryManuallySet = false;
                        }
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 2. Amount display (tappable — opens system keyboard) ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '₹',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: _typeColor.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: TextField(
                    controller: _amountCtrl,
                    focusNode: _amountFocus,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _amountFocus.unfocus(),
                    onTap: () => _amountCtrl.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _amountCtrl.text.length,
                    ),
                    onChanged: (v) {
                      // Keep field non-empty
                      if (v.isEmpty) {
                        _amountCtrl.text = '0';
                        _amountCtrl.selection =
                            const TextSelection.collapsed(offset: 1);
                      }
                      setState(() {}); // refresh save-button state
                    },
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.w700,
                      color: _typeColor,
                      height: 1,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 3. Form card ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border:
                    Border.all(color: const Color(0xFFE5E7EB), width: 1),
              ),
              child: Column(
                children: [
                  if (_type == 'transfer') ...[
                    _FormRow(
                      label: 'From',
                      trailing: _AccountTrailing(account: _fromAccount),
                      onTap: () =>
                          _showTransferAccountPicker(isFrom: true),
                    ),
                    const _RowDivider(),
                    _FormRow(
                      label: 'To',
                      trailing: _AccountTrailing(account: _toAccount),
                      onTap: () =>
                          _showTransferAccountPicker(isFrom: false),
                    ),
                    const _RowDivider(),
                  ] else ...[
                    _FormRow(
                      label: 'Account',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BankLogo(
                            imagePath: _selectedAccountImage ??
                                bankImagePathFor('hdfc')!,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedAccountName ?? 'HDFC',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right,
                              size: 18, color: Color(0xFF9CA3AF)),
                        ],
                      ),
                      onTap: _showAccountPicker,
                    ),
                    const _RowDivider(),
                    _FormRow(
                      label: 'Category',
                      trailing: Text(
                        _selectedCategoryName ?? 'Select',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _selectedCategoryName != null
                              ? const Color(0xFF111827)
                              : const Color(0xFF9CA3AF),
                        ),
                      ),
                      onTap: _showCategoryPicker,
                    ),
                    const _RowDivider(),
                  ],
                  _FormRow(
                    label: 'Date',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 16, color: Color(0xFF6B7280)),
                        const SizedBox(width: 6),
                        Text(
                          _formatDate(_selectedDate),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right,
                            size: 18, color: Color(0xFF9CA3AF)),
                      ],
                    ),
                    onTap: _showDatePickerDialog,
                  ),
                  const _RowDivider(),
                  if (_type != 'transfer') ...[
                    _FormRow(
                      label: 'Tag',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_selectedTag.emoji} ${_selectedTag.label}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right,
                              size: 18, color: Color(0xFF9CA3AF)),
                        ],
                      ),
                      onTap: _showTagPicker,
                    ),
                    const _RowDivider(),
                  ],
                  if (_type != 'transfer') ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 2),
                      child: TextField(
                        controller: _payeeCtrl,
                        onChanged: _onPayeeChanged,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Payee (e.g. Pizza Hut)',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD1D5DB),
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const _RowDivider(),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 2),
                    child: TextField(
                      controller: _memoCtrl,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Memo (optional)',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD1D5DB),
                        ),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Quick add from text (expense/income only) ──
          if (_type != 'transfer')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '✨ Quick add from text',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _quickTextCtrl,
                      minLines: 2,
                      maxLines: 4,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF111827),
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Paste a bank SMS, e.g. "Rs.250 spent at SWIGGY on 10-07-26"',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFB0B7C3),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF7FAF4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: _autoFillFromText,
                        icon: const Icon(Icons.auto_fix_high_rounded,
                            size: 18, color: Color(0xFF2E7D32)),
                        label: const Text(
                          'Auto-fill',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF2E7D32)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
                ],     // inner Column children
              ),       // inner Column
            ),         // SingleChildScrollView
          ),           // Expanded

          // ── 4. Save button ────────────────────────────
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _amount > 0 ? _saveTransaction : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _amount > 0
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFF9CA3AF),
                    disabledBackgroundColor: const Color(0xFF9CA3AF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────

/// Trailing content for the From/To rows: logo + name + chevron, or a grey
/// "Select" placeholder when no account is chosen yet.
class _AccountTrailing extends StatelessWidget {
  final Account? account;
  const _AccountTrailing({required this.account});

  @override
  Widget build(BuildContext context) {
    if (account == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            'Select',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9CA3AF),
            ),
          ),
          SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 18, color: Color(0xFF9CA3AF)),
        ],
      );
    }
    final logo = bankImagePathForName(account!.name);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (logo != null)
          BankLogo(imagePath: logo, size: 24)
        else
          const Icon(Icons.account_balance_rounded,
              size: 18, color: Color(0xFF1565C0)),
        const SizedBox(width: 8),
        Text(
          account!.name,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right, size: 18, color: Color(0xFF9CA3AF)),
      ],
    );
  }
}

// NOTE: does NOT return Expanded — the caller wraps with Expanded
class _TypeTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _TypeTab({
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.white : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  const _FormRow({
    required this.label,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
            const Spacer(),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 0.5,
      color: Color(0xFFF3F4F6),
      indent: 16,
      endIndent: 16,
    );
  }
}
