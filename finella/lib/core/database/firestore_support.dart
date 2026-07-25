import 'package:cloud_firestore/cloud_firestore.dart';

/// Monotonic numeric id generator.
///
/// The app's models use integer ids (a legacy of the old Drift schema). We keep
/// that contract by generating microsecond-based ids and using their string
/// form as the Firestore document id. The guard guarantees uniqueness even when
/// two rows are written within the same microsecond (e.g. a transfer's two legs).
int _lastId = 0;
int genNumericId() {
  final now = DateTime.now().microsecondsSinceEpoch;
  _lastId = now > _lastId ? now : _lastId + 1;
  return _lastId;
}

/// Coerces a Firestore value into a [DateTime] (handles Timestamp / DateTime /
/// millis), defaulting to now for missing/unknown values.
DateTime tsToDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return DateTime.now();
}
