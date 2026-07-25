import '../services/email_parser_service.dart' show ParsedTransaction;

/// ICICI Bank parser for **statement rows** (PDF/Excel) and **SMS alerts**.
///
/// This is a standalone helper. The app's live SMS and email pipelines already
/// classify ICICI messages via [SmsParserService] / [EmailParserService]; this
/// parser exists for structured *statement* rows (which those pipelines don't
/// cover) and as a self-contained ICICI SMS fallback.
///
/// All factory methods return the shared [ParsedTransaction] model so the
/// output drops straight into the existing import/save flow.
class ICICIParser {
  // ── Statement row (one row from a PDF/Excel statement) ──────────────────
  //
  // Columns as they appear in an ICICI account statement:
  //   date "25.05.2026" | remarks | withdrawal | deposit | balance
  static ParsedTransaction? parseStatementRow({
    required String date,
    required String remarks,
    required String withdrawal,
    required String deposit,
    required String balance,
  }) {
    final w = withdrawal.replaceAll(',', '').trim();
    final d = deposit.replaceAll(',', '').trim();

    final bool isExpense = w.isNotEmpty && w != '0' && (double.tryParse(w) ?? 0) > 0;
    final amount = double.tryParse(isExpense ? w : d) ?? 0;
    if (amount <= 0) return null;

    final merchant = _extractMerchant(remarks);
    final method = _extractMethod(remarks);
    final txDate = _parseDotDate(date);
    // The 12-digit RRN inside the remarks ("…/614548283286/…") is the same
    // reference SMS/email imports capture, so it doubles as the dedup key.
    final upiRef = RegExp(r'\b(\d{12})\b').firstMatch(remarks)?.group(1);

    return ParsedTransaction(
      amount: amount,
      type: isExpense ? 'expense' : 'income',
      merchant: merchant,
      date: txDate,
      accountNumber: null,
      availableBalance: double.tryParse(balance.replaceAll(',', '').trim()),
      bankName: 'ICICI',
      // Deterministic dedup key — same row never imports twice.
      emailId: 'icici_stmt_${date}_${amount}_${remarks.hashCode}',
      memo: remarks.trim().isEmpty ? null : remarks.trim(),
      upiRef: upiRef,
      category: _guessCategory(merchant ?? '', remarks),
      instrumentType: _instrument(method),
      isRecurring: method == 'NACH' || method == 'ECS',
    );
  }

