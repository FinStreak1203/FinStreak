import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_database.dart';
import 'firestore_support.dart';

/// Firestore-backed goal store, scoped to `users/{uid}/goals`.
class GoalDao {
  final FirebaseFirestore _db;
  final String? _uid;
  GoalDao(this._db, this._uid);

  CollectionReference<Map<String, dynamic>>? get _col => _uid == null
      ? null
      : _db.collection('users').doc(_uid).collection('goals');

  Stream<List<Goal>> watchAllGoals() {
    final col = _col;
    if (col == null) return Stream.value(const []);
    return col.snapshots().map((snap) {
      final list = snap.docs.map(_fromDoc).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<int> insertGoal(GoalsCompanion e) async {
    final col = _col;
    if (col == null) return 0;
    final id = genNumericId();
    await col.doc(id.toString()).set(_companionToMap(id, e));
    return id;
  }

  Future<int> deleteGoal(int id) async {
    final col = _col;
    if (col == null) return 0;
    await col.doc(id.toString()).delete();
    return 1;
  }

  Future<bool> updateGoal(Goal goal) async {
    final col = _col;
    if (col == null) return false;
    await col.doc(goal.id.toString()).set(_modelToMap(goal));
    return true;
  }

  Goal _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final td = d['targetDate'];
    return Goal(
      id: (d['id'] as num).toInt(),
      name: d['name'] as String? ?? '',
      targetAmount: (d['targetAmount'] as num?)?.toDouble() ?? 0,
      savedAmount: (d['savedAmount'] as num?)?.toDouble() ?? 0,
      targetDate: td == null ? null : tsToDate(td),
      remindersEnabled: d['remindersEnabled'] as bool? ?? false,
      createdAt: tsToDate(d['createdAt']),
    );
  }

  Map<String, dynamic> _modelToMap(Goal g) => {
        'id': g.id,
        'name': g.name,
        'targetAmount': g.targetAmount,
        'savedAmount': g.savedAmount,
        'targetDate': g.targetDate,
        'remindersEnabled': g.remindersEnabled,
        'createdAt': g.createdAt,
      };

  Map<String, dynamic> _companionToMap(int id, GoalsCompanion e) => {
        'id': id,
        'name': e.name.value,
        'targetAmount': e.targetAmount.value,
        'savedAmount': e.savedAmount.present ? e.savedAmount.value : 0,
        'targetDate': e.targetDate.present ? e.targetDate.value : null,
        'remindersEnabled':
            e.remindersEnabled.present ? e.remindersEnabled.value : false,
        'createdAt': e.createdAt.present ? e.createdAt.value : DateTime.now(),
      };
}
