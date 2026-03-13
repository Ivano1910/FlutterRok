import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationsService {
  NotificationsService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Zagreb'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(initSettings);

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      final notifPerm = await android?.requestNotificationsPermission();
      final exactPerm = await android?.requestExactAlarmsPermission();

      if (kDebugMode) {
        print('notifications permission: $notifPerm');
        print('exact alarm permission: $exactPerm');
      }
    }

    _initialized = true;
  }

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'booking_reminders',
      'Booking reminders',
      channelDescription: 'Reminders before appointments',
      importance: Importance.max,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static Future<void> debugNotification() async {
    if (!_initialized) await init();

    await _plugin.show(
      111111,
      'TEST ✅',
      'Ako ovo vidiš, notifikacije rade.',
      _details,
    );
  }

  static int _id24h(int bookingId) => bookingId * 10 + 1;
  static int _id1h(int bookingId) => bookingId * 10 + 2;

  static Future<void> scheduleBookingReminders({
    required int bookingId,
    required DateTime bookingStartLocal,
    required String titleName,
  }) async {
    if (!_initialized) await init();

    final now = DateTime.now();

    if (bookingStartLocal.isBefore(now)) {
      if (kDebugMode) {
        print('Booking is in the past, not scheduling notifications.');
      }
      return;
    }

    // TESTING MODE:
    // Keep these short while debugging
    final when24h = now.add(const Duration(seconds: 15));
    final when1h = now.add(const Duration(seconds: 30));

    if (kDebugMode) {
      print('Now: $now');
      print('Booking start: $bookingStartLocal');
      print('Scheduling 24h test reminder for: $when24h');
      print('Scheduling 1h test reminder for: $when1h');
    }

    await cancelBookingReminders(bookingId);

    if (when24h.isAfter(now)) {
      await _plugin.zonedSchedule(
        _id24h(bookingId),
        'Podsjetnik (24h)',
        'Termin: $titleName • ${_fmt(bookingStartLocal)}',
        tz.TZDateTime.from(when24h, tz.local),
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    if (when1h.isAfter(now)) {
      await _plugin.zonedSchedule(
        _id1h(bookingId),
        'Podsjetnik (1h)',
        'Termin: $titleName • ${_fmt(bookingStartLocal)}',
        tz.TZDateTime.from(when1h, tz.local),
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    final pending = await _plugin.pendingNotificationRequests();
    if (kDebugMode) {
      print('Pending notifications count: ${pending.length}');
      for (final p in pending) {
        print('Pending id=${p.id}, title=${p.title}, body=${p.body}');
      }
    }
  }

  static Future<void> cancelBookingReminders(int bookingId) async {
    if (!_initialized) await init();
    await _plugin.cancel(_id24h(bookingId));
    await _plugin.cancel(_id1h(bookingId));
  }

  static Future<void> showRemoteNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'booking_reminders',
        'Booking reminders',
        channelDescription: 'Reminders before appointments',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

  await _plugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    details,
  );
}

  static String _fmt(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yy = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$dd-$mm-$yy $hh:$mi';
  }
}