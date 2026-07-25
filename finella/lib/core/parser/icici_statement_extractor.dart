import '../services/email_parser_service.dart' show ParsedTransaction;
import 'icici_parser.dart';

/// One raw row pulled out of an ICICI account-statement PDF, with the columns
/// already separated so it can be handed straight to
/// [ICICIParser.parseStatementRow].
class IciciStatementRow {
  final String date; // "25.05.2026"
  final String remarks; // "UPI/Mr Ketavat/.../614548283286/..."
  final String withdrawal; // amount or ''
  final String deposit; // amount or ''
  final String balance; // running balance

  const IciciStatementRow({
    required this.date,
    required this.remarks,
    required this.withdrawal,
    required this.deposit,
    required this.balance,
  });
}

/// Turns the layout-preserving text of an ICICI savings-account statement
/// (as produced by `PdfTextExtractor.extractText(layoutText: true)`) into
/// structured rows.
///
/// The statement lays out each transaction as:
/// ```
///                                  Mr Ketavat            <- payee (short)
///  1   25.05.2026                  60.00      18518.21   <- anchor: no, date, amount, balance
///                                  UPI/Mr Ketavat/...     <- remarks (wrap across lines)
/// ```
/// The anchor line is detected by `<serial> <dd.mm.yyyy>`; everything between
/// two anchors (minus the next payee line and page furniture) is the remarks.
///
/// Direction (withdrawal vs deposit) is taken from the **running balance
/// delta** — robust to column spacing, which varies between PDF text
/// extractors. The first row, having no previous balance, falls back to the
/// amount's horizontal position (the deposit column sits to the right).
class IciciStatementExtractor {
  // Format A — "OpTransactionHistory" export: "<serial> <dd.mm.yyyy> … amt bal".
  static final RegExp _anchor =
      RegExp(r'^\s*(\d{1,4})\s+(\d{2}\.\d{2}\.\d{4})\b(.*)$');
  // Format B — monthly e-statement: line starts with "<dd-mm-yyyy>".
  static final RegExp _anchorB = RegExp(r'^\s*(\d{2})-(\d{2})-(\d{4})\b(.*)$');
  static final RegExp _money = RegExp(r'\d[\d,]*\.\d{2}');
  // MODE column values that precede the particulars in the monthly format.
  static final RegExp _modeB = RegExp(
    r'^\s*(MOBILE BANKING|NET BANKING|INTERNET BANKING|CMS TRANSACTION)\s*',
    caseSensitive: false,
  );
  // Page furniture inside the transaction region — never part of a real row.
  static final RegExp _noiseB = RegExp(
    r'(Total:|Page \d+ of|DATEMODE|Statement of Transactions|Never share|'
    r'www\.icici|Dial your Bank|Sincerely|Team ICICI|Legends for|'
    r'Account Related|This is a|Customers are|Registered Office|'
    r'Corporate Office)',
    caseSensitive: false,
  );

  /// Lines inside the transaction band that are page furniture, not remarks.
  static final RegExp _noise = RegExp(
    r'(www\.icici|dial your bank|never share|legends for|page \d|'
    r'transaction remarks|cheque number|withdrawal|deposit\b|balance\b|'
    r's no\.|statement of transactions|base branch|statement summary|'
    r'account holders|account type|account details)',
    caseSensitive: false,
  );

  static List<IciciStatementRow> extractRows(String layoutText) {
    // Split on ANY line terminator. Syncfusion emits "\r"-terminated lines;
    // splitting only on "\n" leaves a trailing "\r" that breaks the "(.*)$"
    // anchor regexes (Dart's "." and "$" don't cross "\r"), yielding 0 rows.
    final lines = layoutText.split(RegExp(r'\r\n|\r|\n'));

    // Monthly e-statements use dash dates + a "DEPOSITS … WITHDRAWALS" header
    // and a "B/F" opening balance; the OpTransactionHistory export uses
    // "<serial> <dd.mm.yyyy>" rows. Pick the layout that actually matches.
    final looksLikeB = lines.any(_anchorB.hasMatch) &&
        (layoutText.contains('B/F') ||
            RegExp(r'DEPOSITS\s+WITHDRAWALS', caseSensitive: false)
                .hasMatch(layoutText));
    return looksLikeB ? _extractFormatB(lines) : _extractFormatA(lines);
  }

  // ── Format A: OpTransactionHistory export ───────────────────────────────
  static List<IciciStatementRow> _extractFormatA(List<String> lines) {
    // Index every anchor line first so we can bound each transaction's remarks.
    final anchors = <int>[];
    for (var i = 0; i < lines.length; i++) {
      if (_anchor.hasMatch(lines[i])) anchors.add(i);
    }

    final rows = <IciciStatementRow>[];
    double? prevBalance;

    for (var k = 0; k < anchors.length; k++) {
      final i = anchors[k];
      final m = _anchor.firstMatch(lines[i])!;
      final date = m.group(2)!;
      final tail = m.group(3)!; // everything after the date

      final nums = _money.allMatches(tail).map((e) => e.group(0)!).toList();
      if (nums.length < 2) continue; // need at least amount + balance

      final balanceStr = nums.last;
      final amountStr = nums[nums.length - 2];
      final balance = double.tryParse(balanceStr.replaceAll(',', ''));
      if (balance == null) continue;

      final bool isDeposit;
      if (prevBalance != null) {
        isDeposit = balance > prevBalance;
      } else {
        // First row: deposit column sits right of withdrawal, i.e. the amount
        // is close to the balance. Large gap ⇒ withdrawal.
        final aEnd = tail.indexOf(amountStr) + amountStr.length;
        final bStart = tail.lastIndexOf(balanceStr);
        isDeposit = (bStart - aEnd) <= 8;
      }
      prevBalance = balance;

      rows.add(IciciStatementRow(
        date: date,
        remarks: _collectRemarks(lines, i, k, anchors),
        withdrawal: isDeposit ? '' : amountStr.replaceAll(',', ''),
        deposit: isDeposit ? amountStr.replaceAll(',', '') : '',
        balance: balanceStr.replaceAll(',', ''),
      ));
    }
    return rows;
  }

