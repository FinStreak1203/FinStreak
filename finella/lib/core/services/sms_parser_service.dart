import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'email_parser_service.dart' show ParsedTransaction;

/// Sender-ID regex → bank name. Senders are `XX-BANKCODE` (the 2-char operator
/// prefix varies: VM, AX, JD, …). Matching also tolerates a trailing DLT suffix
/// ("-S"/"-T"/…) and a missing operator prefix — see [_matches].
const Map<String, String> _senderRegexMap = {
  r'^[A-Z]{2}-(SBIINB|SBINBK|SBIPSG|SBIUPI|SBIBNK|SBIBK|CBSSBI|ATMSBI|SBYONO)$':
      'State Bank of India',
  r'^[A-Z]{2}-(BOBSMS|BOBALT|BOBCRD)$': 'Bank of Baroda',
  r'^[A-Z]{2}-(BOIIND|BOIALT)$': 'Bank of India',
  r'^[A-Z]{2}-(MAHABK|BOMALT)$': 'Bank of Maharashtra',
  r'^[A-Z]{2}-(CANBNK|CANARA)$': 'Canara Bank',
  r'^[A-Z]{2}-(CBINBK|CBISMS)$': 'Central Bank of India',
  r'^[A-Z]{2}-(INDBNK|INDIAN)$': 'Indian Bank',
  r'^[A-Z]{2}-(IOB[A-Z]{2,4}|INDOV[A-Z]?|INDOVB)$': 'Indian Overseas Bank',
  r'^[A-Z]{2}-(PNBALT|PNBSMS)$': 'Punjab National Bank',
  r'^[A-Z]{2}-(PSBALT|PSBSMS)$': 'Punjab & Sind Bank',
  r'^[A-Z]{2}-(UCOBNK|UCOALT)$': 'UCO Bank',
  r'^[A-Z]{2}-(UNIONB|UBIIND)$': 'Union Bank of India',
  r'^[A-Z]{2}-(AXISBK|AXISBN)$': 'Axis Bank',
  r'^[A-Z]{2}-(BANDHN|BDBANK)$': 'Bandhan Bank',
  r'^[A-Z]{2}-(CSBBNK|CSBALT)$': 'CSB Bank',
  r'^[A-Z]{2}-(CUBBNK|CUBALT)$': 'City Union Bank',
  r'^[A-Z]{2}-(DCBBNK|DCBALT)$': 'DCB Bank',
  r'^[A-Z]{2}-(DLXBNK|DHANBK)$': 'Dhanlaxmi Bank',
  r'^[A-Z]{2}-(FEDBNK|FEDALT)$': 'Federal Bank',
  r'^[A-Z]{2}-(HDFCBK|HDFCCC)$': 'HDFC Bank',
  r'^[A-Z]{2}-(ICICI[A-Z]{0,2})$': 'ICICI Bank',
  r'^[A-Z]{2}-(IDBIBK|IDBIAL)$': 'IDBI Bank',
  r'^[A-Z]{2}-(IDFCFB|IDFCBK)$': 'IDFC First Bank',
  r'^[A-Z]{2}-(INDUSB|IIBANK)$': 'IndusInd Bank',
  r'^[A-Z]{2}-(JKBANK|JKBALT)$': 'J&K Bank',
  r'^[A-Z]{2}-(KARBK|KTKBK)$': 'Karnataka Bank',
  r'^[A-Z]{2}-(KVBANK|KVBALT)$': 'Karur Vysya Bank',
  r'^[A-Z]{2}-(KOTAKB|KOTAKC)$': 'Kotak Mahindra Bank',
  r'^[A-Z]{2}-(NAINBK|NTBANK)$': 'Nainital Bank',
  r'^[A-Z]{2}-(RBLBNK|RBLCAR)$': 'RBL Bank',
  r'^[A-Z]{2}-(SIBBNK|SIBALT)$': 'South Indian Bank',
  r'^[A-Z]{2}-(TMBANK|TMBALT)$': 'Tamilnad Mercantile Bank',
  r'^[A-Z]{2}-(YESBNK|YESBKC)$': 'YES Bank',
  r'^[A-Z]{2}-(AUBANK|AUSFBK)$': 'AU Small Finance Bank',
  r'^[A-Z]{2}-(CAPSFB|CAPBNK)$': 'Capital Small Finance Bank',
  r'^[A-Z]{2}-(EQTSFB|EQUITB)$': 'Equitas Small Finance Bank',
  r'^[A-Z]{2}-(ESAFBK|ESAFSF)$': 'ESAF Small Finance Bank',
  r'^[A-Z]{2}-(JANASB|JANABK)$': 'Jana Small Finance Bank',
  r'^[A-Z]{2}-(NESFBK|NORTHE)$': 'North East Small Finance Bank',
  r'^[A-Z]{2}-(SHIVBK|SHVSFB)$': 'Shivalik Small Finance Bank',
  r'^[A-Z]{2}-(SURYBK|SURYSF)$': 'Suryoday Small Finance Bank',
  r'^[A-Z]{2}-(UJJIVN|UJJSFB)$': 'Ujjivan Small Finance Bank',
  r'^[A-Z]{2}-(UNITYB|UNTSFB)$': 'Unity Small Finance Bank',
  r'^[A-Z]{2}-(UTKARS|UTKSFB)$': 'Utkarsh Small Finance Bank',
  r'^[A-Z]{2}-(AIRBNK|AIRTEL)$': 'Airtel Payments Bank',
  r'^[A-Z]{2}-(IPPBNK|INDPST)$': 'India Post Payments Bank',
  r'^[A-Z]{2}-(FINOBK|FINOPB)$': 'Fino Payments Bank',
  r'^[A-Z]{2}-(JIOBNK|JIOPAY)$': 'Jio Payments Bank',
  r'^[A-Z]{2}-(NSDLBK|NSDLPB)$': 'NSDL Payments Bank',
  r'^[A-Z]{2}-(PAYTMB|PAYTMM)$': 'Paytm Payments Bank',
  r'^[A-Z]{2}-(SCBANK|STANCH)$': 'Standard Chartered Bank',
  r'^[A-Z]{2}-(HSBCIN|HSBCBK)$': 'HSBC India',
  r'^[A-Z]{2}-(DBSBNK|DBSIND)$': 'DBS Bank India',
  r'^[A-Z]{2}-(DEUTBK|DBKIND)$': 'Deutsche Bank India',
  r'^[A-Z]{2}-(CITIBK|CITICD)$': 'Citibank India',
  r'^[A-Z]{2}-(AMEXIN|AMEXCD)$': 'American Express India',
  r'^[A-Z]{2}-(SBICRD|SBICAR)$': 'SBI Card',
  r'^[A-Z]{2}-(BOAIND|BAMLTD)$': 'Bank of America India',
  r'^[A-Z]{2}-(BARCBK|BARCLY)$': 'Barclays Bank India',
  r'^[A-Z]{2}-(JPMBNK|JPMCHS)$': 'JPMorgan Chase Bank India',
};

