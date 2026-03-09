import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // 1. Initialize Timezone Database
    tz.initializeTimeZones(); 
    tz.setLocalLocation(tz.getLocation('Africa/Cairo'));

    // 4. Android Settings
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // 5. iOS Settings
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notifications.initialize(settings);
    
    // 6. Request Permissions
    final platform = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await platform?.requestNotificationsPermission();
  }

  // --- MEDICATIONS SCHEDULER ---
  static Future<void> scheduleMedicationReminders(int medId, String medName, List<String> times) async {
    // Cancel old alarms
    for (int i = 0; i < 10; i++) {
      await _notifications.cancel(medId * 100 + i);
    }

    for (int i = 0; i < times.length; i++) {
      final parts = times[i].split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final notificationId = (medId * 100) + i; 

      final scheduledTime = _nextInstanceOfTime(hour, minute);

      await _notifications.zonedSchedule(
        notificationId,
        'Time for your Medication 💊',
        'Take $medName now',
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'med_channel_v2', 
            'Medications',
            channelDescription: 'Reminders to take medicine',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, 
      );
    }
  }

  // --- DAILY REMINDER ---
  static Future<void> scheduleDailyNotification(int hour, int minute) async {
    final scheduledTime = _nextInstanceOfTime(hour, minute);
    await _notifications.zonedSchedule(
      888,
      'Health Tracker 🩺',
      'Don\'t forget to log your blood pressure!',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_channel', 'Daily Reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelAll() async => await _notifications.cancelAll();
  
  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}