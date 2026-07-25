import '../services/email_parser_service.dart' show ParsedTransaction;

/// Axis Bank PDF account-statement parser.
///
/// New, self-contained file — does not touch the ICICI parser or any existing
/// code. Works on the layout text from `PdfTextExtractor.extractTextLines()`.
///
/// Axis statement layout (one transaction):
/// ```
/// 23-12-2025
/// UPI/P2A/627977632071/BADVEETI
/// /SBIN/Payment/ 59940.00            85402.68 3987
/// ```
/// i.e. a date line, the particulars wrapped across lines, and the trailing
/// line ends with `amount  balance  branch`. The Debit/Credit columns
/// collapse in extraction, so **direction is taken from the running-balance
/// delta** (seeded by "OPENING BALANCE") — the same robust approach used for
/// ICICI — rather than guessing from wording.
class AxisParser {
  // Date at the start of a line; group(4) is any same-line content after it
  // (short transactions render date + particulars + amounts on ONE line).
  static final RegExp _dateLine =
      RegExp(r'^\s*(\d{2})-(\d{2})-(\d{4})\b(.*)$');
  static final RegExp _opening =
      RegExp(r'OPENING BALANCE\s+([\d,]+\.\d{2})', caseSensitive: false);
  // "<amount> <balance> <branch>" anchored at end of a line.
  static final RegExp _amounts =
      RegExp(r'([\d,]+\.\d{2})\s+([\d,]+\.\d{2})\s+\d{1,5}\s*$');

  static List<ParsedTransaction> parseStatementText(String rawText) {
    final lines = rawText.split(RegExp(r'\r\n|\r|\n'));

    // Account number → "XX4394" (last 4 of the statement account).
    final acctRaw = RegExp(r'Account No[:\s]+(\d{4,})', caseSensitive: false)
        .firstMatch(rawText)
        ?.group(1);
    final account = (acctRaw != null && acctRaw.length >= 4)
        ? 'XX${acctRaw.substring(acctRaw.length - 4)}'
        : null;

    double? prevBalance =
        _toNum(_opening.firstMatch(rawText)?.group(1));

    final anchors = <int>[];
    for (var i = 0; i < lines.length; i++) {
      if (_dateLine.hasMatch(lines[i])) anchors.add(i);
    }

    final rows = <ParsedTransaction>[];
    for (var k = 0; k < anchors.length; k++) {
      final i = anchors[k];
      final end = (k + 1 < anchors.length) ? anchors[k + 1] : lines.length;
      final m = _dateLine.firstMatch(lines[i])!;
      final date = DateTime(
          int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));

      // Walk from the date line's own tail, then following lines, until the
      // line that carries the amount+balance (handles both single-line and
      // wrapped transactions).
      final particularsParts = <String>[];
      String? amountStr, balanceStr;
      for (var j = i; j < end; j++) {
        final ln = (j == i) ? m.group(4)! : lines[j];
        final am = _amounts.firstMatch(ln);
        if (am != null) {
          amountStr = am.group(1);
          balanceStr = am.group(2);
          particularsParts.add(ln.substring(0, am.start)); // text before amounts
          break; // amounts end the transaction
        }
        particularsParts.add(ln);
      }

      final amount = _toNum(amountStr);
      final balance = _toNum(balanceStr);
      if (amount == null || balance == null || amount <= 0) continue;

      final particulars =
          particularsParts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();

      // Direction from the running balance: up = credit (income), down = debit.
      final bool isIncome;
      if (prevBalance != null) {
        isIncome = balance > prevBalance;
      } else {
        isIncome = false; // no opening balance seen → assume debit
      }
      prevBalance = balance;

      final merchant = _extractMerchant(particulars);
      final ref = _extractRef(particulars);

      rows.add(ParsedTransaction(
        amount: amount,
        type: isIncome ? 'income' : 'expense',
        merchant: merchant,
        date: date,
        accountNumber: account,
        availableBalance: balance,
        bankName: 'Axis',
        // The running balance disambiguates rows that are otherwise identical
        // (e.g. two "DD Issue Chrgs Incl GST" 59.00 on the same day) while
        // staying deterministic, so re-importing an overlapping statement
        // still dedups correctly.
        emailId: 'axis_stmt_${m.group(1)}${m.group(2)}${m.group(3)}'
            '_${amountStr}_${balanceStr}_${ref ?? particulars.hashCode}',
        memo: particulars.isEmpty ? null : particulars,
        upiRef: ref,
        // No category here on purpose: CategoryClassifier is the single source
        // of truth and already matches the merchant against the real catalog.
        instrumentType: _instrument(particulars),
      ));
    }
    return rows;
  }

  static double? _toNum(String? s) =>
      s == null ? null : double.tryParse(s.replaceAll(',', ''));

  // ── Extractors ──────────────────────────────────────────────────────────
  static String? _extractMerchant(String p) {
    // UPI/P2A/<ref>/MERCHANT/... or UPI/P2M/<ref>/MERCHANT/...
    final upi = RegExp(r'UPI/P2[AM]/\d+/([^/]+)', caseSensitive: false)
        .firstMatch(p);
    if (upi != null) return _cleanName(upi.group(1)!);

    if (RegExp(r'Int\.Pd', caseSensitive: false).hasMatch(p)) {
      return 'Interest Earned';
    }
    if (RegExp(r'Int\.Coll', caseSensitive: false).hasMatch(p)) {
      return 'Interest Charged';
    }
    if (p.toUpperCase().contains('OUTWARD REM')) return 'Outward Remittance';

    // NEFT/<ref>/DESCRIPTION/...
    final neft = RegExp(r'NEFT/[A-Z0-9]+/([^/]+)', caseSensitive: false)
        .firstMatch(p);
    if (neft != null) return _cleanName(neft.group(1)!);

    final first = p.split('/').first.trim();
    return first.isEmpty ? null : _cleanName(first);
  }

  static String? _extractRef(String p) {
    final upi =
        RegExp(r'UPI/P2[AM]/(\d+)', caseSensitive: false).firstMatch(p);
    if (upi != null) return upi.group(1);
    final neft = RegExp(r'NEFT/([A-Z0-9]+)', caseSensitive: false).firstMatch(p);
    return neft?.group(1);
  }

  static String _instrument(String p) {
    final u = p.toUpperCase();
    if (u.contains('UPI/')) return 'upi';
    if (u.contains('NEFT')) return 'neft';
    if (u.contains('IMPS')) return 'imps';
    if (u.contains('RTGS')) return 'rtgs';
    return 'transfer';
  }

  static String _cleanName(String raw) => raw
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .split(' ')
      .map((w) =>
          w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ')
      .trim();

}