/// Pre-compiled (regex, bankName) pairs — built once.
final List<MapEntry<RegExp, String>> _compiledSenders = _senderRegexMap.entries
    .map((e) => MapEntry(RegExp(e.key, caseSensitive: false), e.value))
    .toList();

/// SMS bodies that are alerts but not real transactions — skipped entirely.
const List<String> _skipPhrases = [
  'balance enquiry',
  'balance inquiry',
  'no amount debited',
  'no debit made',
  'no charge posted',
  'collect request',
  'pending for your approval',
  'do not share upi pin',
  'transaction declined',
  'card declined',
  'failed transaction',
  'declined',
  // OTP / verification codes — not a transaction (money hasn't moved yet).
  'one-time password',
  'one time password',
  'otp for',
  'is otp',
  'otp is',
  'otps are secret',
  'do not disclose',
  'do not share',
  // Bill-due reminders / upcoming charges — nothing has been debited yet.
  'due for payment',
  'ignore if already paid',
  'is due on',
  'bill is due',
  'payment is due',
  'last date to pay',
  'pay your bill',
  'kindly pay',
  'will be debited',
  'will be deducted',
  'will be charged',
  // Marketing / loan & offer promos — mention an amount (a limit/offer) but no
  // money moved. A real alert never says "pre-approved" / "apply now" / "tap:".
  'pre-approved',
  'pre approved',
  'preapproved',
  'pre-qualified',
  'apply now',
  'apply for',
  'click here',
  'tap:',
  'tap here',
  'lowest interest',
  'instant loan',
  'loan offer',
  'eligible for a',
  'avail now',
  't&c apply',
  'recharge now',
  'data is consumed',
];

