import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import '../providers/database_providers.dart';
import 'gmail_auth_service.dart';

/// Reads recent bank-alert emails from Gmail using the read-only scope granted
/// by [GmailAuthService]. Parsing of the bodies happens in a later step; this
/// service only fetches raw email content.
class GmailService {
  final GmailAuthService _auth;
  final FirebaseFirestore _db;
  final String? _uid;
  GmailService(this._auth, this._db, this._uid);

  /// Per-user collection of imported Gmail message ids (replaces the old
  /// device-local SharedPreferences list — survives reinstall + syncs devices).
  CollectionReference<Map<String, dynamic>>? get _processedCol => _uid == null
      ? null
      : _db.collection('users').doc(_uid).collection('gmail_processed');

  /// Fetch at most this many emails per call. Raised from 10 because bank
  /// domains send lots of marketing mail; the keyword filter + parser narrow
  /// it down, but we need headroom so real transaction alerts aren't crowded
  /// out by recent promos.
  static const int _maxResults = 25;

  /// Bank alert senders, restricted to the last 90 days.
  ///
  /// Matches by DOMAIN (not exact address) because banks send alerts from many
  /// sub-addresses — e.g. Axis credit-card alerts come from cc.alerts@axisbank.com,
  /// not alerts@axisbank.com (this domain match covers every HDFC variation too:
  /// alerts@/noreply@/hdfcbank@alerts.hdfcbank.com). The content parser still
  /// filters out non-transaction mail, so a broad sender match is safe.
  ///
  /// `in:anywhere` searches ALL tabs and folders (Primary + Updates + Promotions
  /// + All Mail + Spam) — bank alerts often land in Updates/Promotions, not
  /// Primary, so without this they get missed.
  ///
  /// The keyword group (debited/credited/transaction/...) is essential: bank
  /// domains send far more MARKETING mail than transaction alerts, so without
  /// it the recent results are all promos and real transactions get crowded
  /// out. These words appear in transaction alerts but rarely in promos.
  /// Sender + keyword part of the query (everything except the date window).
  static const String _baseQuery =
      // `bank.in` is RBI's reserved domain for Indian banks — one term covers
      // every alerts@<bank>.bank.in sender. The rest are card/intl issuers and
      // legacy bank domains not on bank.in.
      'from:(bank.in OR '
      'sbicard.com OR '
      'americanexpress.com OR '
      'citigroup.com OR '
      'hdfcbank.com OR '
      'hdfcbank.net OR '
      'netbanking.hdfcbank.com OR '
      'icicibank.com OR '
      'sbi.co.in OR '
      'axisbank.com OR '
      'kotak.com OR '
      'yesbank.in OR '
      'idbibank.com OR '
      'idbi.co.in OR '
      'hsbc.co.in OR '
      'sc.com OR '
      'canarabank.com) '
      '(debited OR credited OR transaction OR spent OR withdrawn OR '
      '"used for" OR "payment to" OR "fund transfer" OR added OR received OR '
      'NEFT OR IMPS OR RTGS OR UPI OR "debit alert" OR "credit alert")';

  static String _gmailDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')}';

  /// Builds the full query. With [day] set, scopes to that single calendar day
  /// (`after:<day> before:<day+1>`); otherwise the last 90 days.
  static String _buildQuery(DateTime? day) {
    if (day == null) return '$_baseQuery newer_than:90d in:anywhere';
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return '$_baseQuery after:${_gmailDate(start)} '
        'before:${_gmailDate(end)} in:anywhere';
  }

  /// Subjects to SKIP — OTP / security / failure notices share the same senders
  /// as transaction alerts but aren't transactions.
  static const List<String> _skipSubjectWords = [
    'otp',
    'one time password',
    'unsuccessful',
    'login',
    'new device',
    'password',
    'not done by you', // fraud-report prompts
  ];

  /// Words that mark a real transaction. Checked on the subject first, then the
  /// body as a fallback (some banks use vague subjects like "Account update").
  static const List<String> _keepWords = [
    'transaction',
    'debited',
    'credited',
    'transfer',
    'payment',
    'spent',
    'used for',
    'added',
    'received',
    'neft',
    'imps',
    'rtgs',
    'upi',
  ];

