import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'app_database.dart';
import 'firestore_support.dart';

/// Firestore-backed transaction store, scoped to `users/{uid}/transactions`.
///
/// Keeps the original DAO surface (Companion inserts, int ids, model returns)
/// so the rest of the app is unchanged — only the storage backend differs.
class TransactionDao {
  final FirebaseFirestore _db;
  final String? _uid;
  TransactionDao(this._db, this._uid);

  CollectionReference<Map<String, dynamic>>? get _col => _uid == null
      ? null
      : _db.collection('users').doc(_uid).collection('transactions');

  Stream<List<Transaction>> watchAllTransactions() {
    final col = _col;
    if (col == null) return Stream.value(const []);
    return col.snapshots().map((snap) {
      final list = snap.docs.map(_fromDoc).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Future<List<Transaction>> getAllTransactions() async {
    final col = _col;
    if (col == null) return const [];
    final snap = await col.get();
    final list = snap.docs.map(_fromDoc).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<int> insertTransaction(TransactionsCompanion e) async {
    final col = _col;
    if (col == null) return 0;
    final id = genNumericId();
    await col.doc(id.toString()).set(_companionToMap(id, e));
    return id;
  }

  Future<int> deleteTransaction(int id) async {
    final col = _col;
    if (col == null) return 0;
    await col.doc(id.toString()).delete();
    return 1;
  }

  /// Deletes both rows of a transfer that share the given [ref].
  Future<int> deleteByTransferRef(String ref) async {
    final col = _col;
    if (col == null) return 0;
    final q = await col.where('transferRef', isEqualTo: ref).get();
    for (final d in q.docs) {
      await d.reference.delete();
    }
    return q.docs.length;
  }

  Future<bool> updateTransaction(Transaction tx) async {
    final col = _col;
    if (col == null) return false;
    await col.doc(tx.id.toString()).set(_modelToMap(tx));
    return true;
  }

  Transaction _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Transaction(
      id: (d['id'] as num).toInt(),
      type: d['type'] as String,
      amount: (d['amount'] as num).toDouble(),
      categoryId: d['categoryId'] as String? ?? '',
      categoryName: d['categoryName'] as String? ?? '',
      accountId: d['accountId'] as String? ?? '',
      accountName: d['accountName'] as String? ?? '',
      payee: d['payee'] as String? ?? '',
      memo: d['memo'] as String? ?? '',
      tag: d['tag'] as String?,
      transferRef: d['transferRef'] as String?,
      sourceEmailId: d['sourceEmailId'] as String?,
      upiRef: d['upiRef'] as String?,
      instrumentType: d['instrumentType'] as String?,
      cardNumber: d['cardNumber'] as String?,
      source: d['source'] as String?,
      date: tsToDate(d['date']),
      createdAt: tsToDate(d['createdAt']),
      isRecurring: d['isRecurring'] as bool? ?? false,
      currency: d['currency'] as String? ?? 'INR',
    );
  }

  Map<String, dynamic> _modelToMap(Transaction t) => {
        'id': t.id,
        'type': t.type,
        'amount': t.amount,
        'categoryId': t.categoryId,
        'categoryName': t.categoryName,
        'accountId': t.accountId,
        'accountName': t.accountName,
        'payee': t.payee,
        'memo': t.memo,
        'tag': t.tag,
        'transferRef': t.transferRef,
        'sourceEmailId': t.sourceEmailId,
        'upiRef': t.upiRef,
        'instrumentType': t.instrumentType,
        'cardNumber': t.cardNumber,
        'source': t.source,
        'date': t.date,
        'createdAt': t.createdAt,
        'isRecurring': t.isRecurring,
        'currency': t.currency,
      };

  Map<String, dynamic> _companionToMap(int id, TransactionsCompanion e) => {
        'id': id,
        'type': e.type.value,
        'amount': e.amount.value,
        'categoryId': e.categoryId.value,
        'categoryName': e.categoryName.value,
        'accountId': e.accountId.value,
        'accountName': e.accountName.value,
        'payee': e.payee.present ? e.payee.value : '',
        'memo': e.memo.present ? e.memo.value : '',
        'tag': e.tag.present ? e.tag.value : null,
        'transferRef': e.transferRef.present ? e.transferRef.value : null,
        'sourceEmailId':
            e.sourceEmailId.present ? e.sourceEmailId.value : null,
        'upiRef': e.upiRef.present ? e.upiRef.value : null,
        'instrumentType':
            e.instrumentType.present ? e.instrumentType.value : null,
        'cardNumber': e.cardNumber.present ? e.cardNumber.value : null,
        'source': e.source.present ? e.source.value : null,
        'date': e.date.value,
        'createdAt': e.createdAt.present ? e.createdAt.value : DateTime.now(),
        'isRecurring': e.isRecurring.present ? e.isRecurring.value : false,
        'currency': e.currency.present ? e.currency.value : 'INR',
      };
}