/// Universal, dataset-driven SMS parser. Classifies the body by keyword into a
/// category + instrument + direction, then extracts amount/merchant/ref/VPA/
/// account/date. Produces the shared [ParsedTransaction] model.
class SmsParserService {
  const SmsParserService();

  /// Matches [regex] against the sender, tolerating a missing 2-char operator
  /// prefix (bare "HDFCBK") and a trailing DLT suffix ("VM-HDFCBK-S").
  bool _matches(RegExp regex, String sender) {
    var s = sender.toUpperCase().trim();
    s = s.replaceFirst(RegExp(r'-[A-Z]$'), ''); // drop "-S"/"-T"/… suffix
    return regex.hasMatch(s) || regex.hasMatch('XX-$s');
  }

  /// Full bank names → used when the sender is a branded RCS / verified
  /// business name ("Indian Overseas Bank") instead of a DLT short code.
  static const Map<String, String> _senderNameMap = {
    'indian overseas': 'Indian Overseas Bank',
    'state bank of india': 'State Bank of India',
    'icici bank': 'ICICI Bank',
    'hdfc bank': 'HDFC Bank',
    'axis bank': 'Axis Bank',
    'kotak': 'Kotak Mahindra Bank',
    'idfc first': 'IDFC First Bank',
    'indusind': 'IndusInd Bank',
    'yes bank': 'YES Bank',
    'canara bank': 'Canara Bank',
    'bank of baroda': 'Bank of Baroda',
    'union bank': 'Union Bank of India',
    'punjab national': 'Punjab National Bank',
    'bank of india': 'Bank of India',
    'hsbc': 'HSBC India',
  };

  String? _bankFromName(String sender) {
    final s = sender.toLowerCase();
    for (final e in _senderNameMap.entries) {
      if (s.contains(e.key)) return e.value;
    }
    return null;
  }

  bool isBankSMS(String sender) =>
      _compiledSenders.any((e) => _matches(e.key, sender)) ||
      _bankFromName(sender) != null;

  String getBankName(String sender) {
    for (final e in _compiledSenders) {
      if (_matches(e.key, sender)) return e.value;
    }
    return _bankFromName(sender) ?? 'Unknown Bank';
  }

  /// True if the body contains a click-through link — `http(s)://…` or a bare
  /// `domain.tld/path` (e.g. "i.airtel.in/dtpck"). Marketing SMS always include
  /// one; transaction alerts use a phone number instead.
  static final RegExp _link =
      RegExp(r'https?://|[a-z0-9][a-z0-9.\-]*\.[a-z]{2,}/\S', caseSensitive: false);
  bool _hasLink(String lowerBody) => _link.hasMatch(lowerBody);

  /// True when the body clearly describes a real transaction: a debit/credit
  /// verb together with a masked card/account number or an available
  /// balance/limit. Used to keep genuine alerts that also carry a link.
  static final RegExp _txnVerb = RegExp(
      r'\b(spent|debited|credited|withdrawn|deposited|purchase|paid|'
      r'sent|received|transferred|transfer)\b',
      caseSensitive: false);
  static final RegExp _maskedAcct = RegExp(
      r'(?:card|a/?c|account)\s*(?:no\.?)?\s*[x*]*\d{2,}',
      caseSensitive: false);
  bool _hasTxnEvidence(String lowerBody) =>
      _txnVerb.hasMatch(lowerBody) &&
      (_maskedAcct.hasMatch(lowerBody) ||
          lowerBody.contains('avl bal') ||
          lowerBody.contains('avl lmt') ||
          lowerBody.contains('avbl') ||
          lowerBody.contains('available limit') ||
          lowerBody.contains('available balance'));

