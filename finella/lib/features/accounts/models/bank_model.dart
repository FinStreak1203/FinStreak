import '../../../core/constants/bank_assets.dart';

/// A selectable bank / wallet shown in the account picker.
class BankModel {
  final String id;
  final String name;
  final String imagePath;

  const BankModel({
    required this.id,
    required this.name,
    required this.imagePath,
  });
}

/// Built-in banks shown in the bank selector sheet.
const List<BankModel> predefinedBanks = [
  BankModel(id: 'hdfc', name: 'HDFC', imagePath: BankAssets.hdfc),
  BankModel(id: 'icici', name: 'ICICI', imagePath: BankAssets.icici),
  BankModel(id: 'sbi', name: 'SBI', imagePath: BankAssets.sbi),
  BankModel(id: 'axis', name: 'Axis', imagePath: BankAssets.axis),
  BankModel(id: 'canara', name: 'Canara', imagePath: BankAssets.canara),
  BankModel(id: 'idbi', name: 'IDBI', imagePath: BankAssets.idbi),
  BankModel(id: 'iob', name: 'IOB', imagePath: BankAssets.iob),
  BankModel(id: 'pnb', name: 'PNB', imagePath: BankAssets.pnb),
  BankModel(id: 'yes', name: 'Yes Bank', imagePath: BankAssets.yes),
  BankModel(id: 'paytm', name: 'Paytm', imagePath: BankAssets.paytm),
];

/// Built-in wallets shown alongside the banks.
const List<BankModel> predefinedWallets = [
  BankModel(id: 'gpay', name: 'GPay', imagePath: BankAssets.gpay),
  BankModel(id: 'phonepe', name: 'PhonePe', imagePath: BankAssets.phonepe),
];

/// Returns the logo asset path for a given account [id], or `null` if the id
/// does not match a known bank / wallet.
String? bankImagePathFor(String? id) {
  if (id == null) return null;
  for (final bank in [...predefinedBanks, ...predefinedWallets]) {
    if (bank.id == id) return bank.imagePath;
  }
  return null;
}

/// Returns the logo asset path matching an account [name] (case-insensitive),
/// or `null` if no predefined bank / wallet shares that name.
String? bankImagePathForName(String? name) {
  if (name == null) return null;
  final key = name.trim().toLowerCase();
  for (final bank in [...predefinedBanks, ...predefinedWallets]) {
    if (bank.name.toLowerCase() == key) return bank.imagePath;
  }
  // Full names from the SMS parser (e.g. "State Bank of India").
  return BankAssets.matchOrNull(key);
}

/// Resolves a bank/wallet logo from an account label, tolerating suffixes like
/// "ICICI Credit Card" or "Axis Credit Card" (exact match first, then a
/// word-contains match). Returns `null` for non-bank accounts (Cash, wallets
/// without a logo, etc.).
String? bankImagePathForAccount(String? accountName) {
  if (accountName == null) return null;
  final key = accountName.trim().toLowerCase();
  if (key.isEmpty) return null;
  final all = [...predefinedBanks, ...predefinedWallets];
  // Exact match wins.
  for (final bank in all) {
    if (bank.name.toLowerCase() == key) return bank.imagePath;
  }
  // Then a contained bank name, e.g. "ICICI Credit Card" → ICICI.
  for (final bank in all) {
    if (key.contains(bank.name.toLowerCase())) return bank.imagePath;
  }
  // Finally, full bank names (e.g. "Indian Overseas Bank", "State Bank of …").
  return BankAssets.matchOrNull(key);
}