  /// Returns up to [_maxResults] bank emails, each as a map with `id`,
  /// `subject`, `body`, `date`. With [day] set, only that calendar day's emails
  /// are fetched; otherwise the last 90 days. Empty list on any error or if the
  /// Gmail scope isn't authorized.
  Future<List<Map<String, dynamic>>> fetchBankEmails({DateTime? day}) async {
    final query = _buildQuery(day);
    debugPrint('=== GMAIL FETCH START ===');
    debugPrint('Searching with query: $query');

    final headers = await _auth.getAuthHeaders();
    if (headers == null) {
      debugPrint('Auth headers NULL — Gmail scope not granted ❌');
      return [];
    }

    final client = _GmailAuthClient(headers);
    try {
      final api = gmail.GmailApi(client);
      final listResponse = await api.users.messages.list(
        'me',
        q: query,
        maxResults: _maxResults,
      );

      final messages = listResponse.messages ?? const [];
      debugPrint('Total emails found: ${messages.length}');

      final results = <Map<String, dynamic>>[];
      for (final ref in messages) {
        final id = ref.id;
        if (id == null) continue;
        final full = await api.users.messages.get('me', id, format: 'full');
        final subject = _header(full, 'Subject') ?? '';
        final body = _extractBody(full);
        debugPrint('Email subject: $subject');
        debugPrint(
            'Email body preview: ${body.substring(0, min(200, body.length))}');

        final subjectLower = subject.toLowerCase();
        // Skip OTP / security / failure notices.
        if (_skipSubjectWords.any(subjectLower.contains)) {
          debugPrint('Skipped (OTP/security): $subject');
          continue;
        }
        // Keep only transaction emails (subject, with body as a fallback).
        final bodyLower = body.toLowerCase();
        final looksTransactional = _keepWords.any(subjectLower.contains) ||
            _keepWords.any(bodyLower.contains);
        if (!looksTransactional) {
          debugPrint('Skipped (not a transaction): $subject');
          continue;
        }

        results.add({
          'id': id,
          'subject': subject,
          'body': body,
          'date': _header(full, 'Date') ?? '',
          'from': _header(full, 'From') ?? '', // sender → universal bank detect
          'internalDate': full.internalDate ?? '', // epoch ms (received time)
        });
      }
      return results;
    } catch (e) {
      debugPrint('Gmail fetch error: $e ❌');
      return [];
    } finally {
      client.close();
    }
  }

  /// Records [emailId] as processed (in Firestore) so it isn't imported twice.
  Future<void> markAsProcessed(String emailId) async {
    try {
      final col = _processedCol;
      if (col == null) return;
      await col.doc(emailId).set({'processedAt': FieldValue.serverTimestamp()});
    } catch (_) {
      // Ignore persistence failures.
    }
  }

  /// Clears the "processed" flag for [emailId] so it can be re-imported. Called
  /// when the transaction that came from this email is deleted — otherwise the
  /// email stays flagged forever and a deleted transaction can never come back.
  Future<void> clearProcessed(String emailId) async {
    try {
      final col = _processedCol;
      if (col == null || emailId.isEmpty) return;
      await col.doc(emailId).delete();
    } catch (_) {
      // Ignore — a stale flag only blocks a re-import, never breaks anything.
    }
  }

  /// True if [emailId] was already imported by this user.
  Future<bool> isAlreadyProcessed(String emailId) async {
    try {
      final col = _processedCol;
      if (col == null) return false;
      final doc = await col.doc(emailId).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  // ── Helpers ─────────────────────────────────────────────

  String? _header(gmail.Message msg, String name) {
    final headers = msg.payload?.headers;
    if (headers == null) return null;
    for (final h in headers) {
      if ((h.name ?? '').toLowerCase() == name.toLowerCase()) return h.value;
    }
    return null;
  }

  /// Prefers text/plain, falls back to text/html, then the snippet.
  String _extractBody(gmail.Message msg) {
    final payload = msg.payload;
    if (payload == null) return msg.snippet ?? '';
    return _findPart(payload, 'text/plain') ??
        _findPart(payload, 'text/html') ??
        msg.snippet ??
        '';
  }

  String? _findPart(gmail.MessagePart part, String mimeType) {
    if ((part.mimeType ?? '') == mimeType && part.body?.data != null) {
      return _decodeBody(part.body!.data!);
    }
    for (final child in part.parts ?? const <gmail.MessagePart>[]) {
      final found = _findPart(child, mimeType);
      if (found != null) return found;
    }
    return null;
  }

  String _decodeBody(String data) {
    try {
      // Gmail returns URL-safe base64.
      return utf8.decode(base64Url.decode(base64Url.normalize(data)));
    } catch (_) {
      return '';
    }
  }
}

/// http.Client that injects the Gmail auth headers on every request.
class _GmailAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _GmailAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

final gmailServiceProvider = Provider<GmailService>(
  (ref) => GmailService(
    ref.read(gmailAuthServiceProvider),
    ref.watch(firestoreProvider),
    ref.watch(currentUidProvider),
  ),
);