  ParsedTransaction? parseSMS({
    required String body,
    required String sender,
    required String smsId,
    required DateTime date,
  }) {
    try {
      final b = body.toLowerCase();

      // STEP 9 — skip non-financial alerts (promos, reminders). A click-through
      // link usually means marketing/phishing, so drop links too — UNLESS the
      // message carries clear transaction evidence (a spend/debit/credit verb
      // plus a card/account number or available balance/limit). Some real card
      // alerts append an EMI-conversion "Know more" link, e.g. ICICI:
      //   "Rs 10,295 spent on ICICI Bank Card XX0001 ... Avl Lmt: Rs ...
      //    Know more about EMI conversion at https://icici.co/..."
      if (_skipPhrases.any(b.contains)) return null;
      if (_hasLink(b) && !_hasTxnEvidence(b)) return null;

      // STEP 3 — amount (required). Currency-prefixed first, then the SBI UPI
      // form "debited/credited by 6000.00" (no Rs/INR symbol).
      var amountStr = RegExp(
        r'(?:INR|Rs\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)',
        caseSensitive: false,
      ).firstMatch(body)?.group(1);
      amountStr ??= RegExp(
        r'(?:debited|credited|deposited)\s+by\s+([\d,]+(?:\.\d{1,2})?)',
        caseSensitive: false,
      ).firstMatch(body)?.group(1);
      if (amountStr == null) return null;
      final amount = double.tryParse(amountStr.replaceAll(',', ''));
      if (amount == null) return null;

      // STEP 2 — classify (null = skip).
      final cls = _classify(b);
      if (cls == null) return null;
      // A mandate/standing-instruction SETUP (created/registered/modified) is
      // not a transaction — nothing is debited until it later executes.
      if (cls.instrument == 'upi_mandate') return null;
      final type = cls.direction == 'debit' ? 'expense' : 'income';

      // STEP 5–8 — extract the rest.
      var merchant = _extractMerchant(body);
      final vpa = RegExp(r'([a-z0-9._\-]+@[a-z]{2,})', caseSensitive: false)
          .firstMatch(body)
          ?.group(1);
      // No named payee (e.g. a phone-number UPI id like "9966358368@axl", whose
      // numeric handle the extractor rejects) → show the VPA itself instead of
      // a blank merchant. Named VPAs already resolve to their handle above.
      merchant ??= vpa;
      var ref = RegExp(
        r'(?:UPI\s*Ref|IMPS\s*Ref|Mandate\s*Ref|UTR|Cheque\s*no\.?|'
        r'Ref\s*no\.?|Ref)\s*[:\s]*([0-9]{4,})',
        caseSensitive: false,
      ).firstMatch(body)?.group(1);
      // IOB credit form "[UPI/897933 ]" (tolerates a trailing space).
      ref ??= RegExp(r'\[UPI/(\d+)\s*\]', caseSensitive: false)
          .firstMatch(body)
          ?.group(1);
      // Axis form "UPI/P2M/617828965626/<merchant>".
      ref ??= RegExp(r'UPI/(?:P2M|P2A|P2P)/(\d+)', caseSensitive: false)
          .firstMatch(body)
          ?.group(1);
      // ICICI internal transfer "INF*INFT*000088724565*Self".
      ref ??= RegExp(r'INFT\*(\d+)', caseSensitive: false)
          .firstMatch(body)
          ?.group(1);
      final account = _extractAccount(body);
      final parsedDate = _extractDate(body) ?? date;

      // Credit-card spend? "credit card" OR an available *limit* (bank accounts
      // report "avl bal", credit cards "avl lmt"). Flag it so it links to the
      // credit-card account and reads as such — same as the email parser.
      final isCreditCard = b.contains('credit card') ||
          b.contains('avl lmt') ||
          b.contains('available limit');

      return ParsedTransaction(
        amount: amount,
        type: type,
        merchant: merchant,
        date: parsedDate,
        accountNumber: account,
        availableBalance: null,
        bankName: getBankName(sender),
        emailId: smsId, // reused as the dedup key (sourceEmailId)
        accountType: isCreditCard ? 'credit_card' : null,
        upiRef: ref,
        upiVpa: vpa,
        category: isCreditCard && type == 'expense'
            ? 'Credit Card Purchase'
            : cls.category,
        instrumentType: cls.instrument,
        isRecurring: cls.recurring,
      );
    } catch (e) {
      debugPrint('SMS parse error: $e');
      return null;
    }
  }

