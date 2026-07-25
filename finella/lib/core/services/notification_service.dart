import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local-notification scheduling for the daily reconcile reminder.
///
/// Background note: mobile OSes don't reliably wake an app on a schedule, so
/// the reminder is a single-shot local notification re-scheduled whenever the
/// app is opened or a reconcile completes. That makes "skip if reconciled
/// today" exact. The streak-lapse check runs on app open, not in the OS
/// background.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  static const int _reconcileId = 1001;
  static const String _channelId = 'reconcile_reminders';
  static const String _channelName = 'Streak Reminders';
  static const int _reminderHour = 21; // 9 PM

  static const String _txnChannelId = 'transaction_alerts';
  static const String _txnChannelName = 'Transaction Alerts';

  /// Initializes the plugin + timezone database. Safe to call more than once.
  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      // Indian-locale app — default to IST. (Swap for device tz via
      // flutter_timezone later if multi-region support is needed.)
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: ios),
      );
      _ready = true;
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
    }
  }

  /// Requests OS notification permission (Android 13+ and iOS).
  Future<void> requestPermissions() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('NotificationService permission request failed: $e');
    }
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Daily reminder to reconcile your accounts',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  /// Schedules the next 9 PM reconcile reminder. When [reconciledToday] is
  /// true (or it's already past 9 PM), it targets tomorrow — so a reminder is
  /// never shown on a day the user has already reconciled.
  Future<void> scheduleDailyReconcileReminder({
    required bool reconciledToday,
  }) async {
    if (!_ready) await init();
    if (!_ready) return; // init failed (e.g. unsupported platform in tests)

    try {
      await _plugin.cancel(id: _reconcileId);

      final now = tz.TZDateTime.now(tz.local);
      var next = tz.TZDateTime(
          tz.local, now.year, now.month, now.day, _reminderHour);
      if (reconciledToday || !next.isAfter(now)) {
        next = next.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        id: _reconcileId,
        title: '🔥 Keep your streak alive!',
        body: "Don't forget to reconcile today's accounts",
        scheduledDate: next,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('NotificationService schedule failed: $e');
    }
  }

  /// Shows an immediate alert when a bank SMS is auto-captured into a
  /// transaction (from the real-time listener, foreground or background). A
  /// distinct [id] per call so several transactions stack instead of replacing
  /// one another.
  Future<void> showTransactionCaptured({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_ready) await init();
    if (!_ready) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _txnChannelId,
            _txnChannelName,
            channelDescription: 'Alerts when a bank SMS is captured',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('showTransactionCaptured failed: $e');
    }
  }

  /// Cancels any pending reconcile reminder.
  Future<void> cancelReconcileReminder() async {
    try {
      await _plugin.cancel(id: _reconcileId);
    } catch (_) {}
  }
}
