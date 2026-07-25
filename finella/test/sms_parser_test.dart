import 'package:flutter_test/flutter_test.dart';
import 'package:finella/core/services/sms_parser_service.dart';

void main() {
  const parser = SmsParserService();
  final now = DateTime(2026, 6, 27);

  test('Pre-approved loan promo SMS is skipped (not a transaction)', () {
    const body =
        'Hi Customer, school spends adding up? Your instant Rs.3,00,000 is '
        'pre-approved with Kotak Personal Loan.Tap: '
        'https://1.kotak.bank.in/KOTAKB/YPJkRL T&C';

    final tx = parser.parseSMS(
        body: body, sender: 'VK-KOTAKB', smsId: 's1', date: now);

    expect(tx, isNull); // marketing offer, not a transaction
  });

  test('All Kotak loan/card promos are skipped', () {
    const promos = [
      'Hi Customer, school spends adding up? Your instant Rs.3,00,000 is '
          'pre-approved with Kotak Personal Loan.Tap: '
          'https://1.kotak.bank.in/KOTAKB/YPJkRL T&C',
      'Get pre-approved Kotak Air Credit Card with 0 Joining Fees & enjoy '
          'Rs.25,000+ travel perks. Limit: Rs.268500. Tap '
          'https://1.kotak.bank.in/KOTAKB/YOP3Su T&C',
      'Hi Customer, unexpected expense? Rs. 3,00,000 from Kotak Personal Loan '
          'can help you handle it. 100% digital. Tap: '
          'https://1.kotak.bank.in/KOTAKB/YJDmHE T&C',
      'Hi Customer, monsoon leaks are easier fixed early. Get an instant '
          'Rs.3,00,000 from Kotak Personal Loan. Tap: '
          'https://1.kotak.bank.in/KOTAKB/YHYU2a T&C',
      'Hi Customer, sale season is here! Shop with pre-approved Rs. 3,00,000 '
          'from Kotak Personal Loan. 100% online. Tap '
          'https://1.kotak.bank.in/KOTAKB/YGZEYI T&C',
    ];
    for (var i = 0; i < promos.length; i++) {
      final tx = parser.parseSMS(
          body: promos[i], sender: 'VK-KOTAKB', smsId: 'p$i', date: now);
      expect(tx, isNull, reason: 'promo #$i should be skipped');
    }
  });

  test('IDFC loan & IndusInd EMI-offer promos are skipped', () {
    const promos = [
      'Hi! Withdraw Rs.438000 at 0 foreclosure charges with FIRSTmoney Smart '
          'Personal Loan by IDFC FIRST Bank. Hurry! '
          'https://idfcfs.bank.in/IDFCFB/YIrok9 TCA',
      'Dear Customer, you can customize your personal loan of Rs. 438000 with '
          'FIRSTmoney by IDFC FIRST Bank! Hurry & apply now '
          'https://idfcfs.bank.in/IDFCFB/YLfAo2 TCA',
      'Hello, your IDFC FIRST Bank FIRSTmoney Smart Personal Loan offer of Rs. '
          '438000 is waiting! Get Now: https://idfcfs.bank.in/IDFCFB/YF_tSM TCA',
      'Dear Customer, emergency can strike anytime. With FIRSTmoney by IDFC '
          'FIRST Bank, get instant Rs. 301000 and bid worries goodbye. '
          'https://idfcfs.bank.in/IDFCFB/W1IPxt TCA',
      'Important Update: Break your INR 42995.04 Credit Card outstanding into '
          'EMIs and pay over time. Convert at: '
          'https://indusbk.in/INDUSB/woSBKxk - IndusInd Bank',
    ];
    for (var i = 0; i < promos.length; i++) {
      final tx = parser.parseSMS(
          body: promos[i], sender: 'VK-IDFCFB', smsId: 'q$i', date: now);
      expect(tx, isNull, reason: 'promo #$i should be skipped');
    }
  });

  test('Telecom data/recharge promo (bare link) is skipped', () {
    const body =
        'Alert 50%: data is consumed. Get 3GB per day for 3 days at Rs. 39. '
        'Recharge now i.airtel.in/dtpck-pre';

    final tx = parser.parseSMS(
        body: body, sender: 'AX-AIRTEL', smsId: 's9', date: now);

    expect(tx, isNull); // recharge offer with a bare link, not a transaction
  });

  test('UPI mandate setup (created) is skipped; execution still parses', () {
    const setup =
        'Your UPI-Mandate for Rs.699.00 is successfully created towards '
        'JioHotstar from A/c No: XXXXXX1702. UMN:55dfbfaa@ybl. If not you, '
        'kindly report on 18001234. -SBI';
    expect(
        parser.parseSMS(body: setup, sender: 'VK-SBIUPI', smsId: 'm1', date: now),
        isNull); // mandate creation → not a transaction

    // The actual autopay debit (mandate executing) IS a real transaction.
    const exec =
        'Rs.699.00 debited from A/c XXXXXX1702 towards JioHotstar via UPI '
        'AutoPay mandate on 25-Jun-26.';
    final tx = parser.parseSMS(
        body: exec, sender: 'VK-SBIUPI', smsId: 'm2', date: now)!;
    expect(tx.type, 'expense');
    expect(tx.amount, 699.0);
  });

  test('SBI NACH credit → income with biller name', () {
    const body =
        'Dear Customer,Your A/C XXXXX761702 has a credit by NACH- HINDUSTAN '
        'COPPER LTD of Rs 2.00 on 05/03/26. Avl Bal Rs 56.98. Download YONO-SBI';

    final tx = parser.parseSMS(
        body: body, sender: 'VK-SBIINB', smsId: 'n1', date: now)!;

    expect(tx.type, 'income'); // "has a credit by NACH"
    expect(tx.amount, 2.0);
    expect(tx.merchant, 'HINDUSTAN COPPER LTD');
  });

  test('NACH debit still parses as expense (regression)', () {
    const body =
        'Rs 500.00 debited by NACH- BAJAJ FINANCE of A/c XX1234 on 05-03-26.';
    final tx = parser.parseSMS(
        body: body, sender: 'VK-SBIINB', smsId: 'n2', date: now)!;
    expect(tx.type, 'expense');
    expect(tx.merchant, 'BAJAJ FINANCE');
  });

  test('ICICI INFT self-transfer credit → income, account, ref, merchant', () {
    const body =
        'ICICI Bank Account XX800 credited:Rs. 1,00,000.00 on 29-Jun-26. '
        'Info INF*INFT*000088724565*Self. Available Balance is Rs. 1,01,952.79.';

    final tx = parser.parseSMS(
        body: body, sender: 'AD-ICICIB', smsId: 'i1', date: now)!;

    expect(tx.type, 'income'); // credited
    expect(tx.amount, 100000.0);
    expect(tx.bankName, 'ICICI Bank');
    expect(tx.accountNumber, 'XX800'); // 3-digit masked account
    expect(tx.merchant, 'Self'); // INFT note, not the whole sentence
    expect(tx.upiRef, '000088724565');
    expect(tx.date, DateTime(2026, 6, 29));
  });

  test('Axis "Spent" card SMS → merchant name, not the SMS-BLOCK number', () {
    const body = 'Spent\n'
        'Card no. XX0689\n'
        'INR 100\n'
        '01-04-25 14:06:51\n'
        'GUNDU  ANUR\n'
        'Avl Lmt INR 49721.88\n'
        'SMS BLOCK 0689 to 919951860002, if not you - Axis Bank';

    final tx = parser.parseSMS(
        body: body, sender: 'AX-AXISBK', smsId: 's3', date: now)!;

    expect(tx.amount, 100.0);
    expect(tx.merchant, 'GUNDU ANUR'); // not "919951860002"
    expect(tx.type, 'expense');
    expect(tx.accountNumber, 'XX0689');
  });

  test('Axis UPI P2M debit → merchant + ref from the UPI string', () {
    const body = 'INR 22167.00 debited\n'
        'A/c no. XX6626\n'
        '27-06-26, 14:58:29\n'
        'UPI/P2M/617828965626/Life Insurance Copo\n'
        'Not you? SMS BLOCKUPI Cust ID to 919951860002';

    final tx = parser.parseSMS(
        body: body, sender: 'AX-AXISBK', smsId: 's4', date: now)!;

    expect(tx.type, 'expense');
    expect(tx.amount, 22167.0);
    expect(tx.merchant, 'Life Insurance Copo');
    expect(tx.accountNumber, 'XX6626');
    expect(tx.upiRef, '617828965626');
  });

  test('IOB sender IDs are recognised as a bank', () {
    for (final s in const [
      'AD-IOBCHN',
      'VM-IOBBNK',
      'JD-IOBNET', // newer header — previously unmatched
      'AX-IOBINB',
      'IOBCHN', // bare (no operator prefix)
      'BP-INDOVB',
    ]) {
      expect(parser.isBankSMS(s), isTrue, reason: '$s should be IOB');
      expect(parser.getBankName(s), 'Indian Overseas Bank');
    }
  });

  test('IOB UPI debit parses end-to-end', () {
    const body = 'INR 22167.00 debited\n'
        'A/c no. XX6626\n'
        '27-06-26, 14:58:29\n'
        'UPI/P2M/617828965626/Life Insurance Copo\n'
        'Not you? SMS BLOCKUPI Cust ID to 919951860002';

    final tx = parser.parseSMS(
        body: body, sender: 'AD-IOBCHN', smsId: 's5', date: now)!;

    expect(tx.bankName, 'Indian Overseas Bank');
    expect(tx.amount, 22167.0);
    expect(tx.merchant, 'Life Insurance Copo');
  });

  test('IOB branded (RCS) sender name is recognised as a bank', () {
    expect(parser.isBankSMS('Indian Overseas Bank'), isTrue);
    expect(parser.getBankName('Indian Overseas Bank'), 'Indian Overseas Bank');
  });

  test('IOB UPI credit ("from NAME-vpa@bank") → income with payer name', () {
    const body =
        'Your a/c no. XXXXX80 is credited by Rs.12000.00 on 2026-06-20 '
        '11:58:21.360, from K PRASHANTH CHARY-prasnt26-2@okicici(-(UPI Ref no '
        '617168903998)).Payer Remark - UPI -IOB';

    final tx = parser.parseSMS(
        body: body, sender: 'Indian Overseas Bank', smsId: 's6', date: now)!;

    expect(tx.type, 'income');
    expect(tx.amount, 12000.0);
    expect(tx.merchant, 'K PRASHANTH CHARY');
    expect(tx.bankName, 'Indian Overseas Bank');
    expect(tx.upiRef, '617168903998');
  });

  test('IOB credit with phone-suffix payer + PhonePe remark → correct name', () {
    const body =
        'Your a/c no. XXXXX80 is credited by Rs.6000.00 on 2026-06-19 '
        '22:24:23.434, from Palapolu Kameshwara Rao-6304838283-2¡ybl(UPI Ref '
        'no 055154224631).Payer Remark - Payment from PhonePe -IOB';

    final tx = parser.parseSMS(
        body: body, sender: 'Indian Overseas Bank', smsId: 's7', date: now)!;

    expect(tx.type, 'income');
    expect(tx.amount, 6000.0);
    expect(tx.merchant, 'Palapolu Kameshwara Rao'); // not "PhonePe -IOB"
    expect(tx.upiRef, '055154224631');
  });

  test('Upcoming "will be debited" charge notice is skipped', () {
    const body =
        'AMB Non Maintenance Chrg for May-2026 of Rs. 590.00 will be debited '
        'from your Account x2533 this month. Kotak Bank';

    final tx = parser.parseSMS(
        body: body, sender: 'VK-KOTAKB', smsId: 's8', date: now);

    expect(tx, isNull); // future charge, not executed yet
  });

  test('Real debit SMS still parses (regression for the promo skip)', () {
    const body =
        'Rs.500.00 debited from your Kotak Bank A/c XX1234 on 01-Jun-26. '
        'UPI Ref 123456789012.';

    final tx = parser.parseSMS(
        body: body, sender: 'VK-KOTAKB', smsId: 's2', date: now);

    expect(tx, isNotNull);
    expect(tx!.amount, 500.0);
    expect(tx.type, 'expense');
  });
}
