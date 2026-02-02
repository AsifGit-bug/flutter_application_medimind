import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medicine_model.dart';
import 'database_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String keyAlarmMode = 'alarm_mode';
  static const String keyAllowNotifications = 'allow_notifications';

  Future<void> init() async {
    tz_data.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    final AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // 1. Alarm Channel (High Priority, Sound, FullScreen)
    final AndroidNotificationChannel alarmChannel = AndroidNotificationChannel(
      'medimind_alarms',
      'Medicine Alarms',
      description: 'High-priority alerts with alarm sound.',
      importance: Importance.max,
      playSound: true,
      enableLights: true,
      enableVibration: true,
      sound: const RawResourceAndroidNotificationSound(
        'alarm_sound',
      ), // Optional: Add custom sound later
    );

    // 2. Normal Channel (Standard Priority)
    final AndroidNotificationChannel normalChannel = AndroidNotificationChannel(
      'medimind_reminders',
      'Medicine Reminders',
      description: 'Standard notifications for reminders.',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(alarmChannel);
    await androidPlugin?.createNotificationChannel(normalChannel);

    // Check/Request Permissions
    await _checkPermissions(androidPlugin);
  }

  Future<void> _checkPermissions(
    AndroidFlutterLocalNotificationsPlugin? androidPlugin,
  ) async {
    // Request standard permissions (for Android 13+)
    await androidPlugin?.requestNotificationsPermission();

    // Request Exact Alarms permission (for Android 12+)
    // This is required for 'exactAllowWhileIdle' scheduling.
    final bool? granted = await androidPlugin?.requestExactAlarmsPermission();
    if (granted == false) {
      // Consider showing a dialog to the user explaining why this is needed,
      // but for now, we just proceed. The scheduler will check 'canScheduleExactAlarms'.
    }
  }

  Future<void> scheduleMedicineNotifications(Medicine medicine) async {
    // Cancel existing notifications for this medicine first
    await cancelNotificationsForMedicine(medicine.id);

    if (medicine.isDeleted) return;

    final scheduleTimes = medicine.scheduleTimes.isNotEmpty
        ? medicine.scheduleTimes
        : [medicine.time];

    final prefs = await SharedPreferences.getInstance();
    final bool useAlarm = prefs.getBool(keyAlarmMode) ?? true;

    for (int i = 0; i < scheduleTimes.length; i++) {
      final time = scheduleTimes[i];
      final scheduledDate = _nextInstanceOfTime(time.hour, time.minute);
      final int notificationId = medicine.id.hashCode + i;

      NotificationDetails details;

      if (useAlarm) {
        details = const NotificationDetails(
          android: AndroidNotificationDetails(
            'medimind_alarms',
            'Medicine Alarms',
            importance: Importance.max,
            priority: Priority.high,
            fullScreenIntent: true, // Only this makes it "Alarm" style
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
            actions: [
              AndroidNotificationAction(
                'TAKE',
                'Take',
                showsUserInterface: true,
              ),
              AndroidNotificationAction(
                'SNOOZE',
                'Snooze (10m)',
                showsUserInterface: false,
              ),
            ],
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.critical,
          ),
        );
      } else {
        details = const NotificationDetails(
          android: AndroidNotificationDetails(
            'medimind_reminders',
            'Medicine Reminders',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
            actions: [
              AndroidNotificationAction(
                'TAKE',
                'Take',
                showsUserInterface: true,
              ),
              AndroidNotificationAction(
                'SNOOZE',
                'Snooze (10m)',
                showsUserInterface: false,
              ),
            ],
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        );
      }

      try {
        await _notifications.zonedSchedule(
          notificationId,
          'Time for ${medicine.name}!',
          'Take ${medicine.dosage} (${medicine.type}) - ${medicine.instructions}',
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload:
              '${medicine.id}|$scheduledDate', // Pass data for action handling
        );
      } catch (e) {
        // Fallback to inexact if permission denied or other error
        await _notifications.zonedSchedule(
          notificationId,
          'Time for ${medicine.name}!',
          'Take ${medicine.dosage} (${medicine.type}) - ${medicine.instructions}',
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload:
              '${medicine.id}|$scheduledDate', // Pass data for action handling
        );
      }
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bool allow = prefs.getBool(keyAllowNotifications) ?? true;
    if (!allow) return;

    await _notifications.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medimind_reminders',
          'MediMind Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  Future<void> cancelNotificationsForMedicine(String medicineId) async {
    // We used (medicine.id.hashCode + i) as ID.
    // Usually medicines have 1-5 doses. To be safe, let's cancel 10 slots.
    for (int i = 0; i < 10; i++) {
      await _notifications.cancel(medicineId.hashCode + i);
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  // --- Action Handling ---

  static Future<void> _onNotificationResponse(
    NotificationResponse details,
  ) async {
    // Handle standard tap (Body click) -> Just Open App
    if (details.notificationResponseType ==
        NotificationResponseType.selectedNotification) {
      // Application opens automatically. We can log here if needed.
      return;
    }

    if (details.actionId == 'TAKE') {
      // Logic to Log Dose
      // Since this runs in main isolate (foreground), we can call DB
      if (details.payload != null) {
        final parts = details.payload!.split('|');
        if (parts.length == 2) {
          final medId = parts[0];
          // We can log "Now"
          await DatabaseService().logDose(medId, DateTime.now());
        }
      }
    } else if (details.actionId == 'SNOOZE') {
      // Snooze logic (Reschedule for +10 mins)
      final NotificationService service = NotificationService();
      await service._notifications.zonedSchedule(
        details.id! + 99999, // Unique ID offset
        'Snoozed: ${details.notificationResponseType == NotificationResponseType.selectedNotification ? "Medicine" : "Reminder"}',
        'Reminder snoozed for 10 minutes.', // Simplified for now
        tz.TZDateTime.now(tz.local).add(const Duration(minutes: 10)),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'medimind_reminders',
            'Snoozed Reminders',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode:
            AndroidScheduleMode.inexactAllowWhileIdle, // Safer for snooze
      );
    }
  }

  @pragma('vm:entry-point')
  static void notificationTapBackground(
    NotificationResponse notificationResponse,
  ) {
    // Handle background actions if needed (requires dispatching to isolate)
  }
}
