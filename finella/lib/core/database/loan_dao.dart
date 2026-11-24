import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_database.dart';
import 'firestore_support.dart';

/// Firestore-backed loans store, scoped to `users/{uid}/loans`.
class LoanDao {
  final FirebaseFirestore _db;
  final String? _uid;
  LoanDao(this._db, this._uid);

  CollectionReference<Map<String, dynamic>>? get _col => _uid == null
      ? null
      : _db.collection('users').doc(_uid).collection('loans');

  Stream<List<Loan>> watchAll() {
    final col = _col;
    if (col == null) return Stream.value(const []);
    return col.snapshots().map((snap) {
      final list = snap.docs.map(_fromDoc).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<List<Loan>> getAll() async {
    final col = _col;
    if (col == null) return const [];
    final snap = await col.get();
    return snap.docs.map(_fromDoc).toList();
  }

  Future<int> insert(LoansCompanion e) async {
    final col = _col;
    if (col == null) return 0;
    final id = genNumericId();
    await col.doc(id.toString()).set(_companionToMap(id, e));
    return id;
  }

  Future<bool> update(Loan entry) async {
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

  Loan _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Loan(
      id: (d['id'] as num).toInt(),
      name: d['name'] as String? ?? '',
      type: d['type'] as String? ?? 'personal',
      principalAmount: (d['principalAmount'] as num?)?.toDouble() ?? 0,
      outstandingAmount: (d['outstandingAmount'] as num?)?.toDouble() ?? 0,
      emiAmount: (d['emiAmount'] as num?)?.toDouble() ?? 0,
      interestRate: (d['interestRate'] as num?)?.toDouble() ?? 0,
      tenureMonths: (d['tenureMonths'] as num?)?.toInt() ?? 0,
      remainingMonths: (d['remainingMonths'] as num?)?.toInt() ?? 0,
      startDate: tsToDate(d['startDate']),
      nextDueDate: tsToDate(d['nextDueDate']),
      isActive: d['isActive'] as bool? ?? true,
      monthlyReconciledAt: d['monthlyReconciledAt'] != null
          ? tsToDate(d['monthlyReconciledAt'])
          : null,
      createdAt: tsToDate(d['createdAt']),
    );
  }

  Map<String, dynamic> _modelToMap(Loan l) => {
        'id': l.id,
        'name': l.name,
        'type': l.type,
        'principalAmount': l.principalAmount,
        'outstandingAmount': l.outstandingAmount,
        'emiAmount': l.emiAmount,
        'interestRate': l.interestRate,
        'tenureMonths': l.tenureMonths,
        'remainingMonths': l.remainingMonths,
        'startDate': l.startDate,
        'nextDueDate': l.nextDueDate,
        'isActive': l.isActive,
        'monthlyReconciledAt': l.monthlyReconciledAt,
        'createdAt': l.createdAt,
      };

  Map<String, dynamic> _companionToMap(int id, LoansCompanion e) => {
        'id': id,
        'name': e.name.value,
        'type': e.type.value,
        'principalAmount': e.principalAmount.value,
        'outstandingAmount': e.outstandingAmount.value,
        'emiAmount': e.emiAmount.value,
        'interestRate': e.interestRate.value,
        'tenureMonths': e.tenureMonths.value,
        'remainingMonths': e.remainingMonths.value,
        'startDate': e.startDate.value,
        'nextDueDate': e.nextDueDate.value,
        'isActive': e.isActive.present ? e.isActive.value : true,
        'monthlyReconciledAt':
            e.monthlyReconciledAt.present ? e.monthlyReconciledAt.value : null,
        'createdAt': e.createdAt.present ? e.createdAt.value : DateTime.now(),
      };
}

/// Firestore-backed EMI payments store, scoped to `users/{uid}/emi_payments`.
class EmiPaymentDao {
  final FirebaseFirestore _db;
  final String? _uid;
  EmiPaymentDao(this._db, this._uid);

  CollectionReference<Map<String, dynamic>>? get _col => _uid == null
      ? null
      : _db.collection('users').doc(_uid).collection('emi_payments');

  Stream<List<EmiPayment>> watchAll() {
    final col = _col;
    if (col == null) return Stream.value(const []);
    return col.snapshots().map((snap) {
      final list = snap.docs.map(_fromDoc).toList();
      list.sort((a, b) => b.dueDate.compareTo(a.dueDate));
      return list;
    });
  }

  Stream<List<EmiPayment>> watchByLoanId(int loanId) {
    final col = _col;
    if (col == null) return Stream.value(const []);
    return col
        .where('loanId', isEqualTo: loanId)
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  Future<List<EmiPayment>> getAll() async {
    final col = _col;
    if (col == null) return const [];
    final snap = await col.get();
    return snap.docs.map(_fromDoc).toList();
  }

  Future<int> insert(EmiPaymentsCompanion e) async {
    final col = _col;
    if (col == null) return 0;
    final id = genNumericId();
    await col.doc(id.toString()).set(_companionToMap(id, e));
    return id;
  }

  Future<bool> update(EmiPayment entry) async {
    final col = _col;
    if (col == null) return false;
    await col.doc(entry.id.toString()).set(_modelToMap(entry));
    return true;
  }

  EmiPayment _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return EmiPayment(
      id: (d['id'] as num).toInt(),
      loanId: (d['loanId'] as num).toInt(),
      amountPaid: (d['amountPaid'] as num?)?.toDouble() ?? 0,
      dueDate: tsToDate(d['dueDate']),
      paidDate: d['paidDate'] != null ? tsToDate(d['paidDate']) : null,
      isPaid: d['isPaid'] as bool? ?? false,
      isOnTime: d['isOnTime'] as bool?,
      createdAt: tsToDate(d['createdAt']),
    );
  }

  Map<String, dynamic> _modelToMap(EmiPayment p) => {
        'id': p.id,
        'loanId': p.loanId,
        'amountPaid': p.amountPaid,
        'dueDate': p.dueDate,
        'paidDate': p.paidDate,
        'isPaid': p.isPaid,
        'isOnTime': p.isOnTime,
        'createdAt': p.createdAt,
      };

  Map<String, dynamic> _companionToMap(int id, EmiPaymentsCompanion e) => {
        'id': id,
        'loanId': e.loanId.value,
        'amountPaid': e.amountPaid.value,
        'dueDate': e.dueDate.value,
        'paidDate': e.paidDate.present ? e.paidDate.value : null,
        'isPaid': e.isPaid.present ? e.isPaid.value : false,
        'isOnTime': e.isOnTime.present ? e.isOnTime.value : null,
        'createdAt': e.createdAt.present ? e.createdAt.value : DateTime.now(),
      };
}