  // ── Classifier ─────────────────────────────────────────────
  // Ordered specific → generic; first match wins. Parentheses added throughout
  // to fix the precedence the source pseudo-code implied.
  ({String category, String instrument, String direction, bool recurring})?
      _classify(String b) {
    bool has(String s) => b.contains(s);
    final recurring = has('emi') ||
        has('autopay') ||
        has('mandate') ||
        has('nach') ||
        has('ecs') ||
        has('standing instruction');

    ({String category, String instrument, String direction, bool recurring}) t(
            String c, String i, String d, [bool? r]) =>
        (category: c, instrument: i, direction: d, recurring: r ?? false);

    // UPI / e-mandate SETUP (created / cancelled / modified) — a standing
    // instruction, NOT a debit. Excludes actual mandate *executions* (which
    // say "debited"/"deducted") so those still book as real expenses.
    if (has('mandate') &&
        !has('debited') &&
        !has('deducted') &&
        (has('created') ||
            has('cancelled') ||
            has('registered') ||
            has('modified') ||
            has('paused') ||
            has('e-mandate'))) {
      return t('UPI Mandate Setup', 'upi_mandate', 'debit', true);
    }
    // FASTag / toll
    if (has('fastag') || has('toll plaza')) {
      return t('FASTag Debit', 'fastag', 'debit');
    }
    // ATM family
    if (has('atm') && has('reversal')) {
      return t('ATM Reversal', 'atm', 'income');
    }
    if (has('atm') && (has('cash deposit') || has('cdm'))) {
      return t('ATM Cash Deposit', 'atm', 'income');
    }
    if (has('atm') &&
        (has('withdrawn') || has('withdrawal') || has('cash withdrawal'))) {
      return t('ATM Withdrawal', 'atm', 'debit');
    }
    // BBPS
    if (has('bbps') || has('bill payment')) {
      return t('BBPS Bill Payment', 'bbps', 'debit', recurring);
    }
    // UPI AutoPay (before generic UPI)
    if ((has('upi') && has('autopay')) ||
        has('upi autopay') ||
        (has('autopay') && has('mandate'))) {
      return t('UPI AutoPay Mandate Debit', 'upi_autopay', 'debit', true);
    }
    // NACH / ECS
    if (has('nach') || has('ecs')) {
      // NACH can be a credit too (dividends, refunds, salary via NACH).
      final credit = has('credit') && !has('debit');
      return credit
          ? t('NACH/ECS Credit', 'nach_ecs', 'income', true)
          : t('NACH/ECS Debit', 'nach_ecs', 'debit', true);
    }
    // Loan
    if (has('loan emi') || (has('emi') && has('debited'))) {
      return t('Loan EMI Debit', 'loan', 'debit', true);
    }
    if (has('disbursed') || (has('loan amount') && has('credited'))) {
      return t('Loan Disbursement', 'loan', 'income');
    }
    if (has('loan account') && has('credited')) {
      return t('Loan Payment Credit', 'loan', 'income');
    }
    if (has('overdue') || has('penal')) {
      return t('Loan Overdue/Charges', 'loan', 'debit');
    }
    // UPI
    if (has('upi') && (has('refund') || has('reversal'))) {
      return t('UPI Refund/Reversal', 'upi', 'income');
    }
    if (has('upi') && (has('credited') || has('received'))) {
      return t('UPI Credit', 'upi', 'income');
    }
    if (has('upi') && (has('debited') || has('paid') || has('sent'))) {
      return t('UPI Debit', 'upi', 'debit');
    }
    // IMPS
    if (has('imps') && has('credited')) {
      return t('IMPS Credit', 'imps', 'income');
    }
    if (has('imps') && has('debited')) {
      return t('IMPS Debit', 'imps', 'debit');
    }
    // NEFT / RTGS
    if ((has('neft') || has('rtgs')) && (has('credited') || has('utr'))) {
      return t('NEFT/RTGS Credit', 'neft_rtgs', 'income');
    }
    if ((has('neft') || has('rtgs')) && has('debited')) {
      return t('NEFT Debit', 'neft', 'debit');
    }
    // Credit card
    if (has('credit card') && has('refund')) {
      return t('Credit Card Refund', 'credit_card', 'income');
    }
    if (has('credit card') && has('credited') && has('outstanding')) {
      return t('Credit Card Bill Payment', 'credit_card', 'income');
    }
    if (has('credit card') && (has('spent') || has('payment made'))) {
      return t('Credit Card Purchase', 'credit_card', 'debit');
    }
    // Debit card
    if (has('tap & pay') || has('contactless')) {
      return t('Debit Card Contactless', 'debit_card', 'debit');
    }
    if (has('debit card') && has('online')) {
      return t('Debit Card Online', 'debit_card', 'debit');
    }
    if (has('debit card') && (has('spent') || has('alert'))) {
      return t('Debit Card POS', 'debit_card', 'debit');
    }
    // Wallet / PPI
    if (has('wallet') || has('ppi')) {
      return t('Wallet/PPI Debit', 'wallet', 'debit');
    }
    // Cashback / reward
    if (has('cashback') || has('reward')) {
      return t('Cashback/Reward Credit', 'other', 'income');
    }
    // Cheque
    if (has('cheque')) {
      return t('Cheque', 'cheque', has('debit') ? 'debit' : 'income');
    }
    // Interest
    if (has('interest') && has('credited')) {
      return t('Interest Credit', 'interest', 'income');
    }
    // Bank charges
    if (has('charges') || (has('gst') && has('debited'))) {
      return t('Bank Charges', 'charge', 'debit');
    }
    // Branch cash
    if (has('cash deposit') && has('branch')) {
      return t('Cash Deposit Branch', 'cash', 'income');
    }
    if (has('cash withdrawal') && has('branch')) {
      return t('Cash Withdrawal Branch', 'cash', 'debit');
    }
    // General reversal / refund
    if (has('reversal') || (has('refund') && !has('upi'))) {
      return t('Reversal/Refund Credit', 'other', 'income');
    }
    // Salary / account credit
    if (has('credited') &&
        (has('salary') || has('info:') || has('amount received'))) {
      return t('Account Credit', 'other', 'income');
    }
    // Account debit
    if (has('debited') && (has('info:') || has('payment to'))) {
      return t('Account Debit', 'other', 'debit');
    }
    // Generic credit / debit
    if (has('credited') || has('received') || has('deposited')) {
      return t('Account Credit', 'other', 'income', recurring);
    }
    if (has('debited') ||
        has('spent') ||
        has('withdrawn') ||
        has('paid') ||
        has('sent')) {
      return t('Account Debit', 'other', 'debit', recurring);
    }
    // Amount present but no direction keyword → assume an expense alert.
    return t('Transaction', 'other', 'debit', recurring);
  }

