import 'package:flutter_test/flutter_test.dart';
import 'package:finella/core/services/email_parser_service.dart';

void main() {
  final parser = EmailParserService();

  test('Kotak811 UPI payment email parses merchant, ref, category, vpa', () {
    const body = '''
Dear customer,

You have successfully made a UPI payment of INR 160.00 towards KUNCHAKURI HARINATH through the Kotak811 App.

More details below.

UPI ID: q176685178@ybl
Date: 02/07/2026
UPI Reference Number: 654903271185
''';

    final parsed = parser.parseEmail(body, 'email1',
        senderEmail: 'noreply@kotak.com');

    expect(parsed, isNotNull);
    expect(parsed!.merchant, 'KUNCHAKURI HARINATH');
    expect(parsed.amount, 160.0);
    expect(parsed.type, 'expense');
    expect(parsed.category, 'UPI Debit');
    expect(parsed.instrumentType, 'upi');
    expect(parsed.upiRef, '654903271185');
    expect(parsed.upiVpa, 'q176685178@ybl');
    expect(parsed.date, DateTime(2026, 7, 2));
    expect(parsed.bankName, 'Kotak');
  });

  test('Kotak811 UPI credit email (labeled Sender/RRN/A-c) parses fully', () {
    const body = '''
Hi 811 Customer,

You've received a UPI Credit in your Kotak A/c (XXXXXX3304).

Here's the summary of your transaction:
Date: 03/07/2026
Amount: ₹50.00
Sender: Gangula Ashwin Reddy
UPI Reference Number (RRN): 618435164925

Download the Kotak811 App.
''';

    final parsed = parser.parseEmail(body, 'email2',
        senderEmail: 'noreply@kotak.com');

    expect(parsed, isNotNull);
    expect(parsed!.type, 'income');
    expect(parsed.category, 'UPI Credit');
    expect(parsed.instrumentType, 'upi');
    expect(parsed.amount, 50.0);
    expect(parsed.merchant, 'Gangula Ashwin Reddy');
    expect(parsed.upiRef, '618435164925');
    expect(parsed.accountNumber, 'XX3304');
    expect(parsed.date, DateTime(2026, 7, 3));
    expect(parsed.bankName, 'Kotak');
  });
}
