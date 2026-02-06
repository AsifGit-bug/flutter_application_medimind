import 'package:flutter/foundation.dart';
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
      // sound: Uses default system alarm sound when not specified
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

  // ... (permissions and init code remains same) ...

  /// Schedule notifications for a Monitor/Caregiver for a specific patient
  Future<void> scheduleMonitorReminders(
    List<Medicine> patientMedicines,
    String patientName,
  ) async {
    // We group by time to avoid spamming the monitor
    // final Map<String, List<Medicine>> groupedByTime = {};

    for (var med in patientMedicines) {
      if (med.isDeleted) continue;
      // ... Logic to group medicines by time ...
      // Simplified for MVP: Schedule individually for now or group?
      // Let's reuse the similar grouping logic but with a different ID range
      // Monitor IDs will be offset by 1,000,000 to avoid collision with patient's own meds if they share a device (rare but possible)
    }

    // Actually, for Monitors, we probably want to just verify "Next Dose" logic
    // But since we want to alert them *when* the patient has to take it:

    // Iterate and schedule
    for (var med in patientMedicines) {
      // Reuse the same scheduling logic but with different body text
      await _scheduleForMonitor(med, patientName);
    }
  }

  Future<void> _scheduleForMonitor(
    Medicine medicine,
    String patientName,
  ) async {
    if (medicine.isDeleted) return;

    // Use a unique ID range for monitor notifications (offset by 500,000)
    // This allows a user to be both a patient and a monitor
    final int baseId = 500000 + medicine.id.hashCode;

    // Define notification details for Monitor (Standard importance, not Alarm)
    const NotificationDetails monitorDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'medimind_reminders', // Use standard channel
        'Medicine Reminders',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(''),
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );

    // ... Scheduling logic similar to scheduleMedicineNotifications ...
    // We will duplicate the logic briefly here to ensure it works correctly for the monitor context
    // In a full refactor, we would extract the core scheduling engine.

    final List<DateTime> scheduleTimes = medicine.scheduleTimes.isNotEmpty
        ? medicine.scheduleTimes
        : [medicine.time];

    // final prefs = await SharedPreferences.getInstance();
    // Check if monitor notifications are globally enabled
    // Note: The caller (MonitorDashboard) should check this, but good to double check or we can make this granular per patient later.
    // For now assuming caller checks global 'allowNotifications'.

    // Map day names to weekday numbers
    final Map<String, int> dayToWeekday = {
      'Monday': DateTime.monday,
      'Tuesday': DateTime.tuesday,
      'Wednesday': DateTime.wednesday,
      'Thursday': DateTime.thursday,
      'Friday': DateTime.friday,
      'Saturday': DateTime.saturday,
      'Sunday': DateTime.sunday,
    };

    final freq = medicine.frequency.toLowerCase();
    final bool isWeeklyOrSpecificDays =
        (freq == 'weekly' || freq == 'specific days') &&
        medicine.weeklyDays.isNotEmpty;

    for (int i = 0; i < scheduleTimes.length; i++) {
      final time = scheduleTimes[i];

      if (isWeeklyOrSpecificDays) {
        for (int d = 0; d < medicine.weeklyDays.length; d++) {
          final dayName = medicine.weeklyDays[d];
          final targetWeekday = dayToWeekday[dayName];
          if (targetWeekday == null) continue;

          final scheduledDate = _nextInstanceOfWeekdayTime(
            targetWeekday,
            time.hour,
            time.minute,
          );
          // Unique ID for monitor: Base + Index + DayOffset
          final int notificationId = baseId + (i * 10) + d;

          try {
            await _notifications.zonedSchedule(
              notificationId,
              'Reminder for $patientName',
              'Time for $patientName to take ${medicine.name} (${medicine.dosage})',
              scheduledDate,
              monitorDetails,
              androidScheduleMode: AndroidScheduleMode
                  .inexactAllowWhileIdle, // Monitor alerts don't need exact alarm permission usually
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
              payload: 'monitor|${medicine.id}|$patientName',
            );
          } catch (e) {
            debugPrint("Error scheduling monitor notification: $e");
          }
        }
      } else {
        // Daily / As Needed
        final scheduledDate = _nextInstanceOfTime(time.hour, time.minute);
        final int notificationId = baseId + i;

        try {
          await _notifications.zonedSchedule(
            notificationId,
            'Reminder for $patientName',
            'Time for $patientName to take ${medicine.name} (${medicine.dosage})',
            scheduledDate,
            monitorDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.time,
            payload: 'monitor|${medicine.id}|$patientName',
          );
        } catch (e) {
          debugPrint("Error scheduling monitor notification: $e");
        }
      }
    }
  }

  Future<void> _checkPermissions(
    AndroidFlutterLocalNotificationsPlugin? androidPlugin,
  ) async {
    // Request standard permissions (for Android 13+)
    final bool? notifGranted = await androidPlugin
        ?.requestNotificationsPermission();
    debugPrint(
      "[NotificationService] Notification permission granted: $notifGranted",
    );

    // Request Exact Alarms permission (for Android 12+)
    // This is required for 'exactAllowWhileIdle' scheduling.
    final bool? alarmGranted = await androidPlugin
        ?.requestExactAlarmsPermission();
    debugPrint(
      "[NotificationService] Exact alarm permission granted: $alarmGranted",
    );
  }

  /// Test method to verify notifications work - call this for debugging
  Future<void> sendTestNotification() async {
    debugPrint("[NotificationService] Sending test notification...");
    try {
      await _notifications.show(
        999999,
        '🧪 Test Notification',
        'If you see this, notifications are working!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'medimind_reminders',
            'Medicine Reminders',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
      debugPrint("[NotificationService] Test notification sent successfully!");
    } catch (e) {
      debugPrint("[NotificationService] Test notification FAILED: $e");
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

    // Determine if this is a weekly or specific days medicine
    final freq = medicine.frequency.toLowerCase();
    final bool isWeeklyOrSpecificDays =
        (freq == 'weekly' || freq == 'specific days') &&
        medicine.weeklyDays.isNotEmpty;

    // Map day names to weekday numbers (1 = Monday, 7 = Sunday)
    final Map<String, int> dayToWeekday = {
      'Monday': DateTime.monday,
      'Tuesday': DateTime.tuesday,
      'Wednesday': DateTime.wednesday,
      'Thursday': DateTime.thursday,
      'Friday': DateTime.friday,
      'Saturday': DateTime.saturday,
      'Sunday': DateTime.sunday,
    };

    for (int i = 0; i < scheduleTimes.length; i++) {
      final time = scheduleTimes[i];

      NotificationDetails details;

      if (useAlarm) {
        details = const NotificationDetails(
          android: AndroidNotificationDetails(
            'medimind_alarms',
            'Medicine Alarms',
            importance: Importance.max,
            priority: Priority.high,
            fullScreenIntent: true,
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

      if (isWeeklyOrSpecificDays) {
        // For weekly/specific days medicines, schedule for each selected day
        for (int d = 0; d < medicine.weeklyDays.length; d++) {
          final dayName = medicine.weeklyDays[d];
          final targetWeekday = dayToWeekday[dayName];
          if (targetWeekday == null) continue;

          final scheduledDate = _nextInstanceOfWeekdayTime(
            targetWeekday,
            time.hour,
            time.minute,
          );
          final int notificationId = medicine.id.hashCode + (i * 10) + d;

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
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
              payload: '${medicine.id}|$scheduledDate',
            );
          } catch (e) {
            await _notifications.zonedSchedule(
              notificationId,
              'Time for ${medicine.name}!',
              'Take ${medicine.dosage} (${medicine.type}) - ${medicine.instructions}',
              scheduledDate,
              details,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
              payload: '${medicine.id}|$scheduledDate',
            );
          }
        }
      } else {
        // Daily or As Needed - use daily time matching
        final scheduledDate = _nextInstanceOfTime(time.hour, time.minute);
        final int notificationId = medicine.id.hashCode + i;

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
            payload: '${medicine.id}|$scheduledDate',
          );
        } catch (e) {
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
            payload: '${medicine.id}|$scheduledDate',
          );
        }
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

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Schedules grouped notifications for all medicines.
  /// Medicines at the same time will be grouped into a single notification.
  Future<void> scheduleAllMedicineNotifications(
    List<Medicine> medicines,
  ) async {
    // Cancel all existing notifications first
    await _notifications.cancelAll();

    // Filter active medicines
    final activeMeds = medicines.where((m) => !m.isDeleted).toList();
    if (activeMeds.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final bool useAlarm = prefs.getBool(keyAlarmMode) ?? true;

    // Group medicines by time slot (hour:minute)
    // Key format: "HH:MM" for daily, "DAY-HH:MM" for weekly/specific days
    final Map<String, List<Medicine>> timeGroups = {};

    for (var medicine in activeMeds) {
      final freq = medicine.frequency.toLowerCase();
      final isWeeklyOrSpecificDays =
          (freq == 'weekly' || freq == 'specific days') &&
          medicine.weeklyDays.isNotEmpty;

      final scheduleTimes = medicine.scheduleTimes.isNotEmpty
          ? medicine.scheduleTimes
          : [medicine.time];

      for (var time in scheduleTimes) {
        if (isWeeklyOrSpecificDays) {
          // For weekly/specific days, group by day + time
          for (var day in medicine.weeklyDays) {
            final key =
                '$day-${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
            timeGroups.putIfAbsent(key, () => []).add(medicine);
          }
        } else if (freq != 'as needed') {
          // Daily medicines - group by time only
          final key =
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
          timeGroups.putIfAbsent(key, () => []).add(medicine);
        }
      }
    }

    // Map day names to weekday numbers
    final Map<String, int> dayToWeekday = {
      'Monday': DateTime.monday,
      'Tuesday': DateTime.tuesday,
      'Wednesday': DateTime.wednesday,
      'Thursday': DateTime.thursday,
      'Friday': DateTime.friday,
      'Saturday': DateTime.saturday,
      'Sunday': DateTime.sunday,
    };

    // Schedule one notification per time group
    for (var entry in timeGroups.entries) {
      final key = entry.key;
      final meds = entry.value;

      // Parse the key
      final isWeeklyKey = key.contains('-') && key.split('-').length >= 2;
      String dayName = '';
      int hour, minute;

      if (isWeeklyKey) {
        final parts = key.split('-');
        dayName = parts[0];
        final timeParts = parts[1].split(':');
        hour = int.parse(timeParts[0]);
        minute = int.parse(timeParts[1]);
      } else {
        final timeParts = key.split(':');
        hour = int.parse(timeParts[0]);
        minute = int.parse(timeParts[1]);
      }

      // Build notification content
      String title;
      String body;
      if (meds.length == 1) {
        title = 'Time for ${meds[0].name}!';
        body =
            'Take ${meds[0].dosage} (${meds[0].type}) - ${meds[0].instructions}';
      } else {
        title = 'Time for ${meds.length} medicines!';
        body = meds.map((m) => '• ${m.name} ${m.dosage}').join('\n');
      }

      // Create notification ID from time key hash
      final int notificationId = key.hashCode.abs() % 100000;

      // Determine scheduled date
      tz.TZDateTime scheduledDate;
      DateTimeComponents matchComponents;

      if (isWeeklyKey) {
        final targetWeekday = dayToWeekday[dayName];
        if (targetWeekday == null) continue;
        scheduledDate = _nextInstanceOfWeekdayTime(targetWeekday, hour, minute);
        matchComponents = DateTimeComponents.dayOfWeekAndTime;
      } else {
        scheduledDate = _nextInstanceOfTime(hour, minute);
        matchComponents = DateTimeComponents.time;
      }

      // Build notification details
      NotificationDetails details;
      if (useAlarm) {
        details = const NotificationDetails(
          android: AndroidNotificationDetails(
            'medimind_alarms',
            'Medicine Alarms',
            importance: Importance.max,
            priority: Priority.high,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
            styleInformation: BigTextStyleInformation(''),
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
            styleInformation: BigTextStyleInformation(''),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        );
      }

      // Schedule the grouped notification
      try {
        await _notifications.zonedSchedule(
          notificationId,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: matchComponents,
          payload: meds.map((m) => m.id).join(','),
        );
      } catch (e) {
        await _notifications.zonedSchedule(
          notificationId,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: matchComponents,
          payload: meds.map((m) => m.id).join(','),
        );
      }
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
    if (scheduledDate.isBefore(now.add(const Duration(seconds: 10)))) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Returns the next instance of a specific weekday at the given time.
  /// weekday: 1 = Monday, 7 = Sunday (following Dart's DateTime.weekday)
  tz.TZDateTime _nextInstanceOfWeekdayTime(int weekday, int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Find the next occurrence of the target weekday
    while (scheduledDate.weekday != weekday ||
        scheduledDate.isBefore(now.add(const Duration(seconds: 10)))) {
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