  // ── Extractors ─────────────────────────────────────────────
  String? _extractMerchant(String body) {
    const patterns = [
      // Axis-style UPI merchant: "UPI/P2M/<ref>/Life Insurance Copo" or
      // "UPI/P2A/<ref>/SANAPURED/ANDB/Sent" — the payee/payer is the segment
      // after the reference number, delimited by the next "/" (or end).
      r'UPI/(?:P2M|P2A|P2P)/[A-Za-z0-9]+/([A-Za-z][A-Za-z0-9 .&_\-]+?)(?:\s+Not you|[/\n]|$)',
      // Internal fund transfer: "Info INF*INFT*000088724565*Self." → the note
      // after the reference (e.g. "Self"), stopping at the sentence end.
      r'INFT\*\d+\*([A-Za-z][A-Za-z0-9 ]*?)(?:\.|$)',
      // NACH / ECS payer or biller: "credit by NACH- HINDUSTAN COPPER LTD of
      // Rs 2.00" / "NACH/RAZORPAY of …" → the name between NACH/ECS and "of/on".
      r'(?:NACH|ECS)[-/ ]+([A-Za-z][A-Za-z0-9 .&_\-]+?)\s+(?:of|on)\b',
      // ACH mandate debit: "InfoACH*AVANSE FI.Avl Bal ..." → the biller name
      // after "ACH*", stopping at the sentence end or the balance line.
      r'ACH\*([A-Za-z][A-Za-z0-9 .&_\-]+?)\s*(?:\.|\s+Av(?:l|bl|ailable)\b|$)',
      // IOB credit: the payer name precedes "-<phone>" or "-<vpa>@/¡bank", e.g.
      //   "from K PRASHANTH CHARY-prasnt26-2@okicici(-(UPI Ref…"
      //   "from Palapolu Kameshwara Rao-6304838283-2¡ybl(UPI Ref…"
      // (¡ is a mangled @ from RCS). Anchoring on the phone/VPA avoids matching
      // the later "Payment from PhonePe" in the Payer Remark.
      r'from\s+([A-Za-z][A-Za-z .]+?)-(?:\d{6,}|[A-Za-z0-9._\-]+[@¡])',
      r'Info:\s*payment to\s+([A-Za-z0-9 .&_\-]+?)(?:\s+on|\s+ref|\s+from|\.|$)',
      r'towards\s+([A-Za-z0-9 .&_\-]+?)(?:\s+on|\s+ref|\s+from|\.|$)',
      r'at\s+([A-Za-z0-9 .&_\-]+?)\s+on\s+\d',
      // Card POS "spent ... at MERCHANT." where the date precedes "at" (e.g.
      // ICICI "spent on Card XX on 15-Jun-26 at PAYZAPP WALLET. Avl Lmt: ...").
      // Stops at the sentence end or the available-balance/limit line.
      r'\bat\s+([A-Za-z][A-Za-z0-9 .&_\-]+?)\s*(?:\.|\s+Av(?:l|bl|ailable)\b|$)',
      // Axis "Spent" card SMS: "...HH:MM:SS\nGUNDU ANUR\nAvl Lmt INR ..." —
      // the merchant sits between the timestamp and the available-limit line.
      // (Must beat the generic "to/from" below, which would otherwise grab the
      // "SMS BLOCK 0689 to <number>" phone number.)
      r'\d{2}:\d{2}:\d{2}\s+([A-Za-z][A-Za-z0-9 .&@_\-]+?)\s+Av(?:l|bl|ailable)\b',
      // UPI VPA payee/payer: "to EKART@ybl" / "from rahul@upi" → handle only.
      r'(?:to|from)\s+([A-Za-z0-9._\-]+)@[A-Za-z]',
      // IOB UPI credit: "[UPI/897933 ] BHIMARAM on 26-05-2026" → payer name.
      r'\]\s*([A-Za-z][A-Za-z .]+?)\s+on\b',
      // IOB "payee NAME for" — must beat the generic to/from below, since
      // boilerplate like "report to your bank" also contains "to".
      r'payee\s+([A-Za-z .]+?)\s+for\b',
      r'(?:to|from)\s+([A-Za-z0-9 .&_\-]+?)(?:\s+on|\s+via|\s+ref|\s+from|\.|$)',
      r'\(([A-Za-z0-9 .&_\-]+)\)',
    ];
    for (final p in patterns) {
      final g =
          RegExp(p, caseSensitive: false).firstMatch(body)?.group(1)?.trim();
      // Collapse internal whitespace ("GUNDU  ANUR" → "GUNDU ANUR") and reject
      // a purely-numeric match (a phone/ref number is not a merchant).
      if (g != null && g.isNotEmpty && !RegExp(r'^\d+$').hasMatch(g)) {
        return g.replaceAll(RegExp(r'\s+'), ' ');
      }
    }
    return null;
  }

