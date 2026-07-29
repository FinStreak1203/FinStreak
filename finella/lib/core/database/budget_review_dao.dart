import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_database.dart';
import 'firestore_support.dart';

/// Firestore-backed budget reviews store, scoped to `users/{uid}/budget_reviews`.
class BudgetReviewDao {
  final FirebaseFirestore _db;
  final String? _uid;
  BudgetReviewDao(this._db, this._uid);

  CollectionReference<Map<String, dynamic>>? get _col => _uid == null
      ? null
      : _db.collection('users').doc(_uid).collection('budget_reviews');

  Stream<List<BudgetReview>> watchAll() {
    final col = _col;
    if (col == null) return Stream.value(const []);
    return col.snapshots().map((snap) {
      final list = snap.docs.map(_fromDoc).toList();
      list.sort((a, b) => b.reviewedAt.compareTo(a.reviewedAt));
      return list;
    });
  }

  Stream<List<BudgetReview>> watchByMonth(int year, int month) {
    final col = _col;
    if (col == null) return Stream.value(const []);
    return col
        .where('year', isEqualTo: year)
        .where('month', isEqualTo: month)
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  Future<List<BudgetReview>> getAll() async {
    final col = _col;
    if (col == null) return const [];
    final snap = await col.get();
    return snap.docs.map(_fromDoc).toList();
  }

  Future<int> insert(BudgetReviewsCompanion e) async {
    final col = _col;
    if (col == null) return 0;
    final id = genNumericId();
    await col.doc(id.toString()).set(_companionToMap(id, e));
    return id;
  }

  Future<bool> update(BudgetReview entry) async {
    final col = _col;
    if (col == null) return false;
    await col.doc(entry.id.toString()).set(_modelToMap(entry));
    return true;
  }

  BudgetReview _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return BudgetReview(
      id: (d['id'] as num).toInt(),
      budgetId: (d['budgetId'] as num?)?.toInt() ?? 0,
      categoryId: d['categoryId'] as String? ?? '',
      categoryName: d['categoryName'] as String? ?? '',
      year: (d['year'] as num?)?.toInt() ?? 0,
      month: (d['month'] as num?)?.toInt() ?? 1,
      plannedAmount: (d['plannedAmount'] as num?)?.toDouble() ?? 0,
      actualSpent: (d['actualSpent'] as num?)?.toDouble() ?? 0,
      notes: d['notes'] as String?,
      reviewedAt: tsToDate(d['reviewedAt']),
    );
  }

  Map<String, dynamic> _modelToMap(BudgetReview r) => {
        'id': r.id,
        'budgetId': r.budgetId,
        'categoryId': r.categoryId,
        'categoryName': r.categoryName,
        'year': r.year,
        'month': r.month,
        'plannedAmount': r.plannedAmount,
        'actualSpent': r.actualSpent,
        'notes': r.notes,
        'reviewedAt': r.reviewedAt,
      };

  Map<String, dynamic> _companionToMap(int id, BudgetReviewsCompanion e) => {
        'id': id,
        'budgetId': e.budgetId.present ? e.budgetId.value : 0,
        'categoryId': e.categoryId.value,
        'categoryName': e.categoryName.value,
        'year': e.year.value,
        'month': e.month.value,
        'plannedAmount': e.plannedAmount.value,
        'actualSpent': e.actualSpent.value,
        'notes': e.notes.present ? e.notes.value : null,
        'reviewedAt': e.reviewedAt.present ? e.reviewedAt.value : DateTime.now(),
      };
}