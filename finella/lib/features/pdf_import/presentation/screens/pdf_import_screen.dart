import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/bank_assets.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/services/category_classifier.dart';
import '../../../../core/services/email_parser_service.dart' show ParsedTransaction;
import '../../../../core/services/pdf_statement_service.dart';
import '../../../../shared/widgets/merchant_transaction_row.dart';
import '../../../accounts/models/bank_model.dart';

const _kPrimary = Color(0xFF2E7D32);
const _kBg = Color(0xFFF7FAF4);

enum _Stage { pick, loading, password, results, empty, importing, success, error }

class _Selectable {
  final ParsedTransaction tx;
  bool selected;
  _Selectable(this.tx) : selected = true;
}

/// Imports transactions from a bank-statement PDF (ICICI and Axis savings
/// statements). Pick a PDF → review the parsed rows → import the selected ones.
class PdfImportScreen extends ConsumerStatefulWidget {
  const PdfImportScreen({super.key});

  @override
  ConsumerState<PdfImportScreen> createState() => _PdfImportScreenState();
}

class _PdfImportScreenState extends ConsumerState<PdfImportScreen> {
  _Stage _stage = _Stage.pick;
  List<_Selectable> _items = [];
  int _importedCount = 0;
  String _error = '';

  // Held while we wait for a password on an encrypted statement.
  Uint8List? _pendingBytes;
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null) return; // user cancelled
    final bytes = result.files.single.bytes;
    if (bytes == null) {
      setState(() {
        _error = 'Could not read that file.';
        _stage = _Stage.error;
      });
      return;
    }
    debugPrint('📄 PDF screen: picked "${result.files.single.name}", '
        'bytes=${bytes.length}');
    _pendingBytes = bytes;
    _parse(bytes);
  }

  void _parse(Uint8List bytes, {String? password}) {
    setState(() => _stage = _Stage.loading);
    try {
      final txs = ref.read(pdfStatementServiceProvider).parse(
            bytes,
            password: password,
          );
      debugPrint('📄 PDF screen: parse returned ${txs.length} transactions');
      if (txs.isEmpty) {
        setState(() => _stage = _Stage.empty);
        return;
      }
      setState(() {
        _items = txs.map((t) => _Selectable(t)).toList();
        _stage = _Stage.results;
      });
    } on PdfPasswordRequiredException {
      debugPrint('📄 PDF screen: password required');
      setState(() => _stage = _Stage.password);
    } catch (e, st) {
      debugPrint('📄 PDF screen: ERROR $e\n$st');
      setState(() {
        _error = '$e';
        _stage = _Stage.error;
      });
    }
  }

  Future<void> _import() async {
    final selected = _items.where((s) => s.selected).toList();
    if (selected.isEmpty) return;
    setState(() => _stage = _Stage.importing);

    final dao = ref.read(transactionDaoProvider);
    final accountDao = ref.read(accountDaoProvider);

    // Create any bank / card accounts the statement references but that don't
    // exist yet, so imported transactions link to a real account (and show up
    // in the Accounts view). Same flow as the SMS / Gmail imports.
    await _maybeCreateDetectedAccounts(selected.map((s) => s.tx).toList());

    // Content-level dedup: skip rows we already have (by UPI ref or our
    // deterministic statement key), so re-importing the same PDF is safe.
    // A ref is qualified by direction + amount because a merchant can reuse one
    // ref for a charge and its refund (they're distinct rows), while the same
    // txn already imported from SMS still matches on all three.
    final seenRefs = <String>{};
    final seenKeys = <String>{};
    try {
      for (final tx in await dao.getAllTransactions()) {
        if (tx.upiRef != null && tx.upiRef!.isNotEmpty) {
          seenRefs.add(_refKey(tx.upiRef!, tx.type, tx.amount));
        }
        if (tx.sourceEmailId != null && tx.sourceEmailId!.isNotEmpty) {
          seenKeys.add(tx.sourceEmailId!);
        }
      }
    } catch (_) {
      // Best-effort; continue without dedup if the lookup fails.
    }

    var count = 0;
    for (final s in selected) {
      final t = s.tx;
      final ref0 = t.upiRef;
      final refKey =
          (ref0 == null || ref0.isEmpty) ? null : _refKey(ref0, t.type, t.amount);
      if ((refKey != null && seenRefs.contains(refKey)) ||
          seenKeys.contains(t.emailId)) {
        continue; // duplicate
      }
      try {
        final account =
            await accountDao.findByBankAndNumber(t.bankName, t.accountNumber);
        final accountId = account?.id.toString() ??
            t.accountDisplayName.toLowerCase().replaceAll(' ', '_');
        final accountName = account?.name ?? t.accountDisplayName;

        // Both fields come from one catalog entry, so a row can never display
        // one category while grouping under another.
        final cat = CategoryClassifier.classify(t.merchant, type: t.type);
        final categoryId = cat?.id ?? 'other';
        final categoryName = cat?.name ?? 'Other';

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
            memo: Value(t.memo == null ? 'Imported from statement' : t.memo!),
            sourceEmailId: Value(t.emailId),
            upiRef: Value(ref0),
            instrumentType: Value(t.instrumentType),
            isRecurring: Value(t.isRecurring),
            currency: Value(t.currency),
          ),
        );
        if (refKey != null) seenRefs.add(refKey);
        seenKeys.add(t.emailId);
        count++;
      } catch (_) {
        // Skip a single bad row, keep importing the rest.
      }
    }

    if (!mounted) return;
    setState(() {
      _importedCount = count;
      _stage = _Stage.success;
    });
  }

  /// Creates any bank / card accounts referenced by [parsed] that aren't in the
  /// DB yet. Deduped by bank + masked number, so re-importing never duplicates.
  Future<void> _maybeCreateDetectedAccounts(
      List<ParsedTransaction> parsed) async {
    final accountDao = ref.read(accountDaoProvider);
    final seen = <String>{};
    for (final t in parsed) {
      final number = t.accountNumber;
      if (number == null || number.isEmpty) continue;
      final key = '${t.bankName.toLowerCase()}_${number.toLowerCase()}';
      if (!seen.add(key)) continue;
      if (await accountDao.findByBankAndNumber(t.bankName, number) != null) {
        continue;
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
      } catch (_) {
        // Skip a failed account; the rest still proceed.
      }
    }
  }

  /// Dedup key for a UPI reference. Qualified by direction and amount so a
  /// charge and a refund that share a ref stay distinct.
  String _refKey(String ref, String type, double amount) =>
      '$ref|$type|${amount.toStringAsFixed(2)}';

  int get _selectedCount => _items.where((s) => s.selected).length;

  /// Rows sorted newest-first with a month-label string before each month.
  List<Object> _groupedItems() {
    final sorted = [..._items]..sort((a, b) => b.tx.date.compareTo(a.tx.date));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF111827),
        title: const Text('Import from statement',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: Color(0xFF2E7D32))),
      ),
      body: switch (_stage) {
        _Stage.pick => _PickView(onPick: _pickFile),
        _Stage.loading => const _Centered(child: CircularProgressIndicator(color: _kPrimary)),
        _Stage.password => _passwordView(),
        _Stage.results => _buildResults(),
        _Stage.empty => _messageView(
            Icons.search_off_rounded,
            'No transactions found',
            'We couldn\'t read any transactions from that PDF. Make sure it\'s '
                'an ICICI or Axis Bank account statement.',
            'Choose another file',
          ),
        _Stage.importing => const _Centered(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: _kPrimary),
            SizedBox(height: 16),
            Text('Importing…', style: TextStyle(fontWeight: FontWeight.w600)),
          ])),
        _Stage.success => _messageView(
            Icons.check_circle_rounded,
            'Imported $_importedCount transactions',
            'They\'re now in your Activity.',
            'Import another statement',
            tint: _kPrimary,
          ),
        _Stage.error => _messageView(
            Icons.error_outline_rounded,
            'Something went wrong',
            _error,
            'Try again',
            tint: const Color(0xFFEF4444),
          ),
      },
    );
  }

  Widget _buildResults() {
    final items = _groupedItems();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text('${_items.length} transactions found',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827))),
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
                        color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.white,
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item = items[i];
                if (item is String) {
                  return MerchantSectionHeader(label: item);
                }
                final s = item as _Selectable;
                final t = s.tx;
                // Second line = category + bank name (e.g. "Food · Axis").
                // Resolved the same way _import() does, so the preview shows
                // the category the row will actually be saved with.
                final category = [
                  CategoryClassifier.classify(t.merchant, type: t.type)?.name ??
                      'Other',
                  t.bankName,
                ].join(' · ');
                return MerchantTransactionRow(
                  name: t.merchant ?? 'Unknown',
                  category: category,
                  amount: t.amount,
                  currency: t.currency,
                  isIncome: t.type == 'income',
                  date: t.date,
                  logoAsset: bankImagePathForName(t.bankName),
                  source: 'statement',
                  redExpense: true, // debit → red, credit → green
                  onTap: () => setState(() => s.selected = !s.selected),
                  leading: SizedBox(
                    width: 28,
                    height: 28,
                    child: Checkbox(
                      value: s.selected,
                      onChanged: (v) => setState(() => s.selected = v ?? false),
                      activeColor: _kPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
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

  Widget _passwordView() {
    return _Centered(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline_rounded, size: 48, color: _kPrimary),
          const SizedBox(height: 16),
          const Text('This statement is password-protected',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Enter the PDF password to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'PDF password',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                if (_pendingBytes != null) {
                  _parse(_pendingBytes!, password: _passwordCtrl.text);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Unlock',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _messageView(
      IconData icon, String title, String body, String cta,
      {Color tint = const Color(0xFF374151)}) {
    return _Centered(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: tint),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                _passwordCtrl.clear();
                _pickFile();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: Text(cta,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _PickView extends StatelessWidget {
  final VoidCallback onPick;
  const _PickView({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return _Centered(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
                color: Color(0xFFE8F0EC), shape: BoxShape.circle),
            child: const Icon(Icons.picture_as_pdf_rounded,
                size: 48, color: _kPrimary),
          ),
          const SizedBox(height: 24),
          const Text('Import from PDF statement',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Pick an ICICI or Axis Bank account statement PDF. We\'ll read the '
            'transactions so you can review and import them.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
              label: const Text('Choose PDF',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  final Widget child;
  const _Centered({required this.child});
  @override
  Widget build(BuildContext context) => Center(child: child);
}
