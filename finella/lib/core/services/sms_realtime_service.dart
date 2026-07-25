import 'dart:io';
import 'package:another_telephony/telephony.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'sms_capture.dart';
import 'transaction_importer.dart';

/// Real-time bank-SMS listener (Android only).
///
/// Registers one [Telephony.listenIncomingSms] with a foreground handler and a
/// top-level background handler, so bank SMS are captured whether the app is
/// open, backgrounded, or killed. Foreground SMS save straight to Firestore;
/// background SMS are queued by [smsBackgroundHandler] and drained here on
/// start/resume (see [drainPending]).
///
/// Requires the `IncomingSmsReceiver` in AndroidManifest.xml and SMS permission
/// (first granted on the import screen).
class SmsRealtimeService {
  final TransactionImporter _importer;
  final Telephony _telephony = Telephony.instance;
  bool _listening = false;

  SmsRealtimeService(this._importer);

  /// Starts the listener and drains anything captured while the app was closed.
  /// Idempotent; no-op off-Android or without permission.
  Future<void> start() async {
    await drainPending(); // pick up SMS captured before this launch
    if (_listening) return;
    if (!Platform.isAndroid) return;
    if (!await Permission.sms.isGranted) {
      debugPrint('SmsRealtimeService: SMS permission not granted — not listening');
      return;
    }

    _telephony.listenIncomingSms(
      onNewMessage: (m) => SmsCapture.captureForeground(_importer, m),
      onBackgroundMessage: smsBackgroundHandler,
      listenInBackground: true,
    );
    _listening = true;
    debugPrint('SmsRealtimeService: listening (foreground + background)');
  }

  /// Saves any background-captured SMS sitting in the queue. Safe to call
  /// repeatedly (e.g. on every app resume).
  Future<void> drainPending() => SmsCapture.drainQueue(_importer);
}

final smsRealtimeServiceProvider = Provider<SmsRealtimeService>(
  (ref) => SmsRealtimeService(ref.watch(transactionImporterProvider)),
);
