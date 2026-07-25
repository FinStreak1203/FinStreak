import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A transaction extracted from a bank alert email.
class ParsedTransaction {
  final double amount;
  final String type; // 'expense' or 'income'
  final String? merchant;
  final DateTime date;
  final String? accountNumber;
  final double? availableBalance;
  final String bankName;
  final String emailId; // to mark as processed
  final String? memo; // e.g. "UPI: 886806593189"
  final String? accountType; // e.g. 'credit_card'
  final String? upiRef; // raw reference number, for content-level dedup
  final String? upiVpa; // UPI VPA address, e.g. "merchant@paytm" (SMS only)
  final String? category; // universal category, e.g. "UPI Debit"
  final String? instrumentType; // 'upi' | 'card' | 'imps' | 'atm' | ...
  final bool isRecurring; // EMI / AutoPay / mandate
  final String currency; // ISO code, e.g. 'INR' | 'USD' — drives the symbol

  const ParsedTransaction({
    required this.amount,
    required this.type,
    required this.merchant,
    required this.date,
    required this.accountNumber,
    required this.availableBalance,
    required this.bankName,
    required this.emailId,
    this.memo,
    this.accountType,
    this.upiRef,
    this.upiVpa,
    this.category,
    this.instrumentType,
    this.isRecurring = false,
    this.currency = 'INR',
  });

  /// Account label for display/saving, e.g. "ICICI Credit Card" vs "ICICI".
  String get accountDisplayName =>
      accountType == 'credit_card' ? '$bankName Credit Card' : bankName;

  @override
  String toString() => '''
ParsedTransaction {
  bankName        : $bankName
  type            : $type            (debit→expense / credit→income)
  category        : $category
  instrumentType  : $instrumentType
  currency        : $currency
  amount          : $amount
  accountNumber   : $accountNumber
  accountType     : $accountType
  accountDisplay  : $accountDisplayName
  merchant        : $merchant
  date            : $date
  memo            : $memo
  upiRef          : $upiRef
  availableBalance: $availableBalance
  isRecurring     : $isRecurring
  emailId         : $emailId
}''';
}

/// Per-bank regex configuration.
class _BankParser {
  final String name;
  final List<String> keywords; // detect bank from the email body
  final RegExp amount;
  final RegExp? merchant;
  final RegExp? merchantFallback;
  final RegExp? date;
  final RegExp? account;
  final List<String> expenseWords;
  final List<String> incomeWords;

  const _BankParser({
    required this.name,
    required this.keywords,
    required this.amount,
    this.merchant,
    this.merchantFallback,
    this.date,
    this.account,
    required this.expenseWords,
    required this.incomeWords,
  });
}

/// Parses bank alert email bodies into [ParsedTransaction]s.
class EmailParserService {
  // ── Bank patterns ───────────────────────────────────────
  static final List<_BankParser> _banks = [
    _BankParser(
      name: 'HDFC',
      keywords: ['hdfc'],
      amount: RegExp(r'Rs\.(\d+(?:\.\d{1,2})?)'),
      // Payee inside brackets first: "towards VPA <id> (Airtel Recharge)"
      merchant: RegExp(r'towards VPA\s+\S+\s+\(([^)]+)\)',
          caseSensitive: false),
      // No brackets → use the VPA id itself.
      merchantFallback:
          RegExp(r'towards VPA\s+(\S+)', caseSensitive: false),
      date: RegExp(r'on\s+(\d{2}-\d{2}-\d{2})\.?'),
      account: RegExp(r'account ending (\d{4})', caseSensitive: false),
      expenseWords: ['debited'],
      incomeWords: ['credited'],
    ),
    _BankParser(
      name: 'ICICI',
      keywords: ['icici'],
      amount: RegExp(r'(?:INR|Rs\.?)\s*([\d,]+\.?\d*)', caseSensitive: false),
      merchant: RegExp(r'at\s+([A-Z\s]+)\s+on'),
      date: RegExp(r'(\d{2}/\d{2}/\d{4})'),
      expenseWords: ['debited'],
      incomeWords: ['credited'],
    ),
    _BankParser(
      name: 'SBI',
      keywords: ['sbi', 'state bank'],
      amount: RegExp(r'(?:INR|Rs\.?)\s*([\d,]+\.?\d*)', caseSensitive: false),
      merchant: RegExp(r'Info:\s*([A-Za-z0-9\s/]+)\.'),
      date: RegExp(r'(\d{2}-\d{2}-\d{4})'),
      expenseWords: ['debited'],
      incomeWords: ['credited'],
    ),
    _BankParser(
      name: 'AXIS',
      keywords: ['axis'],
      amount: RegExp(r'(?:INR|Rs\.?)\s*([\d,]+\.?\d*)', caseSensitive: false),
      merchant: RegExp(r'at\s+([A-Z\s]+)\s+on'),
      date: RegExp(r'(\d{2}-\d{2}-\d{4})'),
      expenseWords: ['spent'],
      incomeWords: ['received'],
    ),
  ];


  /// Labeled "Merchant Name: X" fallback (credit-card alert emails), captured
  /// minimally up to the next field keyword.
  static final RegExp _merchantLabel = RegExp(
    r'merchant\s*name\s*:?\s*([A-Za-z0-9][A-Za-z0-9 ._&/-]*?)\s*'
    r'(?:axis|hdfc|icici|sbi|kotak|card|a/c|account|date|available|total|no\b|xx)',
    caseSensitive: false,
  );

  /// "Info: ..." fallback (SBI / ICICI). Captures up to the sentence end.
  static final RegExp _infoLabel = RegExp(
    r'info\s*:?\s*([A-Za-z0-9 ._/&-]+)',
    caseSensitive: false,
  );

  /// Catches the common Indian-bank date formats anywhere in the body.
  /// (2-digit-year `dd-mm-yy` is last so 4-digit years win.)
  static final RegExp _genericDate = RegExp(
    r'(\d{1,2}-[A-Za-z]{3}-\d{4}'
    r'|\d{1,2}-[A-Za-z]{3}-\d{2}'
    r'|[A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4}'
    r'|\d{1,2}\s+[A-Za-z]{3,9},?\s+\d{4}'
    r'|\d{1,2}/\d{1,2}/\d{4}'
    r'|\d{1,2}-\d{1,2}-\d{4}'
    r'|\d{1,2}/\d{1,2}/\d{2}'
    r'|\d{1,2}-\d{1,2}-\d{2})',
    caseSensitive: false,
  );

  /// UPI transaction reference (HDFC), stored in the memo as `UPI: <ref>`.
  /// Handles "UPI transaction reference no.: 123" and "UPI Transaction
  /// Reference Number: 123".
  static final RegExp _upiRef = RegExp(
    r'UPI\s+transaction\s+reference\s+(?:no|number)\.?:?\s*(\d+)',
    caseSensitive: false,
  );

  static final RegExp _balance = RegExp(
    r'(?:available balance|avl\.? bal|avbl bal|balance)[^\d]*(?:INR|Rs\.?)?\s*([\d,]+\.?\d*)',
    caseSensitive: false,
  );

