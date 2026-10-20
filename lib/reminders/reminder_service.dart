import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_plan.dart';

/// Device reminder seam. The app depends only on this interface.
abstract class ReminderService {
  /// False where the platform cannot show notifications (web, Linux,
  /// Windows). The choice is still stored; the UI shows no warnings.
  bool get supported => true;

  /// Ask the OS for permission. Returns true if reminders can be shown.
  Future<bool> requestPermission();

  /// Replace all queued reminders with a new batch for [frequency].
  Future<void> schedule(
    ReminderFrequency frequency, {
    required int streak,
    required int coins,
  });
}

/// Used on web, in tests and on unsupported platforms: stores nothing,
/// shows nothing, never throws.
class NoopReminderService implements ReminderService {
  const NoopReminderService();

  @override
  bool get supported => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> schedule(
    ReminderFrequency frequency, {
    required int streak,
    required int coins,
  }) async {}
}

/// Pick the right service for the current platform.
ReminderService platformReminderService() {
  if (kIsWeb) return const NoopReminderService();
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return LocalNotificationReminderService();
    default:
      return const NoopReminderService();
  }
}

/// On-device scheduled notifications (flutter_local_notifications).
///
/// Android uses inexact, idle-allowed alarms, so no SCHEDULE_EXACT_ALARM /
/// USE_EXACT_ALARM permission is needed (a reminder may arrive a few
/// minutes late, which is fine). Android 13+ asks for POST_NOTIFICATIONS.
class LocalNotificationReminderService implements ReminderService {
  LocalNotificationReminderService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  bool get supported => true;
  bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'quitcash_reminders',
      'Reminders',
      channelDescription: 'Streak and daily bonus reminders',
      importance: Importance.defaultImportance,
    ),
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
  );

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('QuitCash: timezone lookup failed, using UTC: $e');
    }
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: darwin,
        macOS: darwin,
      ),
    );
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    try {
      await _init();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      final mac = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      return await mac?.requestPermissions(alert: true, sound: true) ?? false;
    } catch (e) {
      debugPrint('QuitCash: permission request failed: $e');
      return false;
    }
  }

  @override
  Future<void> schedule(
    ReminderFrequency frequency, {
    required int streak,
    required int coins,
  }) async {
    try {
      await _init();
      await _plugin.cancelAll();
      final times = reminderTimes(DateTime.now(), frequency);
      for (var i = 0; i < times.length; i++) {
        final t = times[i];
        final copy = reminderCopy(i, streak: streak, coins: coins);
        await _plugin.zonedSchedule(
          id: 1000 + i,
          title: copy.title,
          body: copy.body,
          scheduledDate: tz.TZDateTime(
            tz.local,
            t.year,
            t.month,
            t.day,
            t.hour,
          ),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('QuitCash: scheduling reminders failed: $e');
    }
  }
}
