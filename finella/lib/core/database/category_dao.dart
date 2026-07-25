import 'package:cloud_firestore/cloud_firestore.dart';

/// A user-created category, stored at `users/{uid}/categories`. Icon and colour
/// are persisted by KEY (see category_options.dart) so nothing arbitrary is
/// serialized and icons survive release tree-shaking.
class CustomCategory {
  final String id; // used as a transaction's categoryId
  final String name;
  final String type; // 'income' | 'expense'
  final String iconKey;
  final String colorKey;

  const CustomCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.iconKey,
    required this.colorKey,
  });
}

/// Firestore-backed store for user-defined categories.
class CategoryDao {
  final FirebaseFirestore _db;
  final String? _uid;
  CategoryDao(this._db, this._uid);

  CollectionReference<Map<String, dynamic>>? get _col => _uid == null
      ? null
      : _db.collection('users').doc(_uid).collection('categories');

  Stream<List<CustomCategory>> watchAll() {
    final col = _col;
    if (col == null) return Stream.value(const []);
    return col.snapshots().map((snap) {
      final list = snap.docs.map(_fromDoc).toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  Future<List<CustomCategory>> getAll() async {
    final col = _col;
    if (col == null) return const [];
    final snap = await col.get();
    return snap.docs.map(_fromDoc).toList();
  }

  Future<void> add(CustomCategory c) async {
    final col = _col;
    if (col == null) return;
    await col.doc(c.id).set({
      'id': c.id,
      'name': c.name,
      'type': c.type,
      'iconKey': c.iconKey,
      'colorKey': c.colorKey,
    });
  }

  Future<void> delete(String id) async {
    final col = _col;
    if (col == null) return;
    await col.doc(id).delete();
  }

  CustomCategory _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return CustomCategory(
      id: d['id'] as String? ?? doc.id,
      name: d['name'] as String? ?? 'Category',
      type: d['type'] as String? ?? 'expense',
      iconKey: d['iconKey'] as String? ?? 'tag',
      colorKey: d['colorKey'] as String? ?? 'slate',
    );
  }
}