  // ── Universal patterns (the common "A/c debited/credited" format) ──────
  static final RegExp _uAmount =
      RegExp(r'(?:INR|Rs\.?)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false);
  static final RegExp _uAccount = RegExp(
      r'(?:A/c|account)\s*(?:no\.?|number)?\s*:?\s*'
      r'(?:XX|ending(?:\s+in)?)?\s*[xX*]*(\d{3,4})',
      caseSensitive: false);
  static final RegExp _uRef = RegExp(
      r'(?:UPI Ref|IMPS Ref|Mandate Ref|Ref(?:\.|erence)?(?:\s*(?:no|id))?|Txn)'
      r'[:\s.]+([0-9]{4,})',
      caseSensitive: false);
  static final RegExp _uMerchant = RegExp(
      r'(?:at|to|towards|merchant[:\s]+)\s*([A-Z][A-Za-z0-9\s@./_-]+?)'
      r'(?:\s+on|\s+Ref|\.)',
      caseSensitive: false);
  // Axis-style UPI party — "Transaction Info: UPI/P2M/<ref>/BHAVANA SUPER
  // MARKE". The payee/payer is the segment after the reference number,
  // delimited by the next "/" or the line end.
  static final RegExp _uUpiParty = RegExp(
      r'UPI/(?:P2M|P2A|P2P)/[A-Za-z0-9]+/([A-Za-z][A-Za-z0-9 .&_\-]+?)\s*(?:[/\n<]|$)',
      caseSensitive: false);
  static final RegExp _uUpiRef =
      RegExp(r'UPI/(?:P2M|P2A|P2P)/(\d+)', caseSensitive: false);

  /// Maps a sender email to a bank display name (sender-domain → bank).
  static const Map<String, String> _bankMaster = {
    'hdfcbank': 'HDFC', 'hdfc': 'HDFC', 'icicibank': 'ICICI', 'icici': 'ICICI',
    'sbicard': 'SBI', 'sbi': 'SBI', 'axisbank': 'Axis', 'axis': 'Axis',
    'kotak': 'Kotak', 'yes': 'Yes Bank', 'idbi': 'IDBI', 'canarabank': 'Canara',
    'canara': 'Canara', 'pnb': 'PNB', 'bankofbaroda': 'Bank of Baroda',
    'bankofindia': 'Bank of India', 'bankofmaharashtra': 'Bank of Maharashtra',
    'centralbank': 'Central Bank', 'indianbank': 'Indian Bank', 'iob': 'IOB',
    'punjabandsind': 'Punjab & Sind', 'uco': 'UCO',
    'unionbankonline': 'Union Bank', 'bandhan': 'Bandhan', 'csb': 'CSB',
    'cityunionbank': 'City Union', 'dcb': 'DCB', 'dhan': 'Dhanlaxmi',
    'federal': 'Federal', 'indusind': 'IndusInd', 'idfcfirst': 'IDFC First',
    'jkb': 'J&K Bank', 'karnatakabank': 'Karnataka', 'kvb': 'KVB',
    'nainitalbank': 'Nainital', 'rbl': 'RBL', 'southindianbank': 'South Indian',
    'tmb': 'TMB', 'au': 'AU Bank', 'equitas': 'Equitas', 'ujjivansfb': 'Ujjivan',
    'slice': 'Slice', 'jana': 'Jana', 'ippbonline': 'India Post', 'fino': 'Fino',
    'airtelpayments': 'Airtel Payments', 'nsdlpayments': 'NSDL Payments',
    'dbs': 'DBS', 'sc': 'StanChart', 'hsbc': 'HSBC',
    'americanexpress': 'Amex', 'citigroup': 'Citi',
  };

  /// Resolves the bank from the sender address (prefers the `*.bank.in`
  /// subdomain), or null if it can't be determined.
  String? bankFromSender(String? sender) {
    if (sender == null || sender.isEmpty) return null;
    final s = sender.toLowerCase();
    final at = s.indexOf('@');
    final domain = at >= 0 ? s.substring(at + 1) : s;

    // <prefix>.bank.in → look the prefix up first.
    final m = RegExp(r'([a-z0-9]+)\.bank\.in').firstMatch(domain);
    if (m != null) {
      final prefix = m.group(1)!;
      return _bankMaster[prefix] ?? _prettyPrefix(prefix);
    }
    // Legacy / non-bank.in domains.
    for (final e in _bankMaster.entries) {
      if (domain.contains(e.key)) return e.value;
    }
    return null;
  }

  String _prettyPrefix(String p) =>
      p.isEmpty ? 'Bank' : '${p[0].toUpperCase()}${p.substring(1)}';

  /// Classifies a transaction into one of the universal categories from body
  /// Marketing phrases that essentially never appear in a real transaction
  /// alert. Matched on the lowercased, tag-stripped body.
  static const List<String> _promoMarkers = [
    'cashback of up to',
    'cashback up to',
    'get a cashback',
    'up to inr',
    'up to rs',
    'upto inr',
    'upto rs',
    'earn up to',
    'earn upto',
    'apply now',
    'limited period',
    'exclusive offer',
    'avail this offer',
    'offer ends',
    'reward points',
    'voucher',
    'congratulations',
    'as low as',
    'coverage against',
    'insurance coverage',
    'life insurance',
    'peace of mind',
  ];

  /// "up to INR 750", "upto Rs 750", "up to 50% cashback" — an offer cap. The
  /// trailing number requirement keeps "valid up to a date" from matching.
  static final RegExp _offerAmount =
      RegExp(r'up\s*to\s*(?:inr|rs\.?|₹)?\s*[\d,]+', caseSensitive: false);

  bool _isPromotional(String lower) =>
      _offerAmount.hasMatch(lower) || _promoMarkers.any(lower.contains);

  /// keywords. Order matters: recurring (AutoPay/EMI) is checked first.
  ({String category, String instrument, String type, bool recurring})
      _classify(String body) {
    final b = body.toLowerCase();
    bool has(String s) => b.contains(s);
    // Whole-word match — avoids substring false positives like "pr-emi-um"
    // hitting 'emi' or "st-atm-..." hitting 'atm'.
    bool hasWord(String w) => RegExp('\\b$w\\b').hasMatch(b);

    if (has('autopay') || has('mandate')) {
      return (
        category: 'UPI AutoPay Mandate Debit',
        instrument: 'upi',
        type: 'expense',
        recurring: true
      );
    }
    if (hasWord('emi') && (has('debited') || has('debit'))) {
      return (category: 'Loan EMI Debit', instrument: 'loan', type: 'expense', recurring: true);
    }
    if (has('withdrawn') || hasWord('atm')) {
      return (category: 'ATM Withdrawal', instrument: 'atm', type: 'expense', recurring: false);
    }
    if (has('debit card') && (has('debited') || has('spent'))) {
      return (category: 'Debit Card POS Purchase', instrument: 'card', type: 'expense', recurring: false);
    }
    if (has('credit card') &&
        (has('spent') || has('used for a transaction') || has('has been spent'))) {
      return (category: 'Credit Card Purchase', instrument: 'card', type: 'expense', recurring: false);
    }
    if (has('upi') && has('debited')) {
      return (category: 'UPI Debit', instrument: 'upi', type: 'expense', recurring: false);
    }
    if (has('upi') && has('credited')) {
      return (category: 'UPI Credit', instrument: 'upi', type: 'income', recurring: false);
    }
    if (has('imps') && has('debited')) {
      return (category: 'IMPS Debit', instrument: 'imps', type: 'expense', recurring: false);
    }
    if (has('imps') && has('credited')) {
      return (category: 'IMPS Credit', instrument: 'imps', type: 'income', recurring: false);
    }
    if (has('credited') &&
        (has('salary') || has('neft') || has('rtgs') || has('deposit'))) {
      return (category: 'Account Credit', instrument: 'neft', type: 'income', recurring: false);
    }
    if (has('refund') || has('reversal') || has('credited back')) {
      return (category: 'Refund / Reversal', instrument: 'refund', type: 'income', recurring: false);
    }
    if ((has('charges') || has('fee') || has('gst')) && has('debited')) {
      return (category: 'Bank Charges', instrument: 'charge', type: 'expense', recurring: false);
    }
    if (has('interest') && has('credited')) {
      return (category: 'Interest Credit', instrument: 'interest', type: 'income', recurring: false);
    }
    // Generic debit / credit.
    if (has('debited') || has('spent') || has('withdrawn')) {
      return (category: 'Debit', instrument: 'other', type: 'expense', recurring: false);
    }
    if (has('credited') || has('received') || has('deposited')) {
      return (category: 'Credit', instrument: 'other', type: 'income', recurring: false);
    }
    return (category: 'Transaction', instrument: 'other', type: 'expense', recurring: false);
  }

  /// Parses a single email body. Returns null if the amount can't be found.
  /// [emailDate] is the message's received time, used when the body has no
  /// date of its own (e.g. HDFC credit alerts).
  ParsedTransaction? parseEmail(String rawBody, String emailId,
      {DateTime? emailDate, String? senderEmail}) {
    try {
      // Bank alerts are usually HTML tables — strip tags & collapse whitespace
      // so values split across cells (e.g. "INR" | "2") become parseable text.
      final body = _preprocess(rawBody);

      final lower = body.toLowerCase();

      // Skip non-transactions: pre-notifications of an UPCOMING debit (standing
      // instructions / autopay / bills only "due"), and advisory / policy /
      // marketing notices that merely mention an amount (e.g. a transfer-limit
      // notice). Importing these would create phantom transactions.
      if (_isUpcomingDebit(lower) || _isAdvisory(lower)) {
        debugPrint('=== SKIPPED (not a transaction: due/advisory notice) ===');
        return null;
      }

      // ICICI Credit Card has its own format — handle it before the generic
      // bank parsers.
      if (lower.contains('icici bank credit card') &&
          lower.contains('has been used for a transaction')) {
        return _parseIciciCreditCard(body, emailId);
      }

      // ICICI Credit Card BILL PAYMENT received, e.g. "We have received
      // payment of INR 25,000.00 on your ICICI Bank Credit Card account
      // 6528 XXXX XXXX 5004 on 13-May-2026." This is the credit side of the
      // bill payment (the card's outstanding reduced) → income.
      if (lower.contains('received payment') &&
          lower.contains('credit card') &&
          lower.contains('icici')) {
        final parsed = _parseIciciCardPayment(body, emailId);
        if (parsed != null) return parsed;
      }

      // ICICI "You have made an online …" alerts — fund transfer, IMPS / NEFT
      // payment, etc. ("…of [Rs.] X towards MERCHANT on DATE from your ICICI
      // Bank … Account …"). The merchant follows "towards" but is sometimes
      // followed by "on <date>" instead of "from", and the universal parser
      // also matches the "to" inside "towards" → use a dedicated handler.
      if (lower.contains('you have made an online') &&
          lower.contains('towards') &&
          lower.contains('icici')) {
        final parsed = _parseIciciTransfer(body, emailId);
        if (parsed != null) return parsed;
      }

      // ICICI savings/current account credit or debit carrying an "Info:" note,
      // e.g. interest paid: "Your ICICI Bank Account XX800 has been credited
      // with INR 319 on 30-Jun-26. Info: XX800:Int.Pd:...". The universal parser
      // otherwise scrapes the scam-warning footer ("...be a bank employee") as
      // the merchant, so handle it here.
      if (lower.contains('icici') &&
          lower.contains('bank account') &&
          (lower.contains('has been credited') ||
              lower.contains('has been debited')) &&
          lower.contains('info:')) {
        final parsed = _parseIciciAccountAlert(body, emailId);
        if (parsed != null) return parsed;
      }

      // HDFC credit ("Rs.X has been successfully credited to your HDFC Bank
      // account ending in 0229"). Checked BEFORE the debit handler so a UPI
      // credit (which also contains "upi") isn't mis-routed to it as a debit.
      final fromHdfc =
          senderEmail != null && senderEmail.toLowerCase().contains('hdfcbank');
      if ((lower.contains('has been successfully credited') ||
              lower.contains('has been successfully added')) &&
          (lower.contains('hdfc') || lower.contains('account ending'))) {
        final parsed = _parseHdfcCredit(body, emailId, emailDate);
        if (parsed != null) return parsed;
      }

      // HDFC UPI debit / fund transfer ("... debited from your account ending
      // 0229 towards VPA ..."). Debits only — credits are handled above.
      if ((lower.contains('from your account ending') &&
              lower.contains('towards vpa')) ||
          (fromHdfc &&
              lower.contains('upi') &&
              lower.contains('debited'))) {
        final parsed = _parseHdfc(body, emailId);
        if (parsed != null) return parsed;
      }

      // Axis Bank Credit Card — labeled format (1) OR the short
      // "INR X spent on credit card no. XX0261" format (2).
      final fromAxis =
          senderEmail != null && senderEmail.toLowerCase().contains('axis.bank.in');
      if (lower.contains('axis bank credit card transaction') ||
          (lower.contains('transaction amount') &&
              lower.contains('merchant name') &&
              lower.contains('axis')) ||
          (fromAxis && lower.contains('spent on credit card'))) {
        return _parseAxis(body, emailId);
      }

      // SBI Credit Card — sender onlinesbicard@sbicard.com, or "spent" with
      // "SBI Credit Card" / "SBI Card" (covers all SBI Card subject formats).
      if ((senderEmail != null &&
              senderEmail.toLowerCase().contains('sbicard.com')) ||
          ((lower.contains('sbi credit card') || lower.contains('sbi card')) &&
              lower.contains('spent'))) {
        return _parseSbiCreditCard(body, emailId);
      }

      // HSBC Credit Card, e.g. "your Credit card no ending with 4482, has been
      // used for INR 40472.80 for payment to TWALLET TELANGANA on 16 Jun 2026".
      // "card no ending with" isn't caught by the universal account regex, so
      // the card number (and the credit-card type) would otherwise be lost.
      final fromHsbc =
          senderEmail != null && senderEmail.toLowerCase().contains('hsbc');
      if ((fromHsbc || lower.contains('hsbc')) &&
          lower.contains('credit card') &&
          lower.contains('ending with') &&
          lower.contains('used for')) {
        final parsed = _parseHsbcCreditCard(body, emailId);
        if (parsed != null) return parsed;
      }

      // DBT / Government benefit transfer, e.g. "DBT/Govt. payment of Rs.
      // 3,790.40 credited to your Acc No. XXXXX383879 on 28/05/26-SBI". "Acc
      // No." isn't matched by the universal account regex, and "to your Acc
      // No" gets picked up as the merchant.
      if (lower.contains('dbt') ||
          (lower.contains('govt') && lower.contains('payment'))) {
        final parsed = _parseGovtCredit(body, emailId, emailDate, senderEmail);
        if (parsed != null) return parsed;
      }

      // SBI savings/current account alert, e.g. "Your A/C XXXXX383879 Credited
      // INR 15,00,000.00 on 02/04/26 -Deposit by transfer from Mr. NAME. Avl
      // Bal INR 15,04,146.89-SBI". The payer/payee follows "from"/"to" (not
      // caught by the universal merchant regex), and the masked A/C + dd/MM/yy
      // date need dedicated handling.
      final fromSbi =
          senderEmail != null && senderEmail.toLowerCase().contains('sbi');
      if ((fromSbi || lower.contains('-sbi')) &&
          RegExp(r'a/?c\s*[x*]*\d', caseSensitive: false).hasMatch(lower) &&
          (lower.contains('credited') || lower.contains('debited')) &&
          lower.contains('avl bal')) {
        final parsed = _parseSbiAccount(body, emailId);
        if (parsed != null) return parsed;
      }

      // Kotak811 UPI payment / receipt email, e.g. "You have successfully made
      // a UPI payment of INR 160.00 towards KUNCHAKURI HARINATH through the
      // Kotak811 App ... UPI ID: q..@ybl ... UPI Reference Number: 6549...".
      // The universal parser mangles this: it matches the "to" inside "towards"
      // (its merchant regex is case-insensitive, so "wards ..." leaks in) and
      // misses the "UPI Reference Number:" ref, so handle it here.
      final fromKotak =
          senderEmail != null && senderEmail.toLowerCase().contains('kotak');
      if ((fromKotak || lower.contains('kotak')) &&
          lower.contains('upi') &&
          (lower.contains('upi payment') ||
              lower.contains('upi credit') ||
              lower.contains('made a upi') ||
              lower.contains('received a upi') ||
              lower.contains('kotak811'))) {
        final parsed = _parseKotakUpi(body, emailId, emailDate);
        if (parsed != null) return parsed;
      }

      // ── Universal parser (handles the common format for ALL 57 banks) ──
      debugPrint('=== PARSING EMAIL (universal) ===');

      final amount = _matchDouble(_uAmount, body);
      debugPrint('Amount found: $amount');
      if (amount == null) {
        debugPrint('=== PARSE FAILED === Could not parse amount');
        return null; // amount is required
      }

      final cls = _classify(body);

      // Merchant: UPI party ("UPI/P2M/<ref>/NAME") → universal
      // "at/to/towards/Merchant:" → labeled → Info fallback. The UPI party is
      // read from the RAW body first, where the newline/tag after the name is
      // still present to bound it (preprocessing collapses those to spaces, so a
      // trailing footer like "We're here to help you" would otherwise bleed in).
      final merchant = _cleanMerchant(_matchGroup(_uUpiParty, rawBody)) ??
          _cleanMerchant(_matchGroup(_uUpiParty, body)) ??
          _cleanMerchant(_matchGroup(_uMerchant, body)) ??
          _cleanMerchant(_matchGroup(_merchantLabel, body)) ??
          _cleanInfo(_matchGroup(_infoLabel, body));

      final dateStr = _matchGroup(_genericDate, body);
      final account = _matchGroup(_uAccount, body);
      final ref = _matchGroup(_uRef, body) ??
          _matchGroup(_upiRef, body) ??
          _matchGroup(_uUpiRef, body);

      // Drop marketing/offer emails ("Get a cashback of up to INR 750...",
      // "...insurance coverage at a cost as low as INR 560/year..."). A real
      // transaction always carries a card/account number OR a reference; offers
      // carry neither. Skip when it reads as an offer AND has no such evidence,
      // so genuine alerts are never lost.
      final hasRealEvidence = account != null || ref != null;
      if (!hasRealEvidence && _isPromotional(lower)) {
        debugPrint('=== SKIPPED (promotional / offer email) ===');
        return null;
      }

      final bankName =
          bankFromSender(senderEmail) ?? _detectBank(body)?.name ?? 'Bank';

      debugPrint('Bank: $bankName | Category: ${cls.category} | '
          'Type: ${cls.type} | Recurring: ${cls.recurring}');

      return ParsedTransaction(
        amount: amount,
        type: cls.type,
        merchant: (merchant != null && merchant.isNotEmpty) ? merchant : null,
        date: _parseDate(dateStr) ?? emailDate ?? DateTime.now(),
        accountNumber: account != null ? 'XX$account' : null,
        availableBalance: _matchDouble(_balance, body),
        bankName: bankName,
        emailId: emailId,
        memo: ref != null ? 'Ref: $ref' : null,
        upiRef: ref,
        category: cls.category,
        instrumentType: cls.instrument,
        isRecurring: cls.recurring,
      );
    } catch (e) {
      debugPrint('=== PARSE FAILED === Exception: $e');
      return null;
    }
  }

  /// Dedicated parser for ICICI Bank Credit Card transaction alerts, e.g.
  /// "Your ICICI Bank Credit Card XX5004 has been used for a transaction of
  ///  INR 20.00 on Jun 09, 2026 at 11:51:28. Info: UPI-987838759482-GARBHANA."
  ///
  /// Credit-card usage is always a debit → type is always 'expense'.
  ParsedTransaction? _parseIciciCreditCard(String body, String emailId) {
    try {
      debugPrint('=== PARSING EMAIL ===');
      debugPrint('Bank detected: ICICI (Credit Card)');

      // Amount (required).
      final amount = _matchDouble(
          RegExp(r'INR\s*([\d,]+\.?\d*)', caseSensitive: false), body);
      debugPrint('Amount found: $amount');
      if (amount == null) {
        debugPrint('=== PARSE FAILED === Could not parse amount');
        return null;
      }

      // Card number → "XX5004".
      final cardDigits = _matchGroup(
          RegExp(r'Credit Card\s+XX(\d{4})', caseSensitive: false), body);
      final cardNumber = cardDigits != null ? 'XX$cardDigits' : null;

      // Payee: "Info: UPI-<ref>-NAME" → NAME (may be multi-word, e.g.
      // "SRI VENK" / "M S SAHR"), else the full Info string.
      var payee = _matchGroup(
          RegExp(r'Info:\s*UPI-\d+-([A-Za-z][A-Za-z ]*?)\s*(?:\.|$)',
              caseSensitive: false),
          body);
      payee ??= _matchGroup(RegExp(r'Info:\s*(.+?)(?:\.|$)'), body);
      payee = _cleanMerchant(payee);

      // Date "Jun 09, 2026" (MMM dd, yyyy).
      final dateStr = _matchGroup(
          RegExp(r'on\s+(\w+\s+\d{2},\s+\d{4})', caseSensitive: false), body);

      // UPI reference → memo.
      final upiRef = _matchGroup(RegExp(r'UPI-(\d+)-'), body);

      debugPrint('Type found: expense');
      debugPrint('Payee found: $payee');
      debugPrint(
          '=== PARSE SUCCESS === Amount: $amount Payee: $payee Type: expense');

      return ParsedTransaction(
        amount: amount,
        type: 'expense', // credit card usage is always a debit
        merchant: (payee != null && payee.isNotEmpty) ? payee : null,
        date: _parseDate(dateStr) ?? DateTime.now(),
        accountNumber: cardNumber,
        availableBalance: null,
        bankName: 'ICICI',
        emailId: emailId,
        memo: upiRef != null ? 'UPI: $upiRef' : null,
        accountType: 'credit_card',
        upiRef: upiRef,
        category: 'Credit Card Purchase',
        instrumentType: 'card',
      );
    } catch (e) {
      debugPrint('=== PARSE FAILED === ICICI CC exception: $e');
      return null;
    }
  }

  /// ICICI Credit Card bill-payment received, e.g. "We have received payment
  /// of INR 25,000.00 on your ICICI Bank Credit Card account 6528 XXXX XXXX
  /// 5004 on 13-May-2026." This is the payment *into* the card (outstanding
  /// reduced), the credit side of paying the bill → income.
  ParsedTransaction? _parseIciciCardPayment(String body, String emailId) {
    try {
      final amount = _matchDouble(
          RegExp(
              r'payment of\s+(?:INR|Rs\.?|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
              caseSensitive: false),
          body);
      if (amount == null) return null;

      // Card number is the last visible group, "… XXXX XXXX 5004 on …".
      final cardDigits = _matchGroup(
          RegExp(r'(\d{4})\s+on\b', caseSensitive: false), body);

      final dateStr = _matchGroup(
          RegExp(r'on\s+(\d{1,2}-[A-Za-z]{3}-\d{4})', caseSensitive: false),
          body);

      return ParsedTransaction(
        amount: amount,
        type: 'income', // payment received on the card (bill settled)
        merchant: 'ICICI Credit Card Payment',
        date: _parseDate(dateStr) ?? DateTime.now(),
        accountNumber: cardDigits != null ? 'XX$cardDigits' : null,
        availableBalance: null,
        bankName: 'ICICI',
        emailId: emailId,
        accountType: 'credit_card',
        category: 'Card Bill Payment',
        instrumentType: 'card',
      );
    } catch (e) {
      debugPrint('=== PARSE FAILED === ICICI card payment: $e');
      return null;
    }
  }

  /// ICICI "You have made an online …" alerts, e.g.
  ///   "…online ICICI fund transfer of 1,00,000.00 towards CHALLA RAJINEEKAR
  ///    from your ICICI Bank Savings Account XXXX800 to ICICI Bank CCA Account
  ///    XXXX231 on Jun 26, 2026 …The Transaction ID is 88575546."
  ///   "…online IMPS payment of Rs. 1,99,999.00 towards SHIVANAGENDRA FLASH
  ///    TRANSPORT on May 28, 2026 … from your ICICI Bank Savings Account
  ///    XXXX4800. The Transaction ID is 614808918922."
  ///
  /// The amount may lack an INR/Rs prefix and the merchant is followed by
  /// "on DATE" or "from ACCOUNT", which the universal parser mishandles
  /// (it matches the "to" inside "towards"). Money leaving the account is a
  /// debit → 'expense'.
  ParsedTransaction? _parseIciciTransfer(String body, String emailId) {
    try {
      // "…of [Rs.] <amount> towards …" — anchored by "of … towards".
      final amount = _matchDouble(
          RegExp(r'of\s+(?:INR|Rs\.?|₹)?\s*([\d,]+(?:\.\d{1,2})?)\s+towards',
              caseSensitive: false),
          body);
      if (amount == null) return null;

      // Merchant after "towards", stopping at "on <date>" or "from <account>".
      final payee = _cleanMerchant(_matchGroup(
          RegExp(r"towards\s+([A-Za-z0-9][A-Za-z0-9 ./&'-]+?)\s+(?:on|from)\b",
              caseSensitive: false),
          body));

      // Source account (the debited one) — "Savings/Current Account XXXX800".
      final acct = _matchGroup(
          RegExp(r'(?:Savings|Current)\s+Account\s+[Xx*]*(\d{3,4})',
              caseSensitive: false),
          body);

      final dateStr = _matchGroup(
          RegExp(r'on\s+([A-Za-z]{3}\s+\d{1,2},\s+\d{4})',
              caseSensitive: false),
          body);

      final ref = _matchGroup(
          RegExp(r'Transaction ID is\s+(\d+)', caseSensitive: false), body);

      final lower = body.toLowerCase();
      final instrument = lower.contains('imps')
          ? 'imps'
          : lower.contains('neft')
              ? 'neft'
              : lower.contains('rtgs')
                  ? 'rtgs'
                  : 'transfer';
      // Transfer to a credit-card account (CCA) is a card bill payment.
      final toCard =
          RegExp(r'to\b[^.]*(?:\bCCA\b|Credit Card)', caseSensitive: false)
              .hasMatch(body);

      return ParsedTransaction(
        amount: amount,
        type: 'expense',
        merchant: (payee != null && payee.isNotEmpty) ? payee : null,
        date: _parseDate(dateStr) ?? DateTime.now(),
        accountNumber: acct != null ? 'XX$acct' : null,
        availableBalance: null,
        bankName: 'ICICI',
        emailId: emailId,
        memo: ref != null ? 'Txn ID: $ref' : null,
        upiRef: ref,
        category: toCard ? 'Card Bill Payment' : 'Transfer',
        instrumentType: instrument,
      );
    } catch (e) {
      debugPrint('=== PARSE FAILED === ICICI transfer: $e');
      return null;
    }
  }

  /// Kotak811 UPI payment / receipt emails. Covers both layouts Kotak sends:
  ///   DEBIT (prose): "You have successfully made a UPI payment of INR 160.00
  ///     towards KUNCHAKURI HARINATH through the Kotak811 App. ...
  ///     UPI ID: q17..@ybl  Date: 02/07/2026  UPI Reference Number: 654903271185"
  ///   CREDIT (labeled): "You've received a UPI Credit in your Kotak A/c
  ///     (XXXXXX3304). ... Date: 03/07/2026  Amount: ₹50.00
  ///     Sender: Gangula Ashwin Reddy  UPI Reference Number (RRN): 618435164925"
  /// A payment made is money leaving the account → 'expense'; a "received"
  /// credit → 'income'.
  ParsedTransaction? _parseKotakUpi(
      String body, String emailId, DateTime? emailDate) {
    try {
      final lower = body.toLowerCase();

      final amount = _matchDouble(
          RegExp(r'(?:INR|Rs\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)',
              caseSensitive: false),
          body);
      if (amount == null) return null;

      // "received … credit" → income; anything else (a payment made) → expense.
      final isCredit = lower.contains('received') && !lower.contains('made a');

      // Counterparty, tried most-specific first. Labeled forms ("Sender:" for a
      // credit, "Receiver/Beneficiary/Payee:" for a debit) are bounded by the
      // next field label; the prose forms ("towards"/"from") stop at the
      // "through the Kotak811 App" tail or a date/period.
      String? merchant;
      for (final p in const [
        r'Sender\s*:?\s*([A-Za-z][A-Za-z .]+?)\s+(?:UPI|Date|Amount|RRN|Ref|$)',
        r'(?:Receiver|Beneficiary|Payee)\s*:?\s*([A-Za-z][A-Za-z .]+?)'
            r'\s+(?:UPI|Date|Amount|RRN|Ref|$)',
        r"towards\s+([A-Za-z0-9][A-Za-z0-9 .&'/-]+?)\s*(?:through|on|\.|,|$)",
        r"from\s+([A-Za-z0-9][A-Za-z0-9 .&'/-]+?)\s*(?:through|on|\.|,|$)",
      ]) {
        merchant =
            _cleanMerchant(_matchGroup(RegExp(p, caseSensitive: false), body));
        if (merchant != null && merchant.isNotEmpty) break;
      }

      final vpa = _matchGroup(
          RegExp(r'UPI\s*ID\s*:?\s*([a-z0-9._\-]+@[a-z]{2,})',
              caseSensitive: false),
          body);

      // "UPI Reference Number: 6549..." OR "UPI Reference Number (RRN): 6184...".
      final ref = _matchGroup(
          RegExp(
              r'UPI\s+Reference\s+(?:Number|No)\.?\s*(?:\(?\s*RRN\s*\)?)?\s*:?\s*(\d+)',
              caseSensitive: false),
          body);

      // Masked account, e.g. "Kotak A/c (XXXXXX3304)" → "XX3304".
      final acctDigits = _matchGroup(
          RegExp(r'A/?c\s*\(?\s*[Xx*]*(\d{3,4})', caseSensitive: false), body);
      final account = acctDigits != null ? 'XX$acctDigits' : null;

      final dateStr = _matchGroup(
          RegExp(r'Date\s*:?\s*(\d{1,2}/\d{1,2}/\d{2,4})',
              caseSensitive: false),
          body);

      return ParsedTransaction(
        amount: amount,
        type: isCredit ? 'income' : 'expense',
        merchant: (merchant != null && merchant.isNotEmpty) ? merchant : null,
        date: _parseDate(dateStr) ?? emailDate ?? DateTime.now(),
        accountNumber: account,
        availableBalance: null,
        bankName: 'Kotak',
        emailId: emailId,
        memo: ref != null ? 'Ref: $ref' : null,
        upiRef: ref,
        upiVpa: vpa,
        category: isCredit ? 'UPI Credit' : 'UPI Debit',
        instrumentType: 'upi',
      );
    } catch (e) {
      debugPrint('=== PARSE FAILED === Kotak UPI: $e');
      return null;
    }
  }

  /// ICICI savings/current account credit or debit with an "Info:" note (e.g.
  /// quarterly interest: "...Account XX800 has been credited with INR 319 on
  /// 30-Jun-26. Info: XX800:Int.Pd:30-03-2026 to 29-06-2026.").
  ParsedTransaction? _parseIciciAccountAlert(String body, String emailId) {
    try {
      final lower = body.toLowerCase();
      final isCredit = lower.contains('has been credited');

      final amount = _matchDouble(
          RegExp(
              r'(?:credited|debited)\s+with\s+(?:INR|Rs\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)',
              caseSensitive: false),
          body);
      if (amount == null) return null;

      // "Account XX800" → masked number.
      final acctDigits = _matchGroup(
          RegExp(r'account\s+[Xx*]*(\d{3,})', caseSensitive: false), body);
      final account = acctDigits != null ? 'XX$acctDigits' : null;

      // Transaction date follows "on" (e.g. "on 30-Jun-26"), NOT the Info-period
      // dates that trail it.
      final dateStr = _matchGroup(
          RegExp(r'on\s+(\d{1,2}-[A-Za-z]{3}-\d{2,4})', caseSensitive: false),
          body);

      // Merchant/label from the Info note. Interest payout → "Interest";
      // otherwise the first descriptive word after the "XXxxxx:" prefix.
      final isInterest =
          lower.contains('int.pd') || lower.contains('interest');
      String? label;
      if (isInterest) {
        label = 'Interest';
      } else {
        final info = _matchGroup(
            RegExp(r'Info:\s*(.+)', caseSensitive: false), body);
        if (info != null) {
          final rest = info.replaceFirst(RegExp(r'^[Xx*\d]+:?\s*'), '');
          label = RegExp(r'[A-Za-z][A-Za-z ]{1,}').firstMatch(rest)?.group(0)?.trim();
        }
      }

      return ParsedTransaction(
        amount: amount,
        type: isCredit ? 'income' : 'expense',
        merchant: (label != null && label.isNotEmpty) ? label : null,
        date: _parseDate(dateStr) ?? DateTime.now(),
        accountNumber: account,
        availableBalance: null,
        bankName: 'ICICI',
        emailId: emailId,
        category: isInterest
            ? 'Interest Credit'
            : (isCredit ? 'Account Credit' : 'Account Debit'),
        instrumentType: isInterest ? 'interest' : 'transfer',
      );
    } catch (e) {
      debugPrint('=== PARSE FAILED === ICICI account alert: $e');
      return null;
    }
  }

  /// Phrases that mark an email as a *future* / *due* debit notification
  /// (standing instruction, autopay mandate, bill reminder) rather than a
  /// completed transaction. A real alert says "has been debited" (past tense),
  /// never "will be debited" / "is due".
  static const List<String> _upcomingDebitPhrases = [
    'will be debited',
    'will be deducted',
    'is due on',
    'payment is due',
    'due for payment',
    'is scheduled',
    'to cancel this debit',
    'cancel this standing instruction',
    // Upcoming / scheduled AutoPay notice — "...summary of your upcoming
    // AutoPay transaction ... To be debited by: 06-07-2026". Nothing has been
    // debited yet, so it must not be imported.
    'upcoming autopay',
    'to be debited by',
    'upcoming transaction',
  ];

  bool _isUpcomingDebit(String lower) =>
      _upcomingDebitPhrases.any(lower.contains);

  /// Phrases that mark an email as advisory / policy / marketing — it mentions
  /// an amount (a limit, an offer, a threshold) but no money actually moved.
  /// A real alert never says "transfer limit" / "will soon be applicable".
  static const List<String> _advisoryPhrases = [
    'will soon be applicable',
    'transfer limit',
    'limits on new beneficiar',
    'newly added beneficiar',
    'capped at',
    'terms and conditions apply',
    'to protect your account',
    // Scheduled-maintenance / service-outage notices — mention a threshold
    // amount (e.g. "ATM transactions below Rs. 20,000") but no money moved.
    'scheduled maintenance',
    'system maintenance',
    'services will be unavailable',
    'services unavailable',
    'will be unavailable',
    'will be intermittently unavailable',
    'undergoing a scheduled',
  ];

  bool _isAdvisory(String lower) => _advisoryPhrases.any(lower.contains);

  /// SBI savings/current account credit or debit alert, e.g. "Your A/C
  /// XXXXX383879 Credited INR 15,00,000.00 on 02/04/26 -Deposit by transfer
  /// from Mr. SADASHIVA REDDY. Avl Bal INR 15,04,146.89-SBI".
  ParsedTransaction? _parseSbiAccount(String body, String emailId) {
    try {
      final lower = body.toLowerCase();
      final isCredit = lower.contains('credited');

      final amount = _matchDouble(
          RegExp(
              r'(?:credited|debited)\s+(?:INR|Rs\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)',
              caseSensitive: false),
          body);
      if (amount == null) return null;

      // A/C XXXXX383879 → last 4 digits ("XX3879").
      final acctDigits = _matchGroup(
          RegExp(r'A/?C\s*[Xx*]*(\d{3,})', caseSensitive: false), body);
      final acct = acctDigits == null
          ? null
          : 'XX${acctDigits.length > 4 ? acctDigits.substring(acctDigits.length - 4) : acctDigits}';

      // Date dd/MM/yy or dd/MM/yyyy.
      final dateStr = _matchGroup(
          RegExp(r'on\s+(\d{1,2}/\d{1,2}/\d{2,4})', caseSensitive: false), body);

      // Payer (credit) / payee (debit) after "from"/"to", up to "Avl" or end.
      final payee = _cleanMerchant(_matchGroup(
          RegExp(r'(?:from|to)\s+([A-Za-z][A-Za-z0-9.\s&/-]+?)\s*\.?\s*(?:Avl|$)',
              caseSensitive: false),
          body));

      final bal = _matchDouble(
          RegExp(r'Avl\s*Bal\.?\s*(?:INR|Rs\.?|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
              caseSensitive: false),
          body);

      return ParsedTransaction(
        amount: amount,
        type: isCredit ? 'income' : 'expense',
        merchant: (payee != null && payee.isNotEmpty) ? payee : null,
        date: _parseDate(dateStr) ?? DateTime.now(),
        accountNumber: acct,
        availableBalance: bal,
        bankName: 'SBI',
        emailId: emailId,
        category: isCredit ? 'Account Credit' : 'Account Debit',
        instrumentType: 'transfer',
      );
    } catch (e) {
      debugPrint('=== PARSE FAILED === SBI account: $e');
      return null;
    }
  }

  /// DBT / Government benefit transfer credit, e.g. "DBT/Govt. payment of Rs.
  /// 3,790.40 credited to your Acc No. XXXXX383879 on 28/05/26-SBI". The payer
  /// is the government scheme, so the merchant is a fixed label; "Acc No." and
  /// the dd/MM/yy date aren't handled by the universal parser.
  ParsedTransaction? _parseGovtCredit(String body, String emailId,
      DateTime? emailDate, String? senderEmail) {
    try {
      final amount = _matchDouble(
          RegExp(r'(?:INR|Rs\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)',
              caseSensitive: false),
          body);
      if (amount == null) return null;

      final lower = body.toLowerCase();
      final isCredit = lower.contains('credited') || !lower.contains('debited');

      // "Acc No. XXXXX383879" / "A/c No XXXX1234" → trailing digits.
      final acct = _matchGroup(
          RegExp(r'(?:Acc(?:ount)?|A/c)\.?\s*No\.?\s*[Xx*]*(\d{3,})',
              caseSensitive: false),
          body);

      // Date "28/05/26" (dd/MM/yy) or dd/MM/yyyy.
      final dateStr = _matchGroup(
          RegExp(r'(\d{1,2}/\d{1,2}/\d{2,4})'), body);

      return ParsedTransaction(
        amount: amount,
        type: isCredit ? 'income' : 'expense',
        merchant: 'DBT/Govt Payment',
        date: _parseDate(dateStr) ?? emailDate ?? DateTime.now(),
        accountNumber: acct != null ? 'XX$acct' : null,
        availableBalance: null,
        bankName: bankFromSender(senderEmail) ?? _detectBank(body)?.name ?? 'Bank',
        emailId: emailId,
        category: isCredit ? 'Income' : 'Other',
        instrumentType: 'transfer',
      );
    } catch (e) {
      debugPrint('=== PARSE FAILED === DBT/Govt credit: $e');
      return null;
    }
  }

  /// HSBC Credit Card transaction alert, e.g. "your Credit card no ending with
  /// 4482, has been used for INR 40472.80 for payment to TWALLET TELANGANA on
  /// 16 Jun 2026 at 16:21." Credit-card usage is always a debit → 'expense'.
  ParsedTransaction? _parseHsbcCreditCard(String body, String emailId) {
    try {
      final amount = _matchDouble(
          RegExp(r'(?:INR|Rs\.?)\s*([\d,]+(?:\.\d{1,2})?)',
              caseSensitive: false),
          body);
      if (amount == null) return null;

      final cardDigits = _matchGroup(
          RegExp(r'ending with\s+(\d{4})', caseSensitive: false), body);

      final payee = _cleanMerchant(_matchGroup(
          RegExp(r'payment to\s+([A-Za-z0-9][A-Za-z0-9 ./&\x27-]+?)\s+on\b',
              caseSensitive: false),
          body));

      final dateStr = _matchGroup(
          RegExp(r'on\s+(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})', caseSensitive: false),
          body);

      return ParsedTransaction(
        amount: amount,
        type: 'expense',
        merchant: (payee != null && payee.isNotEmpty) ? payee : null,
        date: _parseDate(dateStr) ?? DateTime.now(),
        accountNumber: cardDigits != null ? 'XX$cardDigits' : null,
        availableBalance: null,
        bankName: 'HSBC',
        emailId: emailId,
        accountType: 'credit_card',
        category: 'Credit Card Purchase',
        instrumentType: 'card',
      );
    } catch (e) {
      debugPrint('=== PARSE FAILED === HSBC CC exception: $e');
      return null;
    }
  }

  /// Dedicated parser for HDFC UPI debit / fund-transfer alerts, e.g.
  /// "Rs.10.00 is debited from your account ending 0229 towards VPA
  ///  AIRTELPREDIRECT1@axl (Airtel Recharge) on 10-06-26."
  ParsedTransaction? _parseHdfc(String body, String emailId) {
    try {
      debugPrint('=== PARSING EMAIL ===');
      debugPrint('Bank detected: HDFC');

      // OTP / failed-payment mails are dropped by the subject filter; don't
      // re-check the body (footers say "Never share your OTP" → false skips).
      final lower = body.toLowerCase();

      // Amount (required).
      final amount =
          _matchDouble(RegExp(r'Rs\.(\d+(?:\.\d{1,2})?)'), body);
      debugPrint('Amount found: $amount');
      if (amount == null) {
        debugPrint('=== PARSE FAILED === Could not parse amount');
        return null;
      }

      // Type.
      final type = lower.contains('is credited') ? 'income' : 'expense';

      // A UPI payment made *with* a credit card is a credit-card spend — flag
      // it so it links to the credit-card account and reads as such.
      final isCreditCard = lower.contains('credit card');

      // Account / card → "XX0229" (covers "account ending 0229",
      // "Credit Card ending 5212" and "Credit Card (ending 5212)").
      final acctDigits = _matchGroup(
          RegExp(r'(?:account|card)\s*\(?\s*ending\s*(?:in\s+)?(\d{4})',
              caseSensitive: false),
          body);
      final account = acctDigits != null ? 'XX$acctDigits' : null;

      // Payee, in priority order:
      //  (1) merchant name in brackets after "VPA <id>" — "VPA x (NAME)"
      //  (2) the VPA id after "towards/to VPA"
      //  (3) "Paid to <vpa>" format (no VPA keyword)
      // "to" is only honoured right before "VPA" so intro text like "to help"
      // is never mistaken for the payee.
      var payee = _matchGroup(
          RegExp(r'(?:towards|to)\s+VPA\s+\S+\s*\(([^)]+)\)',
              caseSensitive: false),
          body);
      payee ??= _matchGroup(
          RegExp(r'(?:towards|to)\s+VPA\s+(\S+)', caseSensitive: false), body);
      payee ??= _matchGroup(
          RegExp(r'paid to\s+(\S+)', caseSensitive: false), body);
      payee = _cleanMerchant(payee);

      // Date — DD-MM-YY first, else any generic format ("26 May, 2026").
      final dateStr =
          _matchGroup(RegExp(r'on\s+(\d{2}-\d{2}-\d{2})\.?'), body) ??
              _matchGroup(_genericDate, body);

      // UPI reference → memo "UPI Ref: <ref>".
      final upiRef = _matchGroup(_upiRef, body);

      debugPrint('Type found: $type');
      debugPrint('Payee found: $payee');
      debugPrint(
          '=== PARSE SUCCESS === Amount: $amount Payee: $payee Type: $type');

      return ParsedTransaction(
        amount: amount,
        type: type,
        merchant: (payee != null && payee.isNotEmpty) ? payee : null,
        date: _parseDate(dateStr) ?? DateTime.now(),
        accountNumber: account,
        availableBalance: null,
        bankName: 'HDFC',
        emailId: emailId,
        memo: upiRef != null ? 'UPI Ref: $upiRef' : null,
        upiRef: upiRef,
        accountType: isCreditCard ? 'credit_card' : null,
        category: isCreditCard
            ? 'Credit Card Purchase'
            : (type == 'income' ? 'UPI Credit' : 'UPI Debit'),
        instrumentType: 'upi',
      );
    } catch (e) {
      debugPrint('=== PARSE FAILED === HDFC exception: $e');
      return null;
    }
  }

  /// HDFC credit (income) alert, e.g. "Rs.100.00 has been successfully credited
  /// to your HDFC Bank account ending in 0229." Has no date in the body, so the
  /// email's received date ([emailDate]) is used.
  ParsedTransaction? _parseHdfcCredit(
      String body, String emailId, DateTime? emailDate) {
    try {
      debugPrint('=== PARSING EMAIL ===');
      debugPrint('Bank detected: HDFC (Credit)');


      // Amount (required). Handles "Rs.500.00 has been successfully credited"
      // AND "Rs.INR 5,000.00 has been successfully added" (doubled prefix).
      var amount = _matchDouble(
          RegExp(
              r'(?:Rs\.?\s*)?INR\s*([\d,]+(?:\.\d{1,2})?)\s+has been successfully',
              caseSensitive: false),
          body);
      amount ??= _matchDouble(
          RegExp(r'Rs\.?\s*([\d,]+(?:\.\d{1,2})?)\s+has been successfully',
              caseSensitive: false),
          body);
      amount ??= _matchDouble(
          RegExp(r'(?:Rs\.?\s*)?INR\s*([\d,]+(?:\.\d{1,2})?)',
              caseSensitive: false),
          body);
      amount ??= _matchDouble(
          RegExp(r'Rs\.?\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false), body);
      debugPrint('Amount found: $amount');
      if (amount == null) {
        debugPrint('=== PARSE FAILED === Could not parse amount');
        return null;
      }

      // Account → "XX0229" ("ending in 0229" or "ending XX0229").
      final acctDigits = _matchGroup(
          RegExp(r'ending\s+(?:in\s+)?[Xx*]*(\d{3,4})', caseSensitive: false),
          body);
      final account = acctDigits != null ? 'XX$acctDigits' : null;

      // Sender / payer name:
      //   "Sender: CHALLA RAJINEEKAR (VPA: rajini1203@ibl)"   (UPI)
      //   "from NEFT Cr-ICIC0SF0002-CHALLA RAJINEEKAR-…"      (NEFT / IMPS)
      var sender = _cleanMerchant(_matchGroup(
          RegExp(r'Sender:\s*([A-Za-z][A-Za-z .]+?)\s*(?:\(|$)',
              caseSensitive: false),
          body));
      sender ??= _cleanMerchant(_matchGroup(
          RegExp(r'(?:NEFT|IMPS|RTGS)\s*Cr-[^-]*-([A-Za-z][A-Za-z .]+?)-',
              caseSensitive: false),
          body));

      final vpa = _matchGroup(
          RegExp(r'([a-z0-9._\-]+@[a-z]{2,})', caseSensitive: false), body);

      // Date — "Date: 26-05-26" (dd-MM-yy) or "on 13-MAY-2026" (dd-MMM-yyyy).
      var dateStr = _matchGroup(
          RegExp(r'Date:\s*(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})',
              caseSensitive: false),
          body);
      dateStr ??= _matchGroup(
          RegExp(r'on\s+(\d{1,2}-[A-Za-z]{3}-\d{4})', caseSensitive: false),
          body);

      // "UPI Reference No.: 020586230285" (NEFT credits don't carry one).
      final ref = _matchGroup(
          RegExp(r'(?:UPI\s*Reference\s*No\.?|Ref(?:erence)?\s*No\.?)\s*:?\s*(\d+)',
              caseSensitive: false),
          body);

      // "available balance … Rs. INR 5,022.98".
      final balance = _matchDouble(
          RegExp(
              r'available balance[^0-9]*(?:Rs\.?\s*)?(?:INR\s*)?([\d,]+(?:\.\d{1,2})?)',
              caseSensitive: false),
          body);

      final lower = body.toLowerCase();
      final instrument = lower.contains('neft')
          ? 'neft'
          : lower.contains('imps')
              ? 'imps'
              : lower.contains('rtgs')
                  ? 'rtgs'
                  : (vpa != null || lower.contains('upi'))
                      ? 'upi'
                      : 'neft';
      final isUpi = instrument == 'upi';

      debugPrint('=== PARSE SUCCESS === Amount: $amount Type: income '
          'Sender: $sender');

      return ParsedTransaction(
        amount: amount,
        type: 'income',
        merchant: (sender != null && sender.isNotEmpty)
            ? sender
            : 'HDFC Bank Credit',
        date: _parseDate(dateStr) ?? emailDate ?? DateTime.now(),
        accountNumber: account,
        availableBalance: balance,
        bankName: 'HDFC',
        emailId: emailId,
        memo: ref != null ? 'Ref: $ref' : null,
        upiRef: ref,
        upiVpa: vpa,
        category: isUpi ? 'UPI Credit' : 'Account Credit',
        instrumentType: instrument,
      );
    } catch (e) {
      debugPrint('=== PARSE FAILED === HDFC credit exception: $e');
      return null;
    }
  }

  /// Dedicated parser for Axis Bank Credit Card transaction alerts (labeled
  /// fields). Credit-card usage is always a debit → type is always 'expense'.
  ///
  /// NB: [_preprocess] has collapsed the original newline-separated labels to
  /// single spaces, so patterns are written for "Label: value" on one line.
  ParsedTransaction? _parseAxis(String body, String emailId) {
    try {
      debugPrint('=== PARSING EMAIL ===');
      debugPrint('Bank detected: Axis (Credit Card)');


      // Amount: format-1 label, then format-2 "INR X spent", then first INR.
      var amount = _matchDouble(
          RegExp(r'Transaction Amount:\s*INR\s*([\d,]+\.?\d*)',
              caseSensitive: false),
          body);
      amount ??= _matchDouble(
          RegExp(r'INR\s*([\d,]+(?:\.\d{1,2})?)\s+spent', caseSensitive: false),
          body);
      amount ??= _matchDouble(
          RegExp(r'INR\s*([\d,]+\.?\d*)', caseSensitive: false), body);
      debugPrint('Amount found: $amount');
      if (amount == null) {
        debugPrint('=== PARSE FAILED === Could not parse amount');
        return null;
      }

      // Merchant — captured up to the next field label.
      final merchant = _cleanMerchant(_matchGroup(
          RegExp(
              r'Merchant Name:\s*([A-Za-z0-9][A-Za-z0-9 ._&/-]*?)\s*'
              r'(?:Axis|Card|Date|Available|Total)',
              caseSensitive: false),
          body));

      // Card number → "XX0261".
      final card = _matchGroup(
          RegExp(r'Credit Card No\.?\s*(XX\d{4})', caseSensitive: false),
          body);

      // Date (DD-MM-YYYY) + time (HH:mm:ss IST), combined into the DateTime.
      final dateStr = _matchGroup(
          RegExp(r'Date\s*&\s*Time:\s*(\d{2}-\d{2}-\d{4})',
              caseSensitive: false),
          body);
      final timeStr =
          _matchGroup(RegExp(r'(\d{2}:\d{2}:\d{2})\s*IST'), body);
      var date = _parseDate(dateStr) ?? DateTime.now();
      if (timeStr != null) {
        final tp = timeStr.split(':');
        if (tp.length == 3) {
          date = DateTime(date.year, date.month, date.day,
              int.tryParse(tp[0]) ?? 0,
              int.tryParse(tp[1]) ?? 0,
              int.tryParse(tp[2]) ?? 0);
        }
      }

      // Available limit → stored as availableBalance.
      final availLimit = _matchDouble(
          RegExp(r'Available Limit\*?:\s*INR\s*([\d,]+\.?\d*)',
              caseSensitive: false),
          body);

      debugPrint('Type found: expense');
      debugPrint('Payee found: $merchant');
      debugPrint(
          '=== PARSE SUCCESS === Amount: $amount Payee: $merchant Type: expense');

      return ParsedTransaction(
        amount: amount,
        type: 'expense', // credit card usage is always a debit
        merchant: (merchant != null && merchant.isNotEmpty) ? merchant : null,
        date: date,
        accountNumber: card,
        availableBalance: availLimit,
        bankName: 'Axis',
        emailId: emailId,
        accountType: 'credit_card',
        category: 'Credit Card Purchase',
        instrumentType: 'card',
      );
    } catch (e) {
      debugPrint('=== PARSE FAILED === Axis exception: $e');
      return null;
    }
  }

  /// Dedicated parser for SBI Credit Card transaction alerts, e.g.
  /// "Rs.51,015.97 spent on your SBI Credit Card ending 1157 at
  ///  TWALLETTELANGANA on 10/06/26." Always an expense (card spend).
  ///
  /// Note: the body's footer always says "...not done by you? Report..." — that
  /// is NOT a skip signal here (only the email *subject* triggers skips).
  ParsedTransaction? _parseSbiCreditCard(String body, String emailId) {
    try {
      debugPrint('=== PARSING EMAIL ===');
      debugPrint('Bank detected: SBI (Credit Card)');
      debugPrint('SBI body: ${body.substring(0, body.length > 400 ? 400 : body.length)}');
      // NB: do NOT skip on body 'otp'/'unsuccessful' — SBI footers say "Never
      // share your OTP". Real OTP/failed mails are dropped by the subject filter.

      // Amount (required). Allow a space after Rs./INR (HTML cells become
      // "Rs. 3,906.00"); _matchDouble strips commas (3,906.00 → 3906.00).
      var amount = _matchDouble(
          RegExp(r'(?:INR|Rs\.?)\s*([\d,]+(?:\.\d{1,2})?)\s+spent',
              caseSensitive: false),
          body);
      amount ??= _matchDouble(
          RegExp(r'(?:INR|Rs\.?)\s*([\d,]+(?:\.\d{1,2})?)',
              caseSensitive: false),
          body);

      // Foreign-currency spend, e.g. "USD19.99 spent on your SBI Credit Card".
      // There's no INR figure in the email, so we store the foreign value and
      // keep the currency in the memo.
      String? currency;
      if (amount == null) {
        final fx = RegExp(
                    r'\b(USD|EUR|GBP|AED|SGD|AUD|CAD|JPY|CHF|THB|MYR|HKD|CNY)\s*'
                    r'([\d,]+(?:\.\d{1,2})?)',
                    caseSensitive: false)
                .firstMatch(body);
        if (fx != null) {
          currency = fx.group(1)!.toUpperCase();
          amount = double.tryParse(fx.group(2)!.replaceAll(',', ''));
        }
      }
      debugPrint('Amount found: $amount ${currency ?? 'INR'}');
      if (amount == null) {
        debugPrint('=== PARSE FAILED === Could not parse amount');
        return null;
      }

      // Card → "XX1157".
      final cardDigits = _matchGroup(
          RegExp(r'Credit Card ending\s+(\d{4})', caseSensitive: false), body);
      final card = cardDigits != null ? 'XX$cardDigits' : null;

      final lower = body.toLowerCase();

      // Merchant. Two shapes:
      //  1) E-mandate: "Transaction of USD23.60 at OPENAI *CHATGPT SUBSCR
      //     against E-mandate …" — anchor on the amount so the earlier
      //     "E-mandate at merchant platform" text isn't captured.
      //  2) Normal spend: "at TWALLETTELANGANA on 10/06/26".
      // Names are mixed-case and may carry '*' (network merchant tags).
      final merchant = _cleanMerchant(_matchGroup(
              RegExp(
                  r'Transaction of\s+\S+\s+at\s+'
                  r'([A-Za-z0-9][A-Za-z0-9 *_-]*?)\s+against\b',
                  caseSensitive: false),
              body)) ??
          _cleanMerchant(_matchGroup(
              RegExp(
                  r'\bat\s+([A-Za-z0-9][A-Za-z0-9 .*_-]*?)'
                  r'\s+on\s+\d{2}[/-]\d{2}[/-]\d{2}',
                  caseSensitive: false),
              body));

      // Date DD/MM/YY or DD-MM-YY.
      final dateStr = _matchGroup(
          RegExp(r'on\s+(\d{2}[/-]\d{2}[/-]\d{2})\.?'), body);

      // Recurring E-mandate / autopay subscription debit → shows in the
      // Recurring Payments section.
      final isRecurring =
          lower.contains('mandate') || lower.contains('recurring');

      debugPrint('Type found: expense');
      debugPrint('Payee found: $merchant');
      debugPrint(
          '=== PARSE SUCCESS === Amount: $amount Payee: $merchant Type: expense');

      return ParsedTransaction(
        amount: amount,
        type: 'expense',
        merchant: (merchant != null && merchant.isNotEmpty) ? merchant : null,
        date: _parseDate(dateStr) ?? DateTime.now(),
        accountNumber: card,
        availableBalance: null,
        bankName: 'SBI',
        emailId: emailId,
        memo: currency != null ? '$currency ${amount.toStringAsFixed(2)}' : null,
        accountType: 'credit_card',
        category: isRecurring ? 'Recurring Payment' : 'Credit Card Purchase',
        instrumentType: 'card',
        currency: currency ?? 'INR',
        isRecurring: isRecurring,
      );
    } catch (e) {
      debugPrint('=== PARSE FAILED === SBI CC exception: $e');
      return null;
    }
  }

  /// Parses many emails, silently skipping any that fail.
  List<ParsedTransaction> parseAll(List<Map<String, dynamic>> emails) {
    final results = <ParsedTransaction>[];
    for (final email in emails) {
      try {
        final body = (email['body'] ?? '').toString();
        final id = (email['id'] ?? '').toString();
        if (body.isEmpty || id.isEmpty) continue;
        // Gmail internalDate (epoch ms) → used when the body has no own date.
        DateTime? emailDate;
        final internal = (email['internalDate'] ?? '').toString();
        final ms = int.tryParse(internal);
        if (ms != null) emailDate = DateTime.fromMillisecondsSinceEpoch(ms);
        final sender = (email['from'] ?? '').toString();
        final parsed = parseEmail(body, id,
            emailDate: emailDate, senderEmail: sender);
        if (parsed != null) {
          debugPrint(parsed.toString()); // full model dump for inspection
          results.add(parsed);
        }
      } catch (_) {
        // Skip unparseable emails.
      }
    }
    return results;
  }

  // ── Helpers ─────────────────────────────────────────────

  /// Strips HTML tags, decodes common entities, and collapses all whitespace
  /// to single spaces so regexes work on both plain-text and HTML emails.
  String _preprocess(String body) {
    var t = body;
    if (t.contains('<') && t.contains('>')) {
      // Remove style/script/comment blocks entirely — their contents (CSS/JS)
      // are NOT email text and would otherwise leak in and cause false matches.
      t = t
          .replaceAll(
              RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), ' ')
          .replaceAll(
              RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
              ' ')
          .replaceAll(RegExp(r'<!--[\s\S]*?-->'), ' ')
          .replaceAll(RegExp(r'<[^>]+>'), ' ');
    }
    t = t
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#39;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&ldquo;', '"')
        .replaceAll('&rdquo;', '"');
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  _BankParser? _detectBank(String body) {
    final lower = body.toLowerCase();
    for (final bank in _banks) {
      for (final kw in bank.keywords) {
        if (lower.contains(kw)) return bank;
      }
    }
    return null;
  }

  String? _matchGroup(RegExp re, String body) {
    try {
      final m = re.firstMatch(body);
      return m != null && m.groupCount >= 1 ? m.group(1) : null;
    } catch (_) {
      return null;
    }
  }

  double? _matchDouble(RegExp re, String body) {
    final raw = _matchGroup(re, body);
    if (raw == null) return null;
    try {
      return double.tryParse(raw.replaceAll(',', '').trim());
    } catch (_) {
      return null;
    }
  }

  String? _cleanMerchant(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  /// Cleans an "Info:" value. For UPI strings like "UPI-987838759482-GARBHANA"
  /// it returns the trailing payee name ("GARBHANA").
  String? _cleanInfo(String? raw) {
    if (raw == null) return null;
    var s = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return null;
    final parts = s.split('-');
    if (parts.length >= 2 && parts.first.toUpperCase().contains('UPI')) {
      final tail = parts.last.trim();
      if (tail.isNotEmpty) s = tail;
    }
    return s.isEmpty ? null : s;
  }

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  /// Parses dd-MMM-yyyy, dd/MM/yyyy, or dd-MM-yyyy. Returns null on failure.
  DateTime? _parseDate(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    try {
      // dd-MMM-yyyy  (e.g. 12-Jun-2026)
      if (RegExp(r'^\d{1,2}-[A-Za-z]{3}-\d{4}$').hasMatch(s)) {
        final p = s.split('-');
        final m = _months[p[1].toLowerCase()];
        if (m == null) return null;
        return DateTime(int.parse(p[2]), m, int.parse(p[0]));
      }
      // dd-MMM-yy  (e.g. 30-Jun-26 → 2026)
      if (RegExp(r'^\d{1,2}-[A-Za-z]{3}-\d{2}$').hasMatch(s)) {
        final p = s.split('-');
        final m = _months[p[1].toLowerCase()];
        if (m == null) return null;
        return DateTime(2000 + int.parse(p[2]), m, int.parse(p[0]));
      }
      // dd/MM/yyyy
      if (RegExp(r'^\d{1,2}/\d{1,2}/\d{4}$').hasMatch(s)) {
        final p = s.split('/');
        return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
      }
      // dd/MM/yy  (e.g. 10/06/26 → 2026)
      if (RegExp(r'^\d{1,2}/\d{1,2}/\d{2}$').hasMatch(s)) {
        final p = s.split('/');
        return DateTime(2000 + int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
      }
      // dd-MM-yyyy
      if (RegExp(r'^\d{1,2}-\d{1,2}-\d{4}$').hasMatch(s)) {
        final p = s.split('-');
        return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
      }
      // dd-MM-yy  (e.g. 10-06-26 → 2026)
      if (RegExp(r'^\d{1,2}-\d{1,2}-\d{2}$').hasMatch(s)) {
        final p = s.split('-');
        return DateTime(2000 + int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
      }
      // MMM dd, yyyy  (e.g. Jun 09, 2026 / June 09, 2026)
      final mdy = RegExp(r'^([A-Za-z]{3,9})\s+(\d{1,2}),?\s+(\d{4})$')
          .firstMatch(s);
      if (mdy != null) {
        final m = _months[mdy.group(1)!.substring(0, 3).toLowerCase()];
        if (m == null) return null;
        return DateTime(
            int.parse(mdy.group(3)!), m, int.parse(mdy.group(2)!));
      }
      // dd MMM yyyy  (e.g. 09 Jun 2026 / 26 May, 2026 / 26 June 2026)
      final dmy = RegExp(r'^(\d{1,2})\s+([A-Za-z]{3,9}),?\s+(\d{4})$')
          .firstMatch(s);
      if (dmy != null) {
        final m = _months[dmy.group(2)!.substring(0, 3).toLowerCase()];
        if (m == null) return null;
        return DateTime(
            int.parse(dmy.group(3)!), m, int.parse(dmy.group(1)!));
      }
    } catch (_) {
      // fall through
    }
    return null;
  }
}

final emailParserServiceProvider =
    Provider<EmailParserService>((ref) => EmailParserService());
