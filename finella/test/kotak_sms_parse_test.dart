import 'package:flutter_test/flutter_test.dart';
import 'package:finella/core/services/sms_parser_service.dart';

void main() {
  const parser = SmsParserService();

  test('Kotak "Sent … Fraud link" UPI debit parses as an expense', () {
    final parsed = parser.parseSMS(
      body:
          'Sent Rs.1200.00 from Kotak Bank AC X3304 to 9542878276@ibl on '
          '10-07-26.UPI Ref 619145032342. Not you, https://kotak.com/KBANKT/Fraud',
      sender: 'VM-KOTAKB',
      smsId: 'test1',
      date: DateTime(2026, 7, 10),
    );

    expect(parsed, isNotNull, reason: 'link-bearing UPI debit must not be dropped');
    expect(parsed!.type, 'expense');
    expect(parsed.amount, 1200.0);
    expect(parsed.upiRef, '619145032342');
    expect(parser.isBankSMS('VM-KOTAKB'), isTrue);
  });

  test('phone-number payee VPA is shown as the merchant, not null', () {
    final parsed = parser.parseSMS(
      body:
          'Sent Rs.30.00 from Kotak Bank AC X3304 to 9966358368@axl on '
          '10-07-26.UPI Ref 655739332520. Not you, https://kotak.com/KBANKT/Fraud',
      sender: 'VM-KOTAKB',
      smsId: 'test2',
      date: DateTime(2026, 7, 10),
    );

    expect(parsed, isNotNull);
    expect(parsed!.merchant, '9966358368@axl');
    expect(parsed.amount, 30.0);
  });

  test('SBI credit (typed into Quick-add) parses type/amount/merchant/date', () {
    final parsed = parser.parseSMS(
      body:
          'Dear SBI User, your A/c X7169-credited by Rs.90 on 11Dec25 transfer '
          'from BOLLU VENU Ref No 115489645608 -SBI',
      sender: '', // quick-add has no sender
      smsId: '',
      date: DateTime(2026, 7, 11),
    );

    expect(parsed, isNotNull);
    expect(parsed!.type, 'income');
    expect(parsed.amount, 90.0);
    expect(parsed.merchant, 'BOLLU VENU');
    expect(parsed.date, DateTime(2025, 12, 11));
  });

  test('named payee VPA still resolves to its handle', () {
    final parsed = parser.parseSMS(
      body: 'Sent Rs.500.00 from Kotak Bank AC X3304 to EKART@ybl on '
          '10-07-26.UPI Ref 655739332521. Not you, https://kotak.com/KBANKT/Fraud',
      sender: 'VM-KOTAKB',
      smsId: 'test3',
      date: DateTime(2026, 7, 10),
    );

    expect(parsed, isNotNull);
    expect(parsed!.merchant, 'EKART');
  });
}
