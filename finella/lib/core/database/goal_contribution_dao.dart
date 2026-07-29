import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_database.dart';
import 'firestore_support.dart';

/// Firestore-backed goal contributions store, scoped to `users/{uid}/goal_contributions`.
class GoalContributionDao {
  final FirebaseFirestore _db;
  final String? _uid;
  GoalContributionDao(this._db, this._uid);

  CollectionReference<Map<String, dynamic>>? get _col => _uid == null
      ? null
      : _db.collection('users').doc(_uid).collection('goal_contributions');

  Stream<List<GoalContribution>> watchAll() {
    final col = _col;
    if (col == null) return Stream.value(const []);
    return col.snapshots().map((snap) {
      final list = snap.docs.map(_fromDoc).toList();
      list.sort((a, b) => b.contributedAt.compareTo(a.contributedAt));
      return list;
    });
  }

  Stream<List<GoalContribution>> watchByGoalId(int goalId) {
    final col = _col;
    if (col == null) return Stream.value(const []);
    return col
        .where('goalId', isEqualTo: goalId)
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  Future<List<GoalContribution>> getAll() async {
    final col = _col;
    if (col == null) return const [];
    final snap = await col.get();
    return snap.docs.map(_fromDoc).toList();
  }

  Future<int> insert(GoalContributionsCompanion e) async {
    final col = _col;
    if (col == null) return 0;
    final id = genNumericId();
    await col.doc(id.toString()).set(_companionToMap(id, e));
    return id;
  }

  Future<bool> update(GoalContribution entry) async {
    final col = _col;
    if (col == null) return false;
    await col.doc(entry.id.toString()).set(_modelToMap(entry));
    return true;
  }

  GoalContribution _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return GoalContribution(
      id: (d['id'] as num).toInt(),
      goalId: (d['goalId'] as num?)?.toInt() ?? 0,
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      contributedAt: tsToDate(d['contributedAt']),
      isRecurring: d['isRecurring'] as bool? ?? false,
      frequency: d['frequency'] as String?,
    );
  }

  Map<String, dynamic> _modelToMap(GoalContribution c) => {
        'id': c.id,
        'goalId': c.goalId,
        'amount': c.amount,
        'contributedAt': c.contributedAt,
        'isRecurring': c.isRecurring,
        'frequency': c.frequency,
      };

  Map<String, dynamic> _companionToMap(int id, GoalContributionsCompanion e) => {
        'id': id,
        'goalId': e.goalId.value,
        'amount': e.amount.value,
        'contributedAt': e.contributedAt.present ? e.contributedAt.value : DateTime.now(),
        'isRecurring': e.isRecurring.present ? e.isRecurring.value : false,
        'frequency': e.frequency.present ? e.frequency.value : null,
      };
}