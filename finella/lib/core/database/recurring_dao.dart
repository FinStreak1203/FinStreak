import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'firestore_support.dart';

/// A standing UPI/e-mandate (subscription) the user set up — NOT a debit.
/// Stored at `users/{uid}/recurring`, deduped by [umn].
class RecurringMandate {
  final int id;
  final String name; // merchant, e.g. "Story TV"
  final double amount;
  final String bankName;
  final String umn; // unique mandate number (dedup key)
  final DateTime createdAt;

  const RecurringMandate({
    required this.id,
    required this.name,
    required this.amount,
    required this.bankName,
    required this.umn,
    required this.createdAt,
  });
}

class RecurringDao {
  final FirebaseFirestore _db;
  final String? _uid;
  RecurringDao(this._db, this._uid);

  CollectionReference<Map<String, dynamic>>? get _col => _uid == null
      ? null
      : _db.collection('users').doc(_uid).collection('recurring');

  Stream<List<RecurringMandate>> watchAll() {
    final col = _col;
    if (col == null) return Stream.value(const []);
    return col.snapshots().map((snap) {
      final list = snap.docs.map(_fromDoc).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<List<RecurringMandate>> getAll() async {
    final col = _col;
    if (col == null) return const [];
    final snap = await col.get();
    return snap.docs.map(_fromDoc).toList();
  }

  /// Adds a mandate, skipping if one with the same [umn] already exists.
  /// Returns true if a new mandate was created.
  Future<bool> addIfNew({
    required String name,
    required double amount,
    required String bankName,
    required String umn,
  }) async {
    final col = _col;
    if (col == null) return false;
    if (umn.isNotEmpty) {
      final existing = await col.where('umn', isEqualTo: umn).limit(1).get();
      if (existing.docs.isNotEmpty) return false;
    }
    final id = genNumericId();
    await col.doc(id.toString()).set({
      'id': id,
      'name': name,
      'amount': amount,
      'bankName': bankName,
      'umn': umn,
      'createdAt': DateTime.now(),
    });
    return true;
  }

  Future<void> delete(int id) async {
    final col = _col;
    if (col == null) return;
    await col.doc(id.toString()).delete();
  }

  RecurringMandate _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return RecurringMandate(
      id: (d['id'] as num?)?.toInt() ?? 0,
      name: d['name'] as String? ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      bankName: d['bankName'] as String? ?? '',
      umn: d['umn'] as String? ?? '',
      createdAt: tsToDate(d['createdAt']),
    );
  }
}
