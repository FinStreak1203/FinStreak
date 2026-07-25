import 'dart:io';
import 'package:another_telephony/telephony.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'email_parser_service.dart' show ParsedTransaction;
import 'sms_parser_service.dart';

/// Reads recent bank SMS from the device inbox (Android only) and parses them
/// into [ParsedTransaction]s. The real-time background listener is intentionally
/// not wired here yet — this is the on-demand import path.
class SmsService {
  final Telephony _telephony = Telephony.instance;
  final SmsParserService _parser = const SmsParserService();

  /// Requests the SMS permission. Always false off-Android.
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  /// Whether SMS access is already granted (async — the getter is a Future).
  Future<bool> isGranted() async {
    if (!Platform.isAndroid) return false;
    return Permission.sms.isGranted;
  }

  /// Bank SMS (filtered to known bank senders). With [day] set, only that
  /// calendar day's messages are read; otherwise the last 90 days.
  Future<List<SmsMessage>> fetchBankSMS({DateTime? day}) async {
    if (!Platform.isAndroid) return [];
    if (!await requestPermission()) return [];

    final SmsFilter dateFilter;
    if (day != null) {
      final start = DateTime(day.year, day.month, day.day);
      final end = start.add(const Duration(days: 1));
      dateFilter = SmsFilter.where(SmsColumn.DATE)
          .greaterThanOrEqualTo(start.millisecondsSinceEpoch.toString())
          .and(SmsColumn.DATE)
          .lessThan(end.millisecondsSinceEpoch.toString());
    } else {
      final since = DateTime.now()
          .subtract(const Duration(days: 90))
          .millisecondsSinceEpoch;
      dateFilter = SmsFilter.where(SmsColumn.DATE)
          .greaterThanOrEqualTo(since.toString());
    }

    final messages = await _telephony.getInboxSms(
      columns: [
        SmsColumn.ADDRESS,
        SmsColumn.BODY,
        SmsColumn.DATE,
        SmsColumn.ID,
      ],
      filter: dateFilter,
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );

    // ── DEBUG (debug builds only): every inbox sender, matched or not ──
    if (kDebugMode) {
      debugPrint('════ SMS INBOX (last 30 days): ${messages.length} msgs ════');
      for (final sms in messages) {
        final sender = sms.address ?? '';
        final isBank = _parser.isBankSMS(sender);
        debugPrint(
            'SMS from "$sender"  →  ${isBank ? "✅ ${_parser.getBankName(sender)}" : "❌ not a bank sender"}');
      }
      debugPrint('═════════════════════════════════════════════');
    }

    return messages
        .where((sms) => _parser.isBankSMS(sms.address ?? ''))
        .toList();
  }

  /// Parses every bank SMS found in the last 30 days.
  Future<List<ParsedTransaction>> parseAllBankSMS({DateTime? day}) async {
    final smsList = await fetchBankSMS(day: day);
    final results = <ParsedTransaction>[];
    for (final sms in smsList) {
      final sender = sms.address ?? '';
      final body = sms.body ?? '';
      final parsed = _parser.parseSMS(
        body: body,
        sender: sender,
        smsId: sms.id?.toString() ?? '',
        date: DateTime.fromMillisecondsSinceEpoch(sms.date ?? 0),
      );

      // ── DEBUG (debug builds only): every bank SMS, raw + parsed ──
      if (kDebugMode) {
        debugPrint('═══════════ BANK SMS ═══════════');
        debugPrint('Sender: $sender  (${_parser.getBankName(sender)})');
        debugPrint('Body  : $body');
        debugPrint('Parsed: ${parsed ?? "null (skipped / no amount)"}');
        debugPrint('════════════════════════════════');
      }

      if (parsed != null) results.add(parsed);
    }
    return results;
  }
}

final smsServiceProvider = Provider<SmsService>((ref) => SmsService());

/// Whether SMS access is currently granted (false off-Android). Invalidate to
/// refresh after returning from the import screen.
final smsPermissionProvider =
    FutureProvider<bool>((ref) => ref.read(smsServiceProvider).isGranted());
