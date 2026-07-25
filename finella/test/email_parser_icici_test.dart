import 'package:flutter_test/flutter_test.dart';
import 'package:finella/core/services/email_parser_service.dart';

void main() {
  final parser = EmailParserService();

  test('ICICI online fund transfer (no currency prefix) → expense', () {
    const body =
        'You have made an online ICICI fund transfer of 1,00,000.00 towards '
        'CHALLA RAJINEEKAR from your ICICI Bank Savings Account XXXX800 to '
        'ICICI Bank CCA Account XXXX231 on Jun 26, 2026 at 07:19 a.m..'
        'The Transaction ID is 88575546.';

    final tx = parser.parseEmail(body, 'mail-1',
        senderEmail: 'customernotification@icici.bank.in')!;

    expect(tx.type, 'expense');
    expect(tx.amount, 100000.0);
    expect(tx.merchant, 'CHALLA RAJINEEKAR');
    expect(tx.bankName, 'ICICI');
    expect(tx.accountNumber, 'XX800');
    expect(tx.upiRef, '88575546');
    expect(tx.category, 'Card Bill Payment'); // transfer to a CCA account
    expect(tx.date, DateTime(2026, 6, 26));
  });

  test('ICICI online IMPS payment → expense, clean merchant', () {
    const body =
        'Dear Customer, You have made an online IMPS payment of Rs. 1,99,999.00 '
        'towards SHIVANAGENDRA FLASH TRANSPORT on May 28, 2026 at 08:31 a.m. '
        'from your ICICI Bank Savings Account XXXX4800. The Transaction ID is '
        '614808918922.';

    final tx = parser.parseEmail(body, 'mail-3',
        senderEmail: 'customernotification@icici.bank.in')!;

    expect(tx.type, 'expense');
    expect(tx.amount, 199999.0);
    expect(tx.merchant, 'SHIVANAGENDRA FLASH TRANSPORT'); // no "wards" prefix
    expect(tx.accountNumber, 'XX4800');
    expect(tx.upiRef, '614808918922');
    expect(tx.instrumentType, 'imps');
    expect(tx.category, 'Transfer');
    expect(tx.date, DateTime(2026, 5, 28));
  });

  test('SBI DBT/Govt payment → income, labelled merchant', () {
    const body =
        'Dear Customer, DBT/Govt. payment of Rs. 3,790.40 credited to your '
        'Acc No. XXXXX383879 on 28/05/26-SBI';

    final tx = parser.parseEmail(body, 'mail-4', senderEmail: 'sbi@sbi.co.in')!;

    expect(tx.type, 'income');
    expect(tx.amount, 3790.40);
    expect(tx.merchant, 'DBT/Govt Payment');
    expect(tx.bankName, 'SBI');
    expect(tx.accountNumber, 'XX383879');
    expect(tx.category, 'Income');
    expect(tx.date, DateTime(2026, 5, 28));
  });

  test('SBI credit card USD (foreign) spend → expense + currency memo', () {
    const body =
        'Dear Cardholder, This is to inform you that, USD19.99 spent on your '
        'SBI Credit Card ending 1157 at VSAleximiapp on 27/05/26. Trxn.';

    final tx = parser.parseEmail(body, 'mail-5',
        senderEmail: 'onlinesbicard@sbicard.com')!;

    expect(tx.type, 'expense');
    expect(tx.amount, 19.99);
    expect(tx.merchant, 'VSAleximiapp');
    expect(tx.bankName, 'SBI');
    expect(tx.accountNumber, 'XX1157');
    expect(tx.accountType, 'credit_card');
    expect(tx.memo, 'USD 19.99'); // foreign value preserved
    expect(tx.date, DateTime(2026, 5, 27));
  });

  test('SBI credit card INR spend still works (regression)', () {
    const body =
        'INR 3,906.00 spent on your SBI Credit Card ending 1157 at '
        'TWALLETTELANGANA on 10/06/26. Trxn.';

    final tx = parser.parseEmail(body, 'mail-6',
        senderEmail: 'onlinesbicard@sbicard.com')!;

    expect(tx.amount, 3906.0);
    expect(tx.merchant, 'TWALLETTELANGANA');
    expect(tx.memo, isNull); // INR → no currency memo
  });

  test('ICICI credit card UPI payee keeps multi-word names', () {
    ParsedTransaction cc(String info) => parser.parseEmail(
          'Dear Customer, Your ICICI Bank Credit Card XX5004 has been used for '
          'a transaction of INR 20.00 on May 26, 2026 at 07:12:28. Info: $info',
          'm',
          senderEmail: 'credit_cards@icicibank.com',
        )!;

    expect(cc('UPI-082807123309-SRI VENK.').merchant, 'SRI VENK');
    expect(cc('UPI-084266518971-M S SAHR.').merchant, 'M S SAHR');
    expect(cc('UPI-082807123309-SRI VENK.').upiRef, '082807123309');
  });

  test('HDFC UPI credit → income with sender, body date, ref', () {
    const body =
        "Dear Customer, Greetings from HDFC Bank! We're writing to inform you "
        'that Rs.500.00 has been successfully credited to your HDFC Bank '
        'account ending in 0229. Transaction Details: a. Date: 26-05-26 b. '
        'Sender: CHALLA RAJINEEKAR (VPA: rajini1203@ibl) c. UPI Reference No.: '
        '020586230285';

    final tx = parser.parseEmail(body, 'mail-7',
        senderEmail: 'alerts@hdfcbank.net')!;

    expect(tx.type, 'income'); // credited
    expect(tx.amount, 500.0);
    expect(tx.merchant, 'CHALLA RAJINEEKAR');
    expect(tx.bankName, 'HDFC');
    expect(tx.accountNumber, 'XX0229');
    expect(tx.upiRef, '020586230285');
    expect(tx.category, 'UPI Credit');
    expect(tx.date, DateTime(2026, 5, 26)); // from body, not email date
  });

  test('Standing-instruction "due" notification is skipped (not a txn)', () {
    const body =
        'Dear Customer, Your payment of INR 210.00 towards Google Play through '
        'Standing Instruction XKe1KACWDp is due on 26/05/2026 and will be '
        'debited from your ICICI Bank Debit Card 5291. Click here to cancel '
        'this Debit or your Standing Instruction.';

    final tx = parser.parseEmail(body, 'mail-8',
        senderEmail: 'customernotification@icici.bank.in');

    expect(tx, isNull); // upcoming/due → must not import
  });

  test('Real executed debit still imports (regression for the skip)', () {
    const body =
        'Your ICICI Bank Credit Card XX5004 has been used for a transaction of '
        'INR 20.00 on May 26, 2026 at 07:12:28. Info: UPI-082807123309-SRI VENK.';

    final tx = parser.parseEmail(body, 'mail-9',
        senderEmail: 'credit_cards@icicibank.com');

    expect(tx, isNotNull);
    expect(tx!.amount, 20.0);
  });

  test('HDFC NEFT credit ("successfully added", Rs.INR) → income', () {
    const body =
        'Dear Customer, Greetings from HDFC Bank! Rs.INR 5,000.00 has been '
        'successfully added to your account ending XX0229 from NEFT '
        'Cr-ICIC0SF0002-CHALLA RAJINEEKAR-CHALLA RAJENEKAR-INXXXXXXXXXX0523 '
        'on 13-MAY-2026. The available balance in your account is Rs. INR '
        '5,022.98';

    final tx = parser.parseEmail(body, 'mail-10',
        senderEmail: 'alerts@hdfcbank.net')!;

    expect(tx.type, 'income');
    expect(tx.amount, 5000.0);
    expect(tx.merchant, 'CHALLA RAJINEEKAR');
    expect(tx.bankName, 'HDFC');
    expect(tx.accountNumber, 'XX0229');
    expect(tx.availableBalance, 5022.98);
    expect(tx.instrumentType, 'neft');
    expect(tx.category, 'Account Credit');
    expect(tx.date, DateTime(2026, 5, 13)); // from "13-MAY-2026"
  });

  test('ICICI credit card bill payment received → income', () {
    const body =
        'Dear Customer, Greetings from ICICI Bank! We have received payment of '
        'INR 25,000.00 on your ICICI Bank Credit Card account 6528 XXXX XXXX '
        '5004 on 13-May-2026. more opportunities to be of service to you';

    final tx = parser.parseEmail(body, 'mail-11',
        senderEmail: 'credit_cards@icicibank.com')!;

    expect(tx.type, 'income'); // bill paid → credit to the card
    expect(tx.amount, 25000.0);
    expect(tx.merchant, 'ICICI Credit Card Payment');
    expect(tx.bankName, 'ICICI');
    expect(tx.accountNumber, 'XX5004'); // last group, not 6528
    expect(tx.accountType, 'credit_card');
    expect(tx.category, 'Card Bill Payment');
    expect(tx.date, DateTime(2026, 5, 13));
  });

  test('Advisory notice (transfer-limit policy) is skipped', () {
    const body =
        'Dear Challa, Greetings from HDFC Bank. To protect your account from '
        'unauthorized access on Apple Devices, transfer limits on new '
        'beneficiaries will soon be applicable for the first 72 hours. '
        'Cumulative transfer amount will be capped at Rs. 50,000 within the '
        'first 72 hours across all newly added beneficiaries.';

    final tx = parser.parseEmail(body, 'mail-12',
        senderEmail: 'information@mailers.hdfcbank.bank.in');

    expect(tx, isNull); // policy notice, not a transaction
  });

  test('HSBC credit card transaction → expense', () {
    const body =
        'Dear Customer, We write to confirm that your Credit card no ending '
        'with 4482, has been used for INR 40472.80 for payment to TWALLET '
        'TELANGANA on 16 Jun 2026 at 16:21.';

    final tx = parser.parseEmail(body, 'mail-2',
        senderEmail: 'hsbc@mail.hsbc.co.in')!;

    expect(tx.type, 'expense');
    expect(tx.amount, 40472.80);
    expect(tx.merchant, 'TWALLET TELANGANA');
    expect(tx.bankName, 'HSBC');
    expect(tx.accountNumber, 'XX4482');
    expect(tx.accountType, 'credit_card');
    expect(tx.category, 'Credit Card Purchase');
    expect(tx.date, DateTime(2026, 6, 16));
  });
}