  String? _extractAccount(String body) {
    final digits = RegExp(
                r'(?:A/c|A/C|Acc|account|AC)\s*(?:no\.?:?\s*)?[Xx*]*(\d{3,4})',
                caseSensitive: false)
            .firstMatch(body)
            ?.group(1) ??
        RegExp(r'(?:ending|card)\s*(?:no\.?)?\s*[Xx*]*(\d{4})',
                caseSensitive: false)
            .firstMatch(body)
            ?.group(1) ??
        // IOB-style "a/c XXXXX94" (fewer trailing digits).
        RegExp(r'a/c\s+[Xx*]+(\d{2,})', caseSensitive: false)
            .firstMatch(body)
            ?.group(1) ??
        // IOB credit form "SB-xxx8594" (SB/CA/OD account prefixes).
        RegExp(r'(?:SB|CA|OD)-?[Xx]+(\d{4})', caseSensitive: false)
            .firstMatch(body)
            ?.group(1);
    return digits != null ? 'XX$digits' : null;
  }

  static const Map<String, int> _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  /// Handles 03-Jun-2026, 2026-06-13, 13-06-2026, 13/06/26.
  DateTime? _extractDate(String body) {
    // dd-MMM-yyyy (03-Jun-2026) or no-separator dd MMM yy/yyyy (08Jun26).
    var m = RegExp(r'(\d{2})-?([A-Za-z]{3})-?(\d{4}|\d{2})').firstMatch(body);
    if (m != null) {
      final mon = _months[m.group(2)!.toLowerCase()];
      if (mon != null) {
        final yy = int.parse(m.group(3)!);
        final year = yy < 100 ? 2000 + yy : yy;
        return DateTime(year, mon, int.parse(m.group(1)!));
      }
    }
    m = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(body);
    if (m != null) {
      return DateTime(
          int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
    }
    m = RegExp(r'(\d{2})-(\d{2})-(\d{4})').firstMatch(body);
    if (m != null) {
      return DateTime(
          int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
    }
    m = RegExp(r'(\d{2})/(\d{2})/(\d{2})').firstMatch(body);
    if (m != null) {
      return DateTime(2000 + int.parse(m.group(3)!), int.parse(m.group(2)!),
          int.parse(m.group(1)!));
    }
    return null;
  }
}

final smsParserServiceProvider =
    Provider<SmsParserService>((ref) => const SmsParserService());