  // ── ICICI SMS alert ─────────────────────────────────────────────────────
  static ParsedTransaction? parseSMS(String sms) {
    // Debit/credit UPI, NACH, and generic forms (most specific first).
    final debitUpi = RegExp(
      r'Rs\.?([\d,]+\.?\d*)\s+debited\s+from.*?(?:for\s+)?UPI/([^/]+)',
      caseSensitive: false,
    );
    final creditUpi = RegExp(
      r'Rs\.?([\d,]+\.?\d*)\s+credited\s+to.*?(?:by\s+)?UPI/([^/]+)',
      caseSensitive: false,
    );
    final nach = RegExp(
      r'debited\s+INR\s+([\d,]+\.?\d*).*?Info:\s*([A-Z\s]+)',
      caseSensitive: false,
    );
    final genericDebit = RegExp(
      r'(?:debited|debit).*?Rs\.?\s*([\d,]+\.?\d*)',
      caseSensitive: false,
    );
    final genericCredit = RegExp(
      r'(?:credited|credit).*?Rs\.?\s*([\d,]+\.?\d*)',
      caseSensitive: false,
    );

    double? amount;
    String? merchant;
    String type = 'expense';
    String method = 'Other';

    double? amt(String? s) =>
        s == null ? null : double.tryParse(s.replaceAll(',', ''));

    var m = debitUpi.firstMatch(sms);
    if (m != null) {
      amount = amt(m.group(1));
      merchant = _cleanMerchant(m.group(2) ?? '');
      type = 'expense';
      method = 'UPI';
    }
    if (amount == null && (m = creditUpi.firstMatch(sms)) != null) {
      amount = amt(m!.group(1));
      merchant = _cleanMerchant(m.group(2) ?? '');
      type = 'income';
      method = 'UPI';
    }
    if (amount == null && (m = nach.firstMatch(sms)) != null) {
      amount = amt(m!.group(1));
      merchant = m.group(2)?.trim().isNotEmpty == true
          ? _cleanMerchant(m.group(2)!)
          : 'Auto Debit';
      type = 'expense';
      method = 'NACH';
    }
    if (amount == null && (m = genericDebit.firstMatch(sms)) != null) {
      amount = amt(m!.group(1));
      merchant = null;
      type = 'expense';
    }
    if (amount == null && (m = genericCredit.firstMatch(sms)) != null) {
      amount = amt(m!.group(1));
      merchant = null;
      type = 'income';
    }

    if (amount == null || amount <= 0) return null;

    return ParsedTransaction(
      amount: amount,
      type: type,
      merchant: merchant,
      date: _smsDate(sms),
      accountNumber: _extractAccount(sms),
      availableBalance: null,
      bankName: 'ICICI',
      emailId: 'icici_sms_${sms.hashCode}',
      memo: sms.trim(),
      category: _guessCategory(merchant ?? '', sms),
      instrumentType: _instrument(method),
      isRecurring: method == 'NACH' || method == 'ECS',
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  static String? _extractMerchant(String remarks) {
    final r = remarks;
    final ru = remarks.toUpperCase();

    // UPI: "UPI/MERCHANT/vpa/…"
    final upi = RegExp(r'UPI/([^/]+)/', caseSensitive: false).firstMatch(r);
    if (r.toUpperCase().startsWith('UPI/') && upi != null) {
      return _cleanMerchant(upi.group(1)!);
    }
    // NACH/ACH mandate: "ACH/RAZORPAY PAYMENTS PV/…"
    final ach = RegExp(r'^ACH/([^/]+)', caseSensitive: false).firstMatch(r);
    if (ach != null) return _cleanMerchant(ach.group(1)!);

    // Common ICICI statement narrations (monthly e-statement format).
    if (ru.contains('SALARY')) return 'Salary';
    final vsi = RegExp(r'VSI/([A-Za-z ]+)', caseSensitive: false).firstMatch(r);
    if (vsi != null) return _cleanMerchant(vsi.group(1)!);
    if (r.startsWith('MMT/') || r.contains('/IMPS/')) return 'IMPS Transfer';
    if (r.contains('INF/INFT') || ru.contains('/SELF')) return 'Self Transfer';
    if (r.startsWith('BIL/')) {
      if (ru.contains('LOAN')) return 'Loan EMI';
      if (ru.contains('BILLPAY')) return 'Card Bill Payment';
      return 'Bill Payment';
    }
    if (ru.contains('INT.COLL') || ru.contains('INT.PD')) return 'Interest';
    if (ru.startsWith('DCARDFEE')) return 'Card Fee';
    if (ru.startsWith('POSDEC')) return 'POS Charges';

    // A trailing UPI merchant even when the line doesn't start with UPI/.
    if (upi != null) return _cleanMerchant(upi.group(1)!);

    if (r.contains('ECSRTN') || r.contains('Debit trxn')) return 'ECS Debit';

    final first = r.trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? null : _cleanMerchant(first);
  }

  static String _extractMethod(String remarks) {
    final r = remarks.toUpperCase();
    if (r.startsWith('UPI')) return 'UPI';
    if (r.startsWith('ACH') || r.startsWith('NACH')) return 'NACH';
    if (r.contains('NEFT')) return 'NEFT';
    if (r.contains('IMPS')) return 'IMPS';
    if (r.contains('ECSRTN') || r.contains('ECS')) return 'ECS';
    return 'Other';
  }

  /// Maps the ICICI method label to the model's `instrumentType` vocabulary.
  static String _instrument(String method) {
    switch (method) {
      case 'UPI':
        return 'upi';
      case 'IMPS':
        return 'imps';
      case 'NEFT':
        return 'neft';
      case 'NACH':
      case 'ECS':
        return 'nach_ecs';
      default:
        return 'other';
    }
  }

  static String _cleanMerchant(String raw) {
    return raw
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .split(' ')
        .map((w) => w.isEmpty
            ? ''
            : w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ')
        .trim();
  }

  /// "25.05.2026" → DateTime. Falls back to a zero-ish date on failure so a bad
  /// cell never throws mid-import.
  static DateTime _parseDotDate(String date) {
    try {
      final p = date.split('.');
      return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
    } catch (_) {
      return DateTime(1970);
    }
  }

  /// Best-effort date from an SMS body (dd-MMM-yy / dd-MM-yyyy), else epoch.
  static DateTime _smsDate(String sms) {
    final mon = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    var m = RegExp(r'(\d{1,2})-([A-Za-z]{3})-(\d{2,4})').firstMatch(sms);
    if (m != null) {
      final mm = mon[m.group(2)!.toLowerCase()];
      if (mm != null) {
        final yy = int.parse(m.group(3)!);
        return DateTime(yy < 100 ? 2000 + yy : yy, mm, int.parse(m.group(1)!));
      }
    }
    m = RegExp(r'(\d{2})-(\d{2})-(\d{4})').firstMatch(sms);
    if (m != null) {
      return DateTime(
          int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
    }
    return DateTime(1970);
  }

  static String? _extractAccount(String sms) {
    final m = RegExp(r'(?:A/c|Acct|Account)\s*[Xx*]*(\d{3,})',
            caseSensitive: false)
        .firstMatch(sms);
    return m != null ? 'XX${m.group(1)}' : null;
  }

  static String _guessCategory(String merchant, String remarks) {
    final m = merchant.toLowerCase();
    final r = remarks.toLowerCase();

    // Statement-specific narrations first (most specific).
    if (m.contains('interest')) return 'Interest';
    if (_has(m, ['card fee', 'pos charges', 'gst', 'charges'])) return 'Fees';
    if (m.contains('salary')) return 'Income';
    if (_has(m, ['apollo', 'pharmacy', 'hospital', 'medical', 'clinic'])) {
      return 'Health';
    }
    if (_has(m, ['hydmetro', 'metro'])) return 'Transport';

    if (_has(m, ['swiggy', 'zomato', 'domino', 'pizza', 'food', 'restaurant',
        'cafe', 'hotel', 'biryani', 'district d', 'cinepride'])) {
      return 'Food';
    }
    if (_has(m, ['amazon', 'flipkart', 'myntra', 'nykaa', 'meesho',
        'bigbasket', 'blinkit', 'zepto', 'instamart'])) {
      return 'Shopping';
    }
    if (_has(m, ['netflix', 'hotstar', 'prime', 'spotify', 'youtube',
        'google play', 'googleplay', 'cheq'])) {
      return 'Entertainment';
    }
    if (_has(m, ['uber', 'ola', 'rapido', 'redbus', 'irctc', 'metro',
        'petrol', 'fuel'])) {
      return 'Transport';
    }
    if (_has(m, ['slice', 'razorpay', 'nach', 'ecs', 'emi', 'loan',
        'repayment'])) {
      return 'EMI';
    }
    if (_has(m, ['electricity', 'bescom', 'tpddl', 'water', 'gas',
        'broadband', 'jio', 'airtel', 'vodafone'])) {
      return 'Bills';
    }
    if (r.contains('upi') &&
        _has(r, ['sent using', 'payment fr', 'self trans'])) {
      return 'Transfer';
    }

    return 'Other';
  }

  static bool _has(String text, List<String> keywords) =>
      keywords.any(text.contains);
}