  // ── Format B: monthly e-statement ───────────────────────────────────────
  //
  // Syncfusion's text extraction does NOT preserve columns — it concatenates
  // the DEPOSITS/WITHDRAWALS/BALANCE cells (e.g. "220.00321.15") and puts the
  // date on its own line with the particulars + amounts on following lines.
  //
  // So we work block-by-block (one date line to the next) and derive each
  // amount from the running-balance DELTA: the balance is the last "·.dd"
  // number in the block, and amount = |balance − prevBalance|. That sidesteps
  // the cell concatenation entirely, and the "B/F" row seeds the first balance.
  static List<IciciStatementRow> _extractFormatB(List<String> lines) {
    final anchors = <int>[];
    for (var i = 0; i < lines.length; i++) {
      if (_anchorB.hasMatch(lines[i])) anchors.add(i);
    }

    final rows = <IciciStatementRow>[];
    double? prevBalance;

    for (var k = 0; k < anchors.length; k++) {
      final i = anchors[k];
      final end = (k + 1 < anchors.length) ? anchors[k + 1] : lines.length;
      final m = _anchorB.firstMatch(lines[i])!;
      final date = '${m.group(1)}.${m.group(2)}.${m.group(3)}'; // → dd.mm.yyyy

      // The transaction block = anchor-line tail + following lines, up to the
      // next date OR the first page-furniture line (per-page "Total:" row,
      // "Page X of Y", footer). Stopping there keeps the page totals and the
      // trailing legal footer out of the running-balance chain.
      final blockLines = <String>[m.group(4)!];
      for (var j = i + 1; j < end; j++) {
        if (_noiseB.hasMatch(lines[j])) break;
        blockLines.add(lines[j]);
      }
      final block = blockLines.join(' ');
      final money = _money.allMatches(block).map((e) => e.group(0)!).toList();

      // Opening balance — seeds the delta, not a transaction itself.
      if (block.contains('B/F')) {
        if (money.isNotEmpty) prevBalance = _toNum(money.last);
        continue;
      }
      if (money.isEmpty) continue;

      final balance = _toNum(money.last);
      if (balance == null) continue;

      final double amount;
      final bool isDeposit;
      if (prevBalance != null) {
        final delta = balance - prevBalance;
        amount = (delta.abs() * 100).round() / 100; // exact to paise
        isDeposit = delta > 0;
      } else if (money.length >= 2) {
        // No opening balance yet: fall back to the printed amount.
        amount = _toNum(money[money.length - 2]) ?? 0;
        isDeposit = false;
      } else {
        prevBalance = balance;
        continue;
      }
      prevBalance = balance;
      if (amount <= 0) continue;

      // Particulars = block with the money cells, MODE and date noise removed.
      var particulars = block;
      for (final mm in money) {
        particulars = particulars.replaceAll(mm, ' ');
      }
      particulars = particulars
          .replaceFirst(_modeB, ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final amt = amount.toStringAsFixed(2);
      rows.add(IciciStatementRow(
        date: date,
        remarks: particulars,
        withdrawal: isDeposit ? '' : amt,
        deposit: isDeposit ? amt : '',
        balance: balance.toStringAsFixed(2),
      ));
    }
    return rows;
  }

  static double? _toNum(String s) => double.tryParse(s.replaceAll(',', ''));

  /// Convenience: extract rows and parse them into [ParsedTransaction]s.
  static List<ParsedTransaction> parse(String layoutText) {
    final out = <ParsedTransaction>[];
    for (final r in extractRows(layoutText)) {
      final tx = ICICIParser.parseStatementRow(
        date: r.date,
        remarks: r.remarks,
        withdrawal: r.withdrawal,
        deposit: r.deposit,
        balance: r.balance,
      );
      if (tx != null) out.add(tx);
    }
    return out;
  }

  /// Remarks = the wrapped lines after anchor [i] up to the next anchor,
  /// excluding the next transaction's payee line and any page furniture.
  static String _collectRemarks(
      List<String> lines, int i, int k, List<int> anchors) {
    final end = (k + 1 < anchors.length) ? anchors[k + 1] : lines.length;
    // The line right before the next anchor is that transaction's payee name.
    final stop = (k + 1 < anchors.length) ? end - 1 : end;

    final parts = <String>[];
    for (var j = i + 1; j < stop; j++) {
      final t = lines[j].trim();
      // A transaction's remark lines are contiguous; the first blank line after
      // them ends the block (and keeps page footers/legends out of the last row).
      if (t.isEmpty) {
        if (parts.isNotEmpty) break;
        continue;
      }
      if (_noise.hasMatch(t) || RegExp(r'^\d{1,3}$').hasMatch(t)) continue;
      parts.add(t);
    }
    return parts.join(' ');
  }
}
