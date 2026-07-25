import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_database.dart';
import 'firestore_support.dart';

/// Firestore-backed account store, scoped to `users/{uid}/accounts`.
class AccountDao {
  final FirebaseFirestore _db;
  final String? _uid;
  AccountDao(this._db, this._uid);

  CollectionReference<Map<String, dynamic>>? get _col => _uid == null
      ? null
      : _db.collection('users').doc(_uid).collection('accounts');

  Stream<List<Account>> watchAllAccounts() {
    final col = _col;
    if (col == null) return Stream.value(const []);
    return col.snapshots().map((snap) {
      final list = snap.docs.map(_fromDoc).toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  Future<List<Account>> getAllAccounts() async {
    final col = _col;
    if (col == null) return const [];
    final snap = await col.get();
    final list = snap.docs.map(_fromDoc).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<int> insertAccount(AccountsCompanion e) async {
    final col = _col;
    if (col == null) return 0;
    final id = genNumericId();
    await col.doc(id.toString()).set(_companionToMap(id, e));
    return id;
  }

  Future<bool> updateAccount(Account entry) async {
    final col = _col;
    if (col == null) return false;
    await col.doc(entry.id.toString()).set(_modelToMap(entry));
    return true;
  }

  Future<int> deleteAccount(int id) async {
    final col = _col;
    if (col == null) return 0;
    await col.doc(id.toString()).delete();
    return 1;
  }

  /// Finds an account by its bank name + masked number (e.g. "HDFC", "XX0229"),
  /// or null if none exists. Used to avoid duplicate auto-created accounts and
  /// to link imported transactions.
  Future<Account?> findByBankAndNumber(
      String bankName, String? accountNumber) async {
    if (accountNumber == null || accountNumber.isEmpty) return null;
    final bank = bankName.trim().toLowerCase();
    final num = accountNumber.trim().toLowerCase();
    for (final a in await getAllAccounts()) {
      final aBank = (a.bankName ?? a.name).trim().toLowerCase();
      final aNum = (a.accountNumber ?? '').trim().toLowerCase();
      if (aNum == num && (aBank == bank || aBank.contains(bank))) return a;
    }
    return null;
  }

  /// Seeds the default accounts the first time a user has none. Guarded by a
  /// per-uid pref so it runs at most once per account.
  Future<void> ensureSeeded(SharedPreferences prefs) async {
    final uid = _uid;
    if (uid == null) return;
    final key = 'seeded_accounts_$uid';
    if (prefs.getBool(key) ?? false) return;

    final existing = await getAllAccounts();
    if (existing.isEmpty) {
      for (final (name, type) in const [
        ('HDFC', 'bank'),
        ('ICICI', 'bank'),
        ('SBI', 'bank'),
        ('Paytm', 'wallet'),
        ('Cash', 'cash'),
      ]) {
        await insertAccount(
          AccountsCompanion.insert(name: name, type: type, balance: 0),
        );
      }
    }
    await prefs.setBool(key, true);
  }

  Account _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Account(
      id: (d['id'] as num).toInt(),
      name: d['name'] as String? ?? '',
      type: d['type'] as String? ?? 'bank',
      balance: (d['balance'] as num?)?.toDouble() ?? 0,
      currency: d['currency'] as String? ?? 'INR',
      bankName: d['bankName'] as String?,
      accountNumber: d['accountNumber'] as String?,
      imagePath: d['imagePath'] as String?,
      createdAt: tsToDate(d['createdAt']),
    );
  }

  Map<String, dynamic> _modelToMap(Account a) => {
        'id': a.id,
        'name': a.name,
        'type': a.type,
        'balance': a.balance,
        'currency': a.currency,
        'bankName': a.bankName,
        'accountNumber': a.accountNumber,
        'imagePath': a.imagePath,
        'createdAt': a.createdAt,
      };

  Map<String, dynamic> _companionToMap(int id, AccountsCompanion e) => {
        'id': id,
        'name': e.name.value,
        'type': e.type.value,
        'balance': e.balance.value,
        'currency': e.currency.present ? e.currency.value : 'INR',
        'bankName': e.bankName.present ? e.bankName.value : null,
        'accountNumber':
            e.accountNumber.present ? e.accountNumber.value : null,
        'imagePath': e.imagePath.present ? e.imagePath.value : null,
        'createdAt': e.createdAt.present ? e.createdAt.value : DateTime.now(),
      };
}
