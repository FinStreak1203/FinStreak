import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_database.dart';
import 'firestore_support.dart';

/// Firestore-backed budget store, scoped to `users/{uid}/budgets`.
class BudgetDao {
  final FirebaseFirestore _db;
  final String? _uid;
  BudgetDao(this._db, this._uid);

  CollectionReference<Map<String, dynamic>>? get _col => _uid == null
      ? null
      : _db.collection('users').doc(_uid).collection('budgets');

  Stream<List<Budget>> watchAllBudgets() {
    final col = _col;
    if (col == null) return Stream.value(const []);
    return col.snapshots().map((snap) {
      final list = snap.docs.map(_fromDoc).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<List<Budget>> getAllBudgets() async {
    final col = _col;
    if (col == null) return const [];
    final snap = await col.get();
    return snap.docs.map(_fromDoc).toList();
  }

  Future<int> insertBudget(BudgetsCompanion e) async {
    final col = _col;
    if (col == null) return 0;
    final id = genNumericId();
    await col.doc(id.toString()).set(_companionToMap(id, e));
    return id;
  }

  Future<bool> updateBudget(Budget entry) async {
    final col = _col;
    if (col == null) return false;
    await col.doc(entry.id.toString()).set(_modelToMap(entry));
    return true;
  }

  Future<int> deleteBudget(int id) async {
    final col = _col;
    if (col == null) return 0;
    await col.doc(id.toString()).delete();
    return 1;
  }

  Budget _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Budget(
      id: (d['id'] as num).toInt(),
      categoryId: d['categoryId'] as String? ?? '',
      categoryName: d['categoryName'] as String? ?? '',
      limitAmount: (d['limitAmount'] as num?)?.toDouble() ?? 0,
      year: (d['year'] as num?)?.toInt() ?? 0,
      month: (d['month'] as num?)?.toInt() ?? 1,
      createdAt: tsToDate(d['createdAt']),
    );
  }

  Map<String, dynamic> _modelToMap(Budget b) => {
        'id': b.id,
        'categoryId': b.categoryId,
        'categoryName': b.categoryName,
        'limitAmount': b.limitAmount,
        'year': b.year,
        'month': b.month,
        'createdAt': b.createdAt,
      };

  Map<String, dynamic> _companionToMap(int id, BudgetsCompanion e) => {
        'id': id,
        'categoryId': e.categoryId.value,
        'categoryName': e.categoryName.value,
        'limitAmount': e.limitAmount.value,
        'year': e.year.value,
        'month': e.month.value,
        'createdAt': e.createdAt.present ? e.createdAt.value : DateTime.now(),
      };
}
