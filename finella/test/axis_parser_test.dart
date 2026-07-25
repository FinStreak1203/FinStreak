import 'package:flutter_test/flutter_test.dart';
import 'package:finella/core/parser/axis_parser.dart';

// Axis statement in Syncfusion extractTextLines() form: a date line, particulars
// wrapped across lines, and the trailing line ending with "amount balance branch".
// Short rows put date + particulars + amounts on ONE line.
const _sample = '''
Statement of Axis Account No: 922010044754394 for the period
Tran Date Chq No Particulars Debit Credit Balance Init.
OPENING BALANCE            25462.68
23-12-2025
UPI/P2A/627977632071/BADVEETI
/SBIN/Payment/ 59940.00            85402.68 3987
23-12-2025
UPI/P2A/220054626112/PYDIMARRI
VIDHYADHAR/Paymen/YES BANK LIMITED
YBS 59940.00             25462.68 3987
01-01-2026
SB:922010044754394:Int.Pd:01-10-2025 to 31-
12-2025                 45.00              25507.68 3987
29-04-2026
UPI/P2M/682604759005/ABHIBUS
/Payvia/AIRTEL PAYMENTS BANK 753.95 24753.73 3987
04-06-2026 UPI/P2A/615542632352/Mr VIDHYA/CIUB/NA/ 31000.00             55753.73 3987
''';

// Two rows that are identical in date, amount and particulars, plus a charge
// and its refund sharing one UPI ref — both real rows from an Axis statement.
// Each must keep a distinct emailId or the import screen drops one as a dupe.
const _collidingSample = '''
Statement of Axis Account No: 914010018372651 for the period
OPENING BALANCE            28186.38
25-06-2026 DD Issue Chrgs Incl GST 59.00 28127.38 1413
25-06-2026 DD Issue Chrgs Incl GST 59.00 28068.38 1413
06-05-2026
UPI/P2M/612634367590/Google
Cl/YesBank_Y/Recurrin//P2V/ 2.00 28066.38 1413
13-05-2026 UPI/P2M/612634367590/Google Cloud/YESB// 2.00 28068.38 100
''';

void main() {
  final txs = AxisParser.parseStatementText(_sample);

  test('identical same-day rows and ref-sharing refunds get distinct keys', () {
    final rows = AxisParser.parseStatementText(_collidingSample);
    expect(rows.length, 4);
    expect(rows.map((t) => t.emailId).toSet().length, 4,
        reason: 'emailId must be unique per row — it is the import dedup key');

    // The two 59.00 DD charges differ only by running balance.
    expect(rows[0].amount, 59.0);
    expect(rows[1].amount, 59.0);
    expect(rows[0].emailId, isNot(rows[1].emailId));

    // Same UPI ref, opposite directions → distinct rows.
    expect(rows[2].upiRef, rows[3].upiRef);
    expect(rows[2].type, 'expense');
    expect(rows[3].type, 'income');
  });

  test('extracts every row incl. the single-line one', () {
    expect(txs.length, 5);
  });

  test('direction from running balance + merchant/ref/category', () {
    // 25462.68 → 85402.68 (credit 59940)
    expect(txs[0].type, 'income');
    expect(txs[0].amount, 59940.0);
    expect(txs[0].merchant, 'Badveeti');
    expect(txs[0].upiRef, '627977632071');
    expect(txs[0].bankName, 'Axis');

    // 85402.68 → 25462.68 (debit 59940)
    expect(txs[1].type, 'expense');
    expect(txs[1].merchant, 'Pydimarri Vidhyadhar');

    // Interest paid to customer → income. The parser deliberately sets no
    // category; CategoryClassifier derives it from the merchant at import.
    expect(txs[2].type, 'income');
    expect(txs[2].amount, 45.0);
    expect(txs[2].merchant, 'Interest Earned');
    expect(txs[2].category, isNull);

    // P2M merchant spend → expense
    expect(txs[3].type, 'expense');
    expect(txs[3].merchant, 'Abhibus');

    // Single-line row (date + particulars + amounts on one line) → credit
    expect(txs[4].type, 'income');
    expect(txs[4].amount, 31000.0);
    expect(txs[4].merchant, 'Mr Vidhya');
  });
}
