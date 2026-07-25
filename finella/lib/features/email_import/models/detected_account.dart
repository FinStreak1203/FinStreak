/// A bank account inferred from imported emails, offered to the user for
/// one-tap creation in the Accounts tab.
class DetectedAccount {
  final String bankName;
  final String accountNumber; // e.g. "XX0229"
  final String accountType; // "bank" or "credit_card"
  final String imagePath;
  bool isSelected; // for the UI checkbox

  DetectedAccount({
    required this.bankName,
    required this.accountNumber,
    required this.accountType,
    required this.imagePath,
    this.isSelected = true,
  });

  /// Account label stored in the DB, e.g. "HDFC XX0229".
  String get displayName => '$bankName $accountNumber';

  String get typeLabel =>
      accountType == 'credit_card' ? 'Credit Card' : 'Bank Account';
}
