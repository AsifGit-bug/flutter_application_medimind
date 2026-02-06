import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/medicine_model.dart';
import 'add_medicine_page.dart';

import 'medicine_detail_page.dart';
import 'my_caregivers_page.dart';
import '../auth/welcome_page.dart';
import '../monitor/monitor_dashboard.dart';
import 'monitor_requests_page.dart';
import '../../theme/theme_manager.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../common/content_display_page.dart';
import '../common/report_bug_page.dart';
import '../../utils/translations.dart';
import '../../utils/medicine_icon_helper.dart';
import '../../services/notification_service.dart';
import '../common/notifications_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';

import '../../components/scale_on_press.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  int _selectedIndex = 0;

  // Services
  final AuthService _auth = AuthService();
  final DatabaseService _db = DatabaseService();
  late User _currentUser;

  // State
  List<Medicine> _medicines = [];
  String _userName = "Patient";
  String _userEmail = "";
  String _currentGreeting = "";

  final String _currentLanguage = 'en';

  // History Tab State
  StreamSubscription<List<Medicine>>? _medicinesSubscription;
  String _historyFilterStatus = "All"; // All, Taken, Skipped, Missed, Untracked
  String _medicineFilterStatus = "All"; // All, Daily, Weekly, As Needed
  bool _useAlarmMode = true; // Default to true

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser!;
    _fetchUserData();
    _loadSettings();
    _subscribeToMedicines();
    _saveLastDashboard();
    _initializeGreeting();
  }

  Future<void> _saveLastDashboard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_dashboard_role', 'patient');
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // ... (dispose and other methods) ...

  Widget _buildMedicinesTab(List<Medicine> medicines) {
    final theme = Theme.of(context);

    // Filter Groups logic
    List<Medicine> daily = [];
    List<Medicine> weekly = [];
    List<Medicine> specificDays = [];
    List<Medicine> asNeeded = [];
    List<Medicine> other = [];

    // 1. Group raw medicines
    for (var m in medicines) {
      final freq = m.frequency.toLowerCase();
      if (freq == 'specific days') {
        specificDays.add(m);
      } else if (freq == 'weekly') {
        weekly.add(m);
      } else if (freq == 'as needed') {
        asNeeded.add(m);
      } else if (freq.contains('daily') ||
          freq.contains('day') ||
          freq.contains('hours')) {
        daily.add(m);
      } else {
        other.add(m);
      }
    }

    // 2. Filter based on _medicineFilterStatus
    Widget content;
    if (_medicineFilterStatus == "All") {
      content = Column(
        children: [
          _buildMedicineGroup("Daily", daily),
          _buildMedicineGroup("Specific Days", specificDays),
          _buildMedicineGroup("Weekly", weekly),
          _buildMedicineGroup("As Needed", asNeeded, showTakeAction: true),
          _buildMedicineGroup("Other", other),
        ],
      );
    } else if (_medicineFilterStatus == "Daily") {
      // Combine Daily + Other (often 'Every X Hours' is grouped with daily mentally by users, or strictly Daily?)
      // Implementation plan said "Daily: Show only Daily/Twice/Thrice meds".
      // Let's stick to the grouping we defined above.
      content = daily.isEmpty
          ? _buildNoMedicinesFound("Daily")
          : _buildMedicineGroup("Daily", daily, hideTitle: true);
    } else if (_medicineFilterStatus == "Weekly") {
      content = weekly.isEmpty
          ? _buildNoMedicinesFound("Weekly")
          : _buildMedicineGroup("Weekly", weekly, hideTitle: true);
    } else if (_medicineFilterStatus == "Specific Days") {
      content = specificDays.isEmpty
          ? _buildNoMedicinesFound("Specific Days")
          : _buildMedicineGroup("Specific Days", specificDays, hideTitle: true);
    } else if (_medicineFilterStatus == "As Needed") {
      content = asNeeded.isEmpty
          ? _buildNoMedicinesFound("As Needed")
          : _buildMedicineGroup(
              "As Needed",
              asNeeded,
              showTakeAction: true,
              hideTitle: true,
            );
    } else {
      content = const SizedBox.shrink();
    }

    return Column(
      children: [
        // Teal Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
          decoration: BoxDecoration(
            color: theme.primaryColor,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    Translations.get('my_medicines', _currentLanguage),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSwitchDashboardIcon(color: Colors.white),
                      _buildThemeToggle(color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Content Area
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildMedicineFilterChips(theme),
                const SizedBox(height: 16),
                medicines.isEmpty
                    ? _buildNoMedicinesFound(_medicineFilterStatus)
                    : content,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicineFilterChips(ThemeData theme) {
    final filters = ["All", "Daily", "Specific Days", "Weekly", "As Needed"];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _medicineFilterStatus == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ScaleOnPress(
              onTap: () {
                setState(() {
                  _medicineFilterStatus = filter;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? theme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected
                        ? theme.primaryColor
                        : theme.dividerColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.9,
                          ),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  void dispose() {
    _medicinesSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToMedicines() {
    _medicinesSubscription = _db.getMedicines(_currentUser.uid).listen((
      medicines,
    ) async {
      if (mounted) {
        setState(() {
          _medicines = medicines;
          _sortMedicines();
        });
        // Schedule notifications when medicines are loaded/updated
        try {
          await NotificationService().scheduleAllMedicineNotifications(
            medicines,
          );
        } catch (e) {
          debugPrint("Error scheduling notifications: $e");
        }
      }
    });
  }

  Future<void> _fetchUserData() async {
    final data = await _db.getUserData(_currentUser.uid);
    if (mounted) {
      setState(() {
        _userName = data?['name'] ?? "Patient";
        _userEmail = _currentUser.email ?? "";
      });
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _useAlarmMode =
              prefs.getBool(NotificationService.keyAlarmMode) ?? true;
        });
      }
    } catch (e) {
      debugPrint("Error loading settings: $e");
    }
  }

  Future<void> _toggleAlarmMode(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(NotificationService.keyAlarmMode, value);
      setState(() {
        _useAlarmMode = value;
      });

      // Reschedule all medicines using grouped notifications
      final notificationService = NotificationService();
      await notificationService.scheduleAllMedicineNotifications(_medicines);
      final count = _medicines.where((m) => !m.isDeleted).length;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Alarm mode ${value ? 'enabled' : 'disabled'}. Updated $count medicines.",
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error saving setting: $e")));
      }
    }
  }

  void _navigateToAddMedicine() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMedicinePage(userId: _currentUser.uid),
      ),
    );
    // No manual update needed, stream handles it
  }

  void _navigateToDetail(Medicine medicine) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicineDetailPage(
          medicine: medicine,
          userId: _currentUser.uid,
          onDelete: () async {
            // Show confirmation dialog
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Delete Medicine"),
                content: Text(
                  "Are you sure you want to delete '${medicine.name}'?\n\nThis action can be undone from the Deleted tab.",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text("Cancel"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text("Delete"),
                  ),
                ],
              ),
            );

            if (confirmed != true) return;

            await _db.deleteMedicine(medicine.id);
            if (!mounted) return;
            Navigator.pop(context);
          },
          onUpdate: (updatedMedicine) {
            setState(() {
              final index = _medicines.indexWhere(
                (m) => m.id == updatedMedicine.id,
              );
              if (index != -1) {
                _medicines[index] = updatedMedicine;
                _sortMedicines();
              }
            });
          },
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  void _sortMedicines() {
    _medicines.sort((a, b) => a.time.compareTo(b.time));
  }

  // --- WIDGET BUILDERS ---

  void _initializeGreeting() {
    final List<String> greetings = [
      "Hello,",
      "Welcome back,",
      "Stay healthy,",
      "Have a great day,",
      "Hope you are well,",
    ];
    // Use microseconds only once during initialization
    _currentGreeting = greetings[DateTime.now().microsecond % greetings.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _buildCurrentTab(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.primaryColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: theme.primaryColor,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.white.withValues(alpha: 0.9),
          showUnselectedLabels: true,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_filled),
              label: Translations.get('home', _currentLanguage),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.medication),
              label: Translations.get('medicines', _currentLanguage),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.history),
              label: Translations.get('history', _currentLanguage),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings),
              label: Translations.get('settings', _currentLanguage),
            ),
          ],
        ),
      ),
      floatingActionButton: (_selectedIndex == 0 || _selectedIndex == 1)
          ? FloatingActionButton(
              onPressed: _navigateToAddMedicine,
              backgroundColor: theme.colorScheme.primary,
              child: Icon(Icons.add, color: theme.colorScheme.onPrimary),
            )
          : null,
    );
  }

  Widget _buildCurrentTab() {
    final activeMedicines = _medicines.where((m) => !m.isDeleted).toList();
    switch (_selectedIndex) {
      case 0:
        return _buildHomeTab(
          _medicines,
        ); // Pass ALL here to handle today's history for archived meds
      case 1:
        return _buildMedicinesTab(activeMedicines);
      case 2:
        return _buildHistoryTab(_medicines);
      case 3:
        return _buildSettingsTab();
      default:
        return _buildHomeTab(activeMedicines);
    }
  }

  Widget _buildThemeToggle({Color? color}) {
    final iconColor = color ?? Theme.of(context).iconTheme.color;
    return IconButton(
      icon: Icon(
        ThemeManager.themeNotifier.value == ThemeMode.dark
            ? Icons.light_mode
            : Icons.dark_mode,
        color: iconColor,
      ),
      onPressed: () {
        ThemeManager.toggleTheme();
        setState(() {});
      },
    );
  }

  Widget _buildSwitchDashboardIcon({Color? color}) {
    final iconColor = color ?? Theme.of(context).iconTheme.color;
    return IconButton(
      icon: Icon(Icons.swap_horiz, color: iconColor, size: 28),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Switch Dashboard"),
            content: const Text(
              "Are you sure you want to switch to Monitor Dashboard?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("No"),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('last_dashboard_role', 'monitor');
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MonitorDashboard(),
                      ),
                    );
                  }
                },
                child: const Text("Yes"),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsTab() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: theme.primaryColor.withValues(alpha: 0.85),
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSwitchDashboardIcon(color: Colors.white),
                        _buildThemeToggle(color: Colors.white),
                      ],
                    ),
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: theme.cardColor,
                      child: Text(
                        _userName.isNotEmpty ? _userName[0].toUpperCase() : 'P',
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _userEmail,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSettingsSectionHeader(
                  Translations.get('general', _currentLanguage),
                ),
                _buildSettingsTile(
                  Icons.person_outline,
                  Translations.get('personal_data', _currentLanguage),
                  _showProfileDetails,
                ),
                _buildSettingsTile(
                  Icons.group_outlined,
                  Translations.get('my_caregivers', _currentLanguage),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MyCaregiversPage(),
                      ),
                    );
                  },
                ),
                _buildSettingsTile(
                  Icons.people_outline,
                  Translations.get('monitor_requests', _currentLanguage),
                  () => _showMonitorRequests(),
                ),
                _buildSettingsTile(
                  Icons.notifications_none,
                  Translations.get('notifications', _currentLanguage),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            NotificationsPage(userId: _currentUser.uid),
                      ),
                    );
                  },
                ),
                SwitchListTile(
                  title: const Text("Use Alarm Mode"),
                  subtitle: const Text("Full-screen alerts for medicines"),
                  secondary: const Icon(Icons.alarm),
                  value: _useAlarmMode,
                  onChanged: _toggleAlarmMode,
                  activeThumbColor: theme.primaryColor,
                ),
                _buildSettingsTile(
                  Icons.archive_outlined,
                  "Archived Medicines",
                  _showArchivedMedicines,
                ),
                const SizedBox(height: 24),
                _buildSettingsSectionHeader(
                  Translations.get('support', _currentLanguage),
                ),
                _buildSettingsTile(
                  Icons.bug_report,
                  Translations.get('report_issue', _currentLanguage),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ReportBugPage(),
                      ),
                    );
                  },
                ),
                _buildSettingsTile(
                  Icons.info_outline,
                  Translations.get('about_us', _currentLanguage),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ContentDisplayPage(
                          title: "About Us",
                          contentKey: "aboutUs",
                        ),
                      ),
                    );
                  },
                ),
                _buildSettingsTile(
                  Icons.help_outline,
                  Translations.get('help_faq', _currentLanguage),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ContentDisplayPage(
                          title: "Help & FAQ",
                          contentKey: "faq",
                        ),
                      ),
                    );
                  },
                ),
                _buildSettingsTile(
                  Icons.privacy_tip_outlined,
                  Translations.get('privacy_policy', _currentLanguage),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ContentDisplayPage(
                          title: "Privacy Policy",
                          contentKey: "privacyPolicy",
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WelcomePage(),
                        ),
                        (route) => false,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(Translations.get('log_out', _currentLanguage)),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    "${Translations.get('app_version', _currentLanguage)} 1.0.0",
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium!.color,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- HISTORY TAB ---

  Widget _buildHistoryTab(List<Medicine> medicines) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Teal Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
          decoration: BoxDecoration(
            color: theme.primaryColor,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "History",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    _buildSwitchDashboardIcon(color: Colors.white),
                    _buildThemeToggle(color: Colors.white),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Content Area
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _buildTimelineView(),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineView() {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    List<Map<String, dynamic>> historyEvents = [];

    // Analyze last 7 days
    for (var med in _medicines) {
      // Determine all daily schedule times
      List<DateTime> dailySchedules = med.scheduleTimes.isNotEmpty
          ? med.scheduleTimes
          : [med.time];

      for (int i = 0; i < 7; i++) {
        final checkDate = today.subtract(Duration(days: i));

        // Check if taken on this day
        final takenDoses = med.doseHistory
            .where(
              (d) =>
                  d.year == checkDate.year &&
                  d.month == checkDate.month &&
                  d.day == checkDate.day,
            )
            .toList();
        takenDoses.sort();

        // Check if skipped on this day
        final skippedDoses = med.skipHistory
            .where(
              (d) =>
                  d.year == checkDate.year &&
                  d.month == checkDate.month &&
                  d.day == checkDate.day,
            )
            .toList();
        skippedDoses.sort();

        // Check if explicitly missed on this day
        final missedDoses = med.missedHistory
            .where(
              (d) =>
                  d.year == checkDate.year &&
                  d.month == checkDate.month &&
                  d.day == checkDate.day,
            )
            .toList();
        missedDoses.sort();

        int takenIndex = 0;
        int skippedIndex = 0;
        int missedIndex = 0;

        for (var sched in dailySchedules) {
          final scheduledDateTime = DateTime(
            checkDate.year,
            checkDate.month,
            checkDate.day,
            sched.hour,
            sched.minute,
          );

          // Fix: Check if scheduledTime is before createdAt date (ignore time)
          if (med.createdAt != null) {
            final createdDate = DateTime(
              med.createdAt!.year,
              med.createdAt!.month,
              med.createdAt!.day,
            );
            // If the checkDate (which is 00:00:00 of the day) is strictly before the createdDate (00:00:00 of creation day)
            if (checkDate.isBefore(createdDate)) {
              continue;
            }
          }

          bool matched = false;

          // Try to match with Taken first
          if (takenIndex < takenDoses.length) {
            historyEvents.add({
              'name': med.name,
              'frequency': med.frequency,
              'type': Translations.get(med.type, _currentLanguage),
              'time': takenDoses[takenIndex],
              'status': Translations.get('taken', _currentLanguage),
              'medicine': med,
            });
            takenIndex++;
            matched = true;
          }
          // Try to match with Skipped if not taken
          else if (skippedIndex < skippedDoses.length) {
            historyEvents.add({
              'name': med.name,
              'frequency': med.frequency,
              'type': Translations.get(med.type, _currentLanguage),
              'time': skippedDoses[skippedIndex],
              'status': 'Skipped',
              'medicine': med,
            });
            skippedIndex++;
            matched = true;
          }
          // Try to match with Explicitly Missed
          else if (missedIndex < missedDoses.length) {
            historyEvents.add({
              'name': med.name,
              'frequency': med.frequency,
              'type': Translations.get(med.type, _currentLanguage),
              'time': missedDoses[missedIndex],
              'status': Translations.get('Missed', _currentLanguage),
              'medicine': med,
              'isExplicit': true, // Explicit Missed -> Immutable
            });
            missedIndex++;
            matched = true;
          }

          // If not matched
          if (!matched) {
            // For archived medicines, count untracked doses as "Skipped"
            if (med.isDeleted) {
              historyEvents.add({
                'name': med.name,
                'frequency': med.frequency,
                'type': Translations.get(med.type, _currentLanguage),
                'time': scheduledDateTime,
                'status': 'Skipped', // Auto-skip for history
                'medicine': med,
              });
              continue;
            }

            // IF checkDate is TODAY
            if (checkDate.year == today.year &&
                checkDate.month == today.month &&
                checkDate.day == today.day) {
              // If time passed, it's Missed
              if (scheduledDateTime.isBefore(now)) {
                historyEvents.add({
                  'name': med.name,
                  'frequency': med.frequency,
                  'type': Translations.get(med.type, _currentLanguage),
                  'time': scheduledDateTime,
                  'status': Translations.get('Missed', _currentLanguage),
                  'medicine': med,
                  'isExplicit':
                      false, // Implicit Missed (Overdue) -> Interactive
                });
              }
            } else {
              // IF checkDate is YESTERDAY or BEFORE (Past)
              // And we have no record, it is "Unknown" / "No Track"
              historyEvents.add({
                'name': med.name,
                'frequency': med.frequency,
                'type': Translations.get(med.type, _currentLanguage),
                'time': scheduledDateTime,
                'status': 'No Track',
                'medicine': med,
              });
            }
          }
        }

        // Add any "Extra" taken/skipped doses that exceeded the schedule count
        while (takenIndex < takenDoses.length) {
          historyEvents.add({
            'name': med.name,
            'frequency': med.frequency,
            'type': Translations.get(med.type, _currentLanguage),
            'time': takenDoses[takenIndex],
            'status': Translations.get('taken', _currentLanguage),
            'medicine': med,
          });
          takenIndex++;
        }
        while (skippedIndex < skippedDoses.length) {
          historyEvents.add({
            'name': med.name,
            'frequency': med.frequency,
            'type': Translations.get(med.type, _currentLanguage),
            'time': skippedDoses[skippedIndex],
            'status': 'Skipped',
            'medicine': med,
          });
          skippedIndex++;
        }
      }
    }

    // Sort by time descending (newest first)
    historyEvents.sort((a, b) => b['time'].compareTo(a['time']));

    // Filter events
    if (_historyFilterStatus != "All") {
      historyEvents = historyEvents.where((event) {
        final status = event['status'];
        if (_historyFilterStatus == "Taken") {
          return status == "Taken" ||
              status == Translations.get('taken', _currentLanguage);
        } else if (_historyFilterStatus == "Skipped") {
          return status == "Skipped";
        } else if (_historyFilterStatus == "Missed") {
          return status == "Missed" ||
              status == Translations.get('Missed', _currentLanguage);
        } else if (_historyFilterStatus == "Untracked") {
          return status == "No Track" || status == "Untracked";
        }
        return true;
      }).toList();
    }

    if (historyEvents.isEmpty) {
      return Column(
        children: [
          _buildHistoryFilterChips(theme),
          const SizedBox(height: 32),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: theme.disabledColor.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No ${_historyFilterStatus == 'All' ? '' : _historyFilterStatus.toLowerCase()} history found.",
                    style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Group by day
    Map<DateTime, List<Map<String, dynamic>>> groupedEvents = {};
    for (var event in historyEvents) {
      final date = DateTime(
        event['time'].year,
        event['time'].month,
        event['time'].day,
      );
      if (!groupedEvents.containsKey(date)) {
        groupedEvents[date] = [];
      }
      groupedEvents[date]!.add(event);
    }

    final sortedDates = groupedEvents.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        _buildHistoryFilterChips(theme),
        const SizedBox(height: 16),
        ...sortedDates.map((date) {
          final events = groupedEvents[date]!;
          // Explicitly sort to ensure latest first
          events.sort((a, b) => b['time'].compareTo(a['time']));

          final isToday =
              date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;
          final isYesterday =
              date.year == today.year &&
              date.month == today.month &&
              date.day == today.subtract(const Duration(days: 1)).day;

          String dateHeader;
          if (isToday) {
            dateHeader = "Today";
          } else if (isYesterday) {
            dateHeader = "Yesterday";
          } else {
            dateHeader = DateFormat('EEEE, MMM d').format(date);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 4,
                ),
                child: Text(
                  dateHeader,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
              ),
              ...events.map((event) {
                Color statusColor;
                if (event['status'] ==
                        Translations.get('taken', _currentLanguage) ||
                    event['status'] == 'Taken') {
                  statusColor = Colors.green;
                } else if (event['status'] == 'Skipped') {
                  statusColor = Colors.amber;
                } else if (event['status'] == 'No Track') {
                  statusColor = Colors.grey;
                } else {
                  statusColor = Colors.red;
                }

                return _buildTimelineItem(
                  event['medicine'] as Medicine? ??
                      _medicines.firstWhere((m) => m.name == event['name']),
                  event['name'],
                  "${event['frequency']} • ${event['type']}",
                  event['time'] as DateTime,
                  statusColor,
                  event['status'],
                );
              }),
              const SizedBox(height: 8),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildHistoryFilterChips(ThemeData theme) {
    final filters = ["All", "Taken", "Skipped", "Missed", "Untracked"];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _historyFilterStatus == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _historyFilterStatus = filter;
                  });
                }
              },
              backgroundColor: theme.cardColor,
              selectedColor: theme.primaryColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected
                    ? theme.primaryColor
                    : theme.textTheme.bodyMedium?.color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? theme.primaryColor : theme.dividerColor,
                ),
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimelineItem(
    Medicine med,
    String name,
    String details,
    DateTime time,
    Color color,
    String status,
  ) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday =
        time.year == today.year &&
        time.month == today.month &&
        time.day == today.day;

    // Allow interaction only if status is "Missed" AND it is NOT explicit (i.e. it is Implicit/Overdue)
    // AND it is TODAY (retroactive only allowed for today per previous logic/implied constraint)
    bool isInteractive =
        isToday &&
        (status == Translations.get('Missed', _currentLanguage) ||
            status == 'Missed') &&
        !(color == Colors.red &&
            (details.contains('Implicit') ==
                false)); // Hacky check? No, let's use the explicit flag passed in timeline item

    // BETTER APPROACH: timeline event map has 'isExplicit'.
    // But _buildTimelineItem signature needs update or we check the medicine object?
    // Medicine object doesn't tell us WHICH dose this event is for easily.
    // So let's rely on the fact that we can pass `isInteractive` to specific rows?
    // Current signature: _buildTimelineItem(Medicine, Name, Details, Time, Color, Status)

    // Actually, I can just check if the time exists in missedHistory!
    bool isExplicitMissed = med.missedHistory.any(
      (d) =>
          d.year == time.year &&
          d.month == time.month &&
          d.day == time.day &&
          d.hour == time.hour &&
          d.minute == time.minute, // Check exact time match?
      // Note: scheduled time vs actual time. Explicit Missed stores scheduled time usually?
      // markAsMissed stores the time passed to it.
    );

    // If it is in missedHistory, it is Explicit -> Not Interactive.
    if (isExplicitMissed) isInteractive = false;

    return InkWell(
      onTap: isInteractive
          ? () => _showRetroactiveActionDialog(med, time)
          : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: isInteractive
              ? Border.all(color: Colors.red.withValues(alpha: 0.5), width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_getStatusIcon(status), color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    details,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isToday
                      ? DateFormat('h:mm a').format(time)
                      : DateFormat('MMM d, h:mm a').format(time),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                // Show "Tap to Fix" for interactive items
                isInteractive
                    ? Text(
                        "Tap to Fix",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )
                    : Text(
                        status,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRetroactiveActionDialog(Medicine med, DateTime time) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Update Dose Status"),
        content: Text(
          "You missed the scheduled time for ${med.name} at ${DateFormat('h:mm a').format(time)}. What did you do?",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _db.skipDose(med.id, time);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.amber),
            child: const Text("Skipped it"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _db.logDose(med.id, time);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text("Took it"),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    if (status == Translations.get('taken', _currentLanguage) ||
        status == 'Taken') {
      return Icons.check_circle;
    } else if (status == 'Skipped') {
      return Icons.remove_circle_outline;
    } else if (status == 'No Track') {
      return Icons.help_outline; // Icon for No Track
    } else {
      return Icons.error_outline; // Missed
    }
  }

  // --- HOME & MEDICINE TABS ---

  Widget _buildHomeTab(List<Medicine> medicines) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Stack(
        children: [
          // Background Header
          // Background Header with Glassmorphism
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: 150,
                color: theme.primaryColor.withValues(alpha: 0.85),
              ),
            ),
          ),

          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Content (Transparent background, sits on top of blue)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _showProfileDetails,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.white,
                              child: Text(
                                _userName.isNotEmpty
                                    ? _userName[0].toUpperCase()
                                    : 'P',
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _currentGreeting,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  Text(
                                    _userName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSwitchDashboardIcon(color: Colors.white),
                          IconButton(
                            icon: const Icon(
                              Icons.notifications,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NotificationsPage(
                                    userId: _currentUser.uid,
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildThemeToggle(color: Colors.white),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Daily Schedule Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildDailySchedule(),
              ),

              // Rest of the content
              // Extra space at bottom
              const SizedBox(height: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailySchedule() {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    List<Map<String, dynamic>> pendingEvents = [];
    List<Map<String, dynamic>> completedEvents = [];

    for (var med in _medicines) {
      List<DateTime> schedules = med.scheduleTimes.isNotEmpty
          ? med.scheduleTimes
          : [med.time];

      // Get today's history
      final dosesToday =
          med.doseHistory.where((d) => isSameDay(d, today)).toList()..sort();
      final skippedToday =
          med.skipHistory.where((d) => isSameDay(d, today)).toList()..sort();
      final missedToday =
          med.missedHistory.where((d) => isSameDay(d, today)).toList()..sort();

      // Special handling for "As Needed" / PRN
      if (med.frequency == 'As Needed') {
        for (var date in dosesToday) {
          completedEvents.add({
            'medicine': med,
            'time': date,
            'status': 'Taken',
            'isImmutable': true,
          });
        }
        for (var date in skippedToday) {
          completedEvents.add({
            'medicine': med,
            'time': date,
            'status': 'Skipped',
            'isImmutable': true,
          });
        }
        continue;
      }

      // Special handling for "Weekly" or "Specific Days"
      if (med.frequency == 'Weekly' || med.frequency == 'Specific Days') {
        if (med.weeklyDays.isEmpty) continue;
        final todayDayName = _getDayName(now.weekday);
        // Only show if today is in the selected days
        bool isScheduledForToday = med.weeklyDays.any(
          (day) => day.startsWith(todayDayName.substring(0, 3)),
        );
        // Check full name comparison too just in case of format differences
        if (!isScheduledForToday) {
          isScheduledForToday = med.weeklyDays.contains(todayDayName);
        }

        if (!isScheduledForToday) continue;
      }

      int takenIndex = 0;
      int skippedIndex = 0;
      int missedIndex = 0;

      for (int i = 0; i < schedules.length; i++) {
        final sched = schedules[i];
        final scheduledTime = DateTime(
          today.year,
          today.month,
          today.day,
          sched.hour,
          sched.minute,
        );

        String status = "Untracked";
        bool isImmutable = false;
        DateTime displayTime = scheduledTime;

        if (takenIndex < dosesToday.length) {
          status = "Taken";
          isImmutable = true;
          displayTime = dosesToday[takenIndex];
          takenIndex++;
        } else if (skippedIndex < skippedToday.length) {
          status = "Skipped";
          isImmutable = true;
          displayTime = skippedToday[skippedIndex];
          skippedIndex++;
        } else if (missedIndex < missedToday.length) {
          status = "Missed";
          isImmutable = true;
          displayTime = missedToday[missedIndex];
          missedIndex++;
        }

        if (med.isDeleted) continue;

        final event = {
          'medicine': med,
          'time': displayTime,
          'status': status,
          'isImmutable': isImmutable,
        };

        if (status == "Untracked") {
          pendingEvents.add(event);
        } else {
          completedEvents.add(event);
        }
      }
    }

    // Sort both lists
    pendingEvents.sort(
      (a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime),
    );
    completedEvents.sort(
      (a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime),
    ); // Completed in reverse time (newest first)

    if (pendingEvents.isEmpty && completedEvents.isEmpty) {
      return _buildAllCaughtUpCard();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pendingEvents.isNotEmpty) ...[
          _buildSectionHeader(
            Translations.get('pending_actions', _currentLanguage),
            Icons.pending_actions,
            theme.primaryColor,
          ),
          const SizedBox(height: 12),
          ...pendingEvents.map((e) => _buildEventCard(e)),
          const SizedBox(height: 24),
        ],
        if (completedEvents.isNotEmpty) ...[
          _buildSectionHeader(
            Translations.get('activity_today', _currentLanguage),
            Icons.history,
            theme.primaryColor,
          ),
          const SizedBox(height: 12),
          ...completedEvents.map((e) => _buildEventCard(e)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: theme.textTheme.bodyLarge?.color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllCaughtUpCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24, top: 4),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark
            ? theme.primaryColor.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: isDark ? 0.2 : 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.medication_outlined,
              size: 40,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            Translations.get('no_meds_added_title', _currentLanguage),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.primaryColor,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            Translations.get('no_meds_added_desc', _currentLanguage),
            style: TextStyle(
              fontSize: 13,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Removed old _buildSectionHeader as it's integrated into ExpansionTile title

  Widget _buildEventCard(Map<String, dynamic> event) {
    final Medicine med = event['medicine'];
    final DateTime time = event['time'];
    String status = event['status'];
    // final bool isImmutable = event['isImmutable']; // Unused
    final theme = Theme.of(context);
    final now = DateTime.now();

    // Determine "Overdue" / Warning State for Untracked items
    bool isOverdue = false;
    if (status == 'Untracked' &&
        time.isBefore(now) &&
        !isSameDay(time, now.add(const Duration(days: 1)))) {
      // Logic: If scheduled time is in past AND it is today (or past days which we only show today's schedule usually)
      // Actually dailyEvents creates events for "Today". So check if time < now.
      isOverdue = true;
    }

    // Status Colors
    Color statusColor;
    // IconData statusIcon; // Unused
    switch (status) {
      case 'Taken':
        statusColor = Colors.green;
        break;
      case 'Skipped':
        statusColor = Colors.amber;
        break;
      case 'Missed':
        statusColor = Colors.red;
        break;
      default: // Untracked
        statusColor = isOverdue ? Colors.orange : theme.primaryColor;
    }

    return ScaleOnPress(
      onTap: () {
        if (status == 'Untracked') {
          _showUntrackedOptions(med, time);
        } else {
          _showHistorySheet(med);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: getMedicineIconWidget(med.type, size: 48),
              ),
              const SizedBox(width: 16),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      med.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (time.year == DateTime.now().year &&
                              time.month == DateTime.now().month &&
                              time.day == DateTime.now().day)
                          ? "${Translations.get(med.type, _currentLanguage)} • ${DateFormat('h:mm a').format(time)}"
                          : "${Translations.get(med.type, _currentLanguage)} • ${DateFormat('MMM d, h:mm a').format(time)}",
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                    // Show weekly days if it's a weekly medicine
                    if (med.frequency == 'Weekly' &&
                        med.weeklyDays.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        med.weeklyDays
                            .map((day) => day.substring(0, 3))
                            .join(', '),
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Status/Action Button
              if (status == 'Untracked')
                if (isOverdue)
                  // Warning Sign for Overdue
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.orange, width: 2),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 28,
                    ),
                  )
                else
                  // Normal Empty Circle
                  InkWell(
                    onTap: () => _showUntrackedOptions(med, time),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.primaryColor, width: 3),
                      ),
                    ),
                  )
              else if (status == 'Taken')
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 28),
                )
              else if (status == 'Skipped')
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey, width: 2),
                  ),
                  child: const Icon(
                    Icons.block, // Or remove_circle_outline
                    color: Colors.grey,
                    size: 24,
                  ),
                )
              else
                // Missed
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red, width: 2),
                  ),
                  child: const Icon(
                    Icons.priority_high,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistorySheet(Medicine med) {
    // 1. Merge and Filter History (Last 7 Days)
    List<Map<String, dynamic>> allEvents = [];
    final now = DateTime.now();
    final cutoffDate = now.subtract(const Duration(days: 7));
    bool isRecent(DateTime d) => d.isAfter(cutoffDate);

    for (var date in med.doseHistory) {
      if (isRecent(date)) {
        allEvents.add({'time': date, 'status': 'Taken', 'color': Colors.green});
      }
    }
    for (var date in med.skipHistory) {
      if (isRecent(date)) {
        allEvents.add({
          'time': date,
          'status': 'Skipped',
          'color': Colors.amber,
        });
      }
    }
    for (var date in med.missedHistory) {
      if (isRecent(date)) {
        allEvents.add({'time': date, 'status': 'Missed', 'color': Colors.red});
      }
    }

    allEvents.sort((a, b) => b['time'].compareTo(a['time']));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow fuller height
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return Column(
              children: [
                // Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      getMedicineIconWidget(med.type, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              med.name,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              Translations.get(
                                'Last 7 Days History',
                                _currentLanguage,
                              ),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: allEvents.isEmpty
                      ? Center(
                          child: Text(
                            Translations.get(
                              'No recent history',
                              _currentLanguage,
                            ),
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        )
                      : ListView.separated(
                          controller: controller,
                          itemCount: allEvents.length,
                          separatorBuilder: (_, __) =>
                              const Divider(indent: 72),
                          itemBuilder: (context, index) {
                            final event = allEvents[index];
                            final time = event['time'] as DateTime;
                            final status = event['status'] as String;
                            final color = event['color'] as Color;
                            return ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  status == 'Taken'
                                      ? Icons.check
                                      : status == 'Skipped'
                                      ? Icons.block
                                      : Icons.priority_high,
                                  color: color,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                Translations.get(status, _currentLanguage),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                DateFormat('EEEE, MMM d').format(time),
                              ),
                              trailing: Text(
                                DateFormat('h:mm a').format(time),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.bodyMedium?.color,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // New Action Sheet for "Untracked" items
  void _showUntrackedOptions(Medicine med, DateTime scheduledTime) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${Translations.get('Update Status for', _currentLanguage)} ${med.name}",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "${Translations.get('Scheduled', _currentLanguage)}: ${DateFormat('h:mm a').format(scheduledTime)}",
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // Taken Options
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(Translations.get('Taken Now', _currentLanguage)),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  await _db.logDose(med.id, DateTime.now());
                  messenger.clearSnackBars();
                  messenger.showSnackBar(
                    SnackBar(content: Text("Logged ${med.name} now")),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.history, color: Colors.green),
                title: Text(
                  Translations.get('Taken (Select Time)', _currentLanguage),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showTakeDialog(
                    med,
                    scheduledTime,
                  ); // Re-use existing which has time picker logic
                },
              ),
              const Divider(),
              // Skip/Missed Options
              ListTile(
                leading: const Icon(Icons.remove_circle, color: Colors.amber),
                title: Text(
                  Translations.get('Skipped (Intentional)', _currentLanguage),
                ),
                subtitle: Text(
                  Translations.get(
                    'Doctor advised or not needed',
                    _currentLanguage,
                  ),
                ),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  await _db.skipDose(med.id, scheduledTime);
                  messenger.clearSnackBars();
                  messenger.showSnackBar(
                    SnackBar(content: Text("${med.name} marked as skipped")),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.error, color: Colors.red),
                title: Text(
                  Translations.get('Missed (Forgot)', _currentLanguage),
                ),
                subtitle: Text(
                  Translations.get('Did not take it', _currentLanguage),
                ),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  await _db.markAsMissed(med.id, scheduledTime);
                  messenger.clearSnackBars();
                  messenger.showSnackBar(
                    SnackBar(content: Text("${med.name} marked as missed")),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoMedicinesFound(String filter) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Illustration container
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.primaryColor.withValues(alpha: 0.2),
                    theme.primaryColor.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                filter == "All"
                    ? Icons.medication_outlined
                    : Icons.search_off_rounded,
                size: 64,
                color: theme.primaryColor.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              filter == "All"
                  ? Translations.get('No medicines yet', _currentLanguage)
                  : "${Translations.get('No FILTER medicines', _currentLanguage).replaceAll('{type}', filter)}",
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              filter == "All"
                  ? Translations.get('Tap + to add', _currentLanguage)
                  : Translations.get('Try different filter', _currentLanguage),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.7,
                ),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineGroup(
    String title,
    List<Medicine> medicines, {
    bool showTakeAction = false,
    bool hideTitle = false,
  }) {
    if (medicines.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hideTitle)
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 24, left: 4),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.headlineSmall?.color,
              ),
            ),
          ),
        ...medicines.map(
          (m) => _buildMedicineCard(m, showTakeAction: showTakeAction),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildMedicineCard(Medicine medicine, {bool showTakeAction = false}) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => _navigateToDetail(medicine),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            // Minimalist Icon
            getMedicineIconWidget(medicine.type, size: 24),
            const SizedBox(width: 16),

            // Text Section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    medicine.type,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.9,
                      ),
                    ),
                  ),
                  if (medicine.frequency == 'Weekly' &&
                      medicine.weeklyDays.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      medicine.weeklyDays
                          .map((d) => d.substring(0, 3))
                          .join(', '),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Minimalist Action/Time
            if (showTakeAction)
              TextButton(
                onPressed: () {
                  _db.logDose(medicine.id, DateTime.now());
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${Translations.get('Took', _currentLanguage)} ${medicine.name}',
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: theme.primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  Translations.get('Take', _currentLanguage),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              )
            else
              Text(
                DateFormat('hh:mm a').format(medicine.time),
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.8,
                  ),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: theme.textTheme.bodyMedium!.color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, VoidCallback onTap) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: theme.primaryColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: theme.textTheme.bodyLarge!.color,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: theme.textTheme.bodyMedium!.color,
      ),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
    );
  }

  void _showProfileDetails() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Stack to prevent clipping
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Gradient Background
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.primaryColor,
                          theme.primaryColor.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                    ),
                  ),
                  // Handle
                  Positioned(
                    top: 12,
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Avatar with Border
                  Positioned(
                    bottom: -45,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 45,
                        backgroundColor: theme.primaryColor,
                        child: Text(
                          _userName.isNotEmpty
                              ? _userName[0].toUpperCase()
                              : 'P',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 60),

              // User Info
              Text(
                _userName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _userEmail,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(indent: 30, endIndent: 30),

              // Details List
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  children: [
                    _buildProfileInfoTile(
                      Icons.badge_outlined,
                      "Account Type",
                      "Patient Profile",
                    ),
                    _buildProfileInfoTile(
                      Icons.translate_outlined,
                      "Language",
                      _currentLanguage == 'en' ? 'English (US)' : 'Bangla (BN)',
                    ),
                    _buildProfileInfoTile(
                      Icons.verified_user_outlined,
                      "Security Status",
                      "Standard Protection",
                    ),
                  ],
                ),
              ),

              // Actions with Safe Area Padding
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  0,
                  24,
                  MediaQuery.of(context).padding.bottom + 24,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        label: const Text("Edit Name"),
                        onPressed: () {
                          Navigator.pop(context);
                          _showEditNameDialog();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: theme.primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text("Close"),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileInfoTile(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.primaryColor, size: 22),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog() {
    final TextEditingController nameController = TextEditingController(
      text: _userName,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(Translations.get('edit_name', _currentLanguage)),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: Translations.get('patient_name', _currentLanguage),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(Translations.get('cancel', _currentLanguage)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                await _db.updateUserName(_currentUser.uid, newName);
                if (context.mounted) {
                  setState(() => _userName = newName);
                  Navigator.pop(context); // Close dialog
                  // Re-open details to show updated info (optional, but nice)
                  _showProfileDetails();
                }
              }
            },
            child: Text(Translations.get('save', _currentLanguage)),
          ),
        ],
      ),
    );
  }

  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }

  void _showMonitorRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MonitorRequestsPage(userId: _currentUser.uid),
      ),
    );
  }

  void _showArchivedMedicines() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StreamBuilder<List<Medicine>>(
        stream: _db.getMedicines(_currentUser.uid),
        builder: (context, snapshot) {
          final archived = (snapshot.data ?? _medicines)
              .where((m) => m.isDeleted)
              .toList();
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Archived Medicines",
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  "These medicines are hidden from your active list but their history is preserved. You can delete them permanently here.",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: archived.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.archive_outlined,
                                size: 64,
                                color: Colors.grey.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "No archived medicines found",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: archived.length,
                          itemBuilder: (context, index) {
                            final med = archived[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                                leading: Icon(
                                  Icons.medical_services,
                                  color: theme.primaryColor,
                                ),
                                title: Text(
                                  med.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text("${med.dosage} • ${med.type}"),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Restore Button
                                    IconButton(
                                      icon: const Icon(
                                        Icons.settings_backup_restore,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () async {
                                        final nav = Navigator.of(context);
                                        med.isDeleted = false;
                                        await _db.updateMedicine(
                                          med,
                                          _currentUser.uid,
                                        );
                                        nav.pop();
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                "${med.name} restored!",
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    // Permanent Delete Button
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_forever,
                                        color: Colors.red,
                                      ),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text(
                                              "Delete Permanently?",
                                            ),
                                            content: const Text(
                                              "This will erase ALL dose history for this medicine. This action cannot be undone.",
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text("Cancel"),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text(
                                                  "Delete Forever",
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          final nav = Navigator.of(context);
                                          await _db.hardDeleteMedicine(med.id);
                                          nav.pop();
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  "Medicine deleted permanently",
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showTakeDialog(Medicine med, DateTime scheduledTime) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text("Take ${med.name}"),
        content: const Text("When did you take this dose?"),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final messenger = ScaffoldMessenger.of(context);
              final localizations = MaterialLocalizations.of(context);

              // Select Time
              final TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );

              if (!mounted) return;

              if (picked != null) {
                final now = DateTime.now();
                final pickedTime = DateTime(
                  scheduledTime.year,
                  scheduledTime.month,
                  scheduledTime.day,
                  picked.hour,
                  picked.minute,
                );

                if (pickedTime.isAfter(now)) {
                  messenger.clearSnackBars();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text("Cannot log a dose in the future!"),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final formattedTime = localizations.formatTimeOfDay(picked);
                await _db.logDose(med.id, pickedTime); // Log ACTUAL time

                if (mounted) {
                  messenger.clearSnackBars();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text("Logged ${med.name} at $formattedTime"),
                    ),
                  );
                }
              }
            },
            child: const Text("Select Time"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final messenger = ScaffoldMessenger.of(context);
              await _db.logDose(med.id, DateTime.now()); // Log NOW

              if (mounted) {
                messenger.clearSnackBars();
                messenger.showSnackBar(
                  SnackBar(content: Text("Logged ${med.name} now")),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text("Now"),
          ),
        ],
      ),
    );
  }
}
