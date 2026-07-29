import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_database.dart';
import 'firestore_support.dart';

/// Firestore-backed learning content store, scoped to `users/{uid}/learning_contents`.
class LearningContentDao {
  final FirebaseFirestore _db;
  final String? _uid;
  LearningContentDao(this._db, this._uid);

  CollectionReference<Map<String, dynamic>>? get _col => _uid == null
      ? null
      : _db.collection('users').doc(_uid).collection('learning_contents');

  Stream<List<LearningContent>> watchAll() {
    final col = _col;
    if (col == null) return Stream.value(const []);
    return col.snapshots().map((snap) {
      final list = snap.docs.map(_fromDoc).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<LearningContent>> watchByCategory(String category) {
    final col = _col;
    if (col == null) return Stream.value(const []);
    return col
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  Future<List<LearningContent>> getAll() async {
    final col = _col;
    if (col == null) return const [];
    final snap = await col.get();
    return snap.docs.map(_fromDoc).toList();
  }

  Future<int> insert(LearningContentsCompanion e) async {
    final col = _col;
    if (col == null) return 0;
    final id = genNumericId();
    await col.doc(id.toString()).set(_companionToMap(id, e));
    return id;
  }

  Future<bool> update(LearningContent entry) async {
    final col = _col;
    if (col == null) return false;
    await col.doc(entry.id.toString()).set(_modelToMap(entry));
    return true;
  }

  Future<int> delete(int id) async {
    final col = _col;
    if (col == null) return 0;
    await col.doc(id.toString()).delete();
    return 1;
  }

  LearningContent _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return LearningContent(
      id: (d['id'] as num).toInt(),
      title: d['title'] as String? ?? '',
      type: d['type'] as String? ?? 'article',
      category: d['category'] as String? ?? 'general',
      contentUrl: d['contentUrl'] as String?,
      xpReward: (d['xpReward'] as num?)?.toInt() ?? 10,
      durationMinutes: (d['durationMinutes'] as num?)?.toInt(),
      createdAt: tsToDate(d['createdAt']),
    );
  }

  Map<String, dynamic> _modelToMap(LearningContent c) => {
        'id': c.id,
        'title': c.title,
        'type': c.type,
        'category': c.category,
        'contentUrl': c.contentUrl,
        'xpReward': c.xpReward,
        'durationMinutes': c.durationMinutes,
        'createdAt': c.createdAt,
      };

  Map<String, dynamic> _companionToMap(int id, LearningContentsCompanion e) => {
        'id': id,
        'title': e.title.value,
        'type': e.type.value,
        'category': e.category.value,
        'contentUrl': e.contentUrl.present ? e.contentUrl.value : null,
        'xpReward': e.xpReward.present ? e.xpReward.value : 10,
        'durationMinutes': e.durationMinutes.present ? e.durationMinutes.value : null,
        'createdAt': e.createdAt.present ? e.createdAt.value : DateTime.now(),
      };
}

/// Firestore-backed learning progress store, scoped to `users/{uid}/learning_progresses`.
class LearningProgressDao {
  final FirebaseFirestore _db;
  final String? _uid;
  LearningProgressDao(this._db, this._uid);

  CollectionReference<Map<String, dynamic>>? get _col => _uid == null
      ? null
      : _db.collection('users').doc(_uid).collection('learning_progresses');

  Stream<List<LearningProgressesData>> watchAll() {
    final col = _col;
    if (col == null) return Stream.value(const []);
    return col.snapshots().map((snap) {
      final list = snap.docs.map(_fromDoc).toList();
      list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return list;
    });
  }

  Stream<List<LearningProgressesData>> watchCompleted() {
    final col = _col;
    if (col == null) return Stream.value(const []);
    return col
        .where('completed', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  Future<List<LearningProgressesData>> getAll() async {
    final col = _col;
    if (col == null) return const [];
    final snap = await col.get();
    return snap.docs.map(_fromDoc).toList();
  }

  Future<int> insert(LearningProgressesCompanion e) async {
    final col = _col;
    if (col == null) return 0;
    final id = genNumericId();
    await col.doc(id.toString()).set(_companionToMap(id, e));
    return id;
  }

  Future<bool> update(LearningProgressesData entry) async {
    final col = _col;
    if (col == null) return false;
    await col.doc(entry.id.toString()).set(_modelToMap(entry));
    return true;
  }

  Future<bool> upsertProgress({
    required int contentId,
    required String contentTitle,
    required String contentType,
    required String contentCategory,
    required bool completed,
    double? score,
    DateTime? completedAt,
  }) async {
    final col = _col;
    if (col == null) return false;

    // Check if progress exists for this content
    final existing = await col.where('contentId', isEqualTo: contentId).limit(1).get();
    final now = DateTime.now();

    if (existing.docs.isNotEmpty) {
      final id = (existing.docs.first.data()['id'] as num).toInt();
      await col.doc(id.toString()).set({
        'completed': completed,
        'score': score,
        'completedAt': completedAt ?? (completed ? now : null),
        'progressPercent': completed ? 100 : 0,
      }, SetOptions(merge: true));
    } else {
      final id = genNumericId();
      await col.doc(id.toString()).set({
        'id': id,
        'contentId': contentId,
        'contentTitle': contentTitle,
        'contentType': contentType,
        'contentCategory': contentCategory,
        'completed': completed,
        'score': score,
        'completedAt': completedAt ?? (completed ? now : null),
        'startedAt': now,
        'progressPercent': completed ? 100 : 0,
      });
    }
    return true;
  }

  LearningProgressesData _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return LearningProgressesData(
      id: (d['id'] as num).toInt(),
      contentId: (d['contentId'] as num?)?.toInt() ?? 0,
      contentTitle: d['contentTitle'] as String? ?? '',
      contentType: d['contentType'] as String? ?? '',
      contentCategory: d['contentCategory'] as String? ?? '',
      completed: d['completed'] as bool? ?? false,
      score: (d['score'] as num?)?.toDouble(),
      completedAt: d['completedAt'] != null ? tsToDate(d['completedAt']) : null,
      startedAt: tsToDate(d['startedAt']),
    );
  }

  Map<String, dynamic> _modelToMap(LearningProgressesData p) => {
        'id': p.id,
        'contentId': p.contentId,
        'contentTitle': p.contentTitle,
        'contentType': p.contentType,
        'contentCategory': p.contentCategory,
        'completed': p.completed,
        'score': p.score,
        'completedAt': p.completedAt,
        'startedAt': p.startedAt,
      };

  Map<String, dynamic> _companionToMap(int id, LearningProgressesCompanion e) => {
        'id': id,
        'contentId': e.contentId.value,
        'contentTitle': e.contentTitle.value,
        'contentType': e.contentType.value,
        'contentCategory': e.contentCategory.value,
        'completed': e.completed.present ? e.completed.value : false,
        'score': e.score.present ? e.score.value : null,
        'completedAt': e.completedAt.present ? e.completedAt.value : null,
        'startedAt': e.startedAt.present ? e.startedAt.value : DateTime.now(),
      };
}