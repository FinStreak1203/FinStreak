import 'package:flutter_test/flutter_test.dart';
import 'package:finella/core/parser/icici_parser.dart';
import 'package:finella/core/services/email_parser_service.dart'
    show ParsedTransaction;

void main() {
  group('ICICIParser.parseStatementRow', () {
    test('UPI withdrawal → expense with merchant + category', () {
      final tx = ICICIParser.parseStatementRow(
        date: '25.05.2026',
        remarks: 'UPI/SWIGGY/swiggy@icici/Payment from Ph',
        withdrawal: '350.00',
        deposit: '',
        balance: '18,518.21',
      )!;
      expect(tx.type, 'expense');
      expect(tx.amount, 350.0);
      expect(tx.merchant, 'Swiggy');
      expect(tx.category, 'Food');
      expect(tx.instrumentType, 'upi');
      expect(tx.availableBalance, 18518.21);
      expect(tx.date, DateTime(2026, 5, 25));
      expect(tx.bankName, 'ICICI');
    });

    test('deposit → income', () {
      final tx = ICICIParser.parseStatementRow(
        date: '26.05.2026',
        remarks: 'UPI/LYRA IVAN/lyra@oksbi/UPI',
        withdrawal: '',
        deposit: '12000.00',
        balance: '30518.21',
      )!;
      expect(tx.type, 'income');
      expect(tx.amount, 12000.0);
      expect(tx.merchant, 'Lyra Ivan');
    });

    test('NACH/ACH remarks → EMI + recurring', () {
      final tx = ICICIParser.parseStatementRow(
        date: '01.06.2026',
        remarks: 'ACH/RAZORPAY PAYMENTS PV/EMI',
        withdrawal: '1500',
        deposit: '',
        balance: '29018.21',
      )!;
      expect(tx.merchant, 'Razorpay Payments Pv');
      expect(tx.category, 'EMI');
      expect(tx.instrumentType, 'nach_ecs');
      expect(tx.isRecurring, true);
    });

    test('monthly e-statement narration types → merchant + category', () {
      ParsedTransaction row(String remarks) =>
          ICICIParser.parseStatementRow(
            date: '26.12.2025',
            remarks: remarks,
            withdrawal: '100.00',
            deposit: '',
            balance: '500.00',
          )!;

      expect(row('CMS/ SALARY 2025DEC ELEMICA SOLUTIONS').merchant, 'Salary');
      expect(row('VSI/GOOGLEPLAY /202512300256/605').merchant, 'Googleplay');
      expect(row('VSI/GOOGLEPLAY /202512300256/605').category, 'Entertainment');
      expect(row('DCardfee5291DEC25-NOV26+GST').merchant, 'Card Fee');
      expect(row('DCardfee5291DEC25-NOV26+GST').category, 'Fees');
      expect(row('POSDEC CHG/26-12-2025/5291+GST').merchant, 'POS Charges');
      expect(row('BIL/Auto Loan XX37871 EMI Challa R').merchant, 'Loan EMI');
      expect(row('BIL/Auto Loan XX37871 EMI Challa R').category, 'EMI');
      expect(row('004001624800:Int.Pd:30-09-2025').merchant, 'Interest');
      expect(row('004001624800:Int.Pd:30-09-2025').category, 'Interest');
      expect(row('UPI/APOLLO PHA/APOLLOPHARMACY/Payment fo/YES').category,
          'Health');
    });

    test('zero/empty amount → null', () {
      expect(
        ICICIParser.parseStatementRow(
          date: '01.06.2026',
          remarks: 'x',
          withdrawal: '',
          deposit: '',
          balance: '0',
        ),
        isNull,
      );
    });
  });

  group('ICICIParser.parseSMS', () {
    test('UPI debit', () {
      final tx = ICICIParser.parseSMS(
        'Rs.6545.50 debited from ICICI Bank A/c XX4326 for UPI/DIGIT INSUR/'
        'payment on 01-Jun-26',
      )!;
      expect(tx.type, 'expense');
      expect(tx.amount, 6545.50);
      expect(tx.merchant, 'Digit Insur');
      expect(tx.accountNumber, 'XX4326');
      expect(tx.date, DateTime(2026, 6, 1));
    });

    test('UPI credit', () {
      final tx = ICICIParser.parseSMS(
        'Rs.12000.00 credited to ICICI Bank A/c XX4326 by UPI/LYRA IVAN/upi',
      )!;
      expect(tx.type, 'income');
      expect(tx.amount, 12000.0);
      expect(tx.merchant, 'Lyra Ivan');
    });

    test('NACH debit alert', () {
      final tx = ICICIParser.parseSMS(
        'ICICI Bank Acct XX4326 debited INR 1500.00 on 01-Jun-26. Info: NACH',
      )!;
      expect(tx.type, 'expense');
      expect(tx.amount, 1500.0);
      expect(tx.instrumentType, 'nach_ecs');
    });

    test('non-transaction → null', () {
      expect(ICICIParser.parseSMS('Your OTP is 123456'), isNull);
    });
  });
}
