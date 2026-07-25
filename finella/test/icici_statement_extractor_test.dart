import 'package:flutter_test/flutter_test.dart';
import 'package:finella/core/parser/icici_statement_extractor.dart';

// A representative slice of a real ICICI savings-account statement, in the
// layout-preserved form that PdfTextExtractor produces. Covers a leading
// withdrawal, an EMI (slice), a credit (deposit), and an ACH/NACH row.
const _sample = '''
        Transaction                              Withdrawal           Deposit       Balance
S No.              Cheque Number      Transaction Remarks
           Date                                  Amount (INR)        Amount (INR)     (INR)
                              Mr Ketavat
 1      25.05.2026                                      60.00                   18518.21
                              UPI/Mr Ketavat/9182963723@ibl/Sent using/INDIAN
                              BAN/614548283286/PTM13F654B7A3F14F07B42E
                              3B8DBF79443D
                              slice
 2      25.05.2026                                   10354.00                      8125.21
                              UPI/slice/repaymentsnesf/UPI/SLICE
                              SMAL/614513809232/NEF9b6f958950
                              ADDANKI RA
 3      28.05.2026                                                74.00    8199.21
                              UPI/ADDANKI RA/rangaravindra./UPI/State
                              Bank/614896767156/SBIfb5c471
                              RAZORPAY
 4      01.06.2026                                    1500.00                     6699.21
                              ACH/RAZORPAY PAYMENTS PV/EMI repayment
''';

void main() {
  group('IciciStatementExtractor.extractRows', () {
    final rows = IciciStatementExtractor.extractRows(_sample);

    test('extracts every transaction', () {
      expect(rows.length, 4);
    });

    test('first row → withdrawal with balance', () {
      expect(rows[0].date, '25.05.2026');
      expect(rows[0].withdrawal, '60.00');
      expect(rows[0].deposit, '');
      expect(rows[0].balance, '18518.21');
      expect(rows[0].remarks, contains('UPI/Mr Ketavat'));
    });

    test('credit row detected as deposit via balance delta', () {
      expect(rows[2].deposit, '74.00');
      expect(rows[2].withdrawal, '');
    });
  });

  // Monthly e-statement as Syncfusion actually extracts it: columns are NOT
  // space-aligned, amount+balance cells are concatenated ("220.00321.15"), the
  // date sits on its own line, and the year can merge into the amount on
  // single-line entries ("…01-12-20259,766.0036,840.15"). These are the real
  // lines from the in-app log.
  const sampleB = '''
DATEMODEPARTICULARSDEPOSITSWITHDRAWALSBALANCE
01-12-2025 B/F 541.15
01-12-2025
UPI/Nathi Raje/paytmqr6h1jrp@/Payment fr/YES
BANKL/131988172308/IBLbc2d9329156943ed9fb4b4eca70df
b5b
220.00321.15
01-12-2025
UPI/KOTHAKONDA/hamsalekha.kot/Payment fr/ICICI
Bank/722623704322/IBL07f08be7acd54565b97eb2db60ed0b
e8
5,000.00 5,321.15
02-12-2025 488805000231:Int.Coll:03-11-2025 to 01-12-202518,838.8524,159.85
''';

  group('IciciStatementExtractor — Syncfusion monthly e-statement', () {
    final txs = IciciStatementExtractor.parse(sampleB);

    test('skips B/F, splits concatenated cells, extracts each transaction', () {
      expect(txs.length, 3);
    });

    test('amount derived from balance delta (concatenation-proof)', () {
      // 541.15 → 321.15  (debit 220)
      expect(txs[0].type, 'expense');
      expect(txs[0].amount, 220.0);
      expect(txs[0].merchant, 'Nathi Raje');
      expect(txs[0].upiRef, '131988172308');

      // 321.15 → 5,321.15 (credit 5,000)
      expect(txs[1].type, 'income');
      expect(txs[1].amount, 5000.0);
      expect(txs[1].merchant, 'Kothakonda');

      // 5,321.15 → 24,159.85, year merged into the amount cell — balance is
      // still the last .dd number, so the delta gives the right amount.
      expect(txs[2].type, 'income');
      expect(txs[2].amount, 18838.70);
      expect(txs[2].merchant, 'Interest');
    });
  });

  group('IciciStatementExtractor.parse', () {
    final txs = IciciStatementExtractor.parse(_sample);

    test('maps to ParsedTransaction with type/merchant/category/ref', () {
      expect(txs.length, 4);

      expect(txs[0].type, 'expense');
      expect(txs[0].merchant, 'Mr Ketavat');
      expect(txs[0].upiRef, '614548283286');

      expect(txs[1].merchant, 'Slice');
      expect(txs[1].category, 'EMI');

      expect(txs[2].type, 'income');
      expect(txs[2].amount, 74.0);

      expect(txs[3].merchant, 'Razorpay Payments Pv');
      expect(txs[3].instrumentType, 'nach_ecs');
      expect(txs[3].isRecurring, true);
    });
  });
}
