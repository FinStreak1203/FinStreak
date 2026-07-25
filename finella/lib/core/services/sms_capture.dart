import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:another_telephony/telephony.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'email_parser_service.dart' show ParsedTransaction;
import 'notification_service.dart';
import 'sms_parser_service.dart';
import 'transaction_importer.dart';

/// SharedPreferences key holding a queue of raw bank SMS captured by the
/// background isolate (JSON-encoded {sender, body, date}). The main isolate
/// drains it into Firestore on next open — cloud_firestore is unreliable from a
/// background isolate (no restored auth token + a persistence lock held by the
/// main isolate), so the background path deliberately never writes to it.
const String kSmsPendingKey = 'sms_pending_queue';

/// Top-level background handler — runs in its OWN isolate when a bank SMS
/// arrives while the app is backgrounded or killed. Must be top-level/static
/// and `@pragma('vm:entry-point')` so it survives tree-shaking.
@pragma('vm:entry-point')
Future<void> smsBackgroundHandler(SmsMessage message) async {
  await SmsCapture.captureInBackground(
    message.address,
    message.body,
    message.date,
  );
}

/// Parses incoming bank SMS. Foreground saves straight to Firestore; background
/// queues + notifies (the queue is drained on next app open). Self-contained
/// (no Riverpod) because the background isolate can't reach app providers.
class SmsCapture {
  static const SmsParserService _parser = SmsParserService();

  /// Background isolate: validate → enqueue for the main isolate → notify now.
  /// Never touches Firestore.
  static Future<void> captureInBackground(
      String? sender, String? body, int? dateMs) async {
    try {
      final parsed = _parse(sender, body, dateMs);
      if (parsed == null) return;

      // Register plugins for this isolate before using SharedPreferences /
      // notifications.
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();

      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(kSmsPendingKey) ?? <String>[];
      queue.add(jsonEncode({
        'sender': sender ?? '',
        'body': body ?? '',
        'date': dateMs ?? DateTime.now().millisecondsSinceEpoch,
      }));
      await prefs.setStringList(kSmsPendingKey, queue);
      debugPrint('SmsCapture(bg): queued ${parsed.type} ₹${parsed.amount}');

      await _notify(parsed);
    } catch (e) {
      debugPrint('SmsCapture.captureInBackground error: $e');
    }
  }

  /// Foreground (main isolate): save straight to Firestore + notify.
  static Future<void> captureForeground(
      TransactionImporter importer, SmsMessage message) async {
    try {
      final parsed = _parse(message.address, message.body, message.date);
      if (parsed == null) return;
      final saved = await importer.save(parsed);
      debugPrint('SmsCapture(fg): ${saved ? "saved" : "skipped (dup)"} '
          '${parsed.type} ₹${parsed.amount}');
      if (saved) await _notify(parsed);
    } catch (e) {
      debugPrint('SmsCapture.captureForeground error: $e');
    }
  }

  /// Main isolate on open/resume: drain any background-captured SMS into
  /// Firestore. Cleared up front; the importer's own dedup guards re-adds.
  static Future<void> drainQueue(TransactionImporter importer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(kSmsPendingKey) ?? const [];
      if (queue.isEmpty) return;
      await prefs.remove(kSmsPendingKey);
      debugPrint('SmsCapture: draining ${queue.length} queued SMS');
      for (final item in queue) {
        try {
          final m = jsonDecode(item) as Map<String, dynamic>;
          final parsed = _parse(
            (m['sender'] ?? '').toString(),
            (m['body'] ?? '').toString(),
            (m['date'] as num?)?.toInt(),
          );
          if (parsed != null) await importer.save(parsed);
        } catch (_) {
          // Skip a bad queue entry; the rest still drain.
        }
      }
    } catch (e) {
      debugPrint('SmsCapture.drainQueue error: $e');
    }
  }

  /// Shared parse+validate. Returns null for non-bank / non-transaction SMS.
  static ParsedTransaction? _parse(String? sender, String? body, int? dateMs) {
    if (!Platform.isAndroid) return null;
    final from = sender ?? '';
    final text = body ?? '';
    if (from.isEmpty || text.isEmpty) return null;
    if (!_parser.isBankSMS(from)) return null;
    final date = dateMs != null
        ? DateTime.fromMillisecondsSinceEpoch(dateMs)
        : DateTime.now();
    // Incoming SMS carry no row id — synthesise a stable dedup key.
    final smsId = 'rt_${from}_${date.millisecondsSinceEpoch}_${text.hashCode}';
    return _parser.parseSMS(body: text, sender: from, smsId: smsId, date: date);
  }

  static Future<void> _notify(ParsedTransaction t) async {
    final isIncome = t.type == 'income';
    final who = (t.merchant != null && t.merchant!.isNotEmpty)
        ? t.merchant!
        : t.bankName;
    final amount = '₹${t.amount.toStringAsFixed(0)}';
    final title = isIncome ? '$amount received' : '$amount spent';
    final body =
        isIncome ? 'From $who · ${t.bankName}' : 'To $who · ${t.bankName}';
    final id = 2000 + (t.upiRef ?? t.emailId).hashCode.abs() % 100000;
    await NotificationService.instance
        .showTransactionCaptured(id: id, title: title, body: body);
  }
}
