import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/medicine_model.dart';
import 'add_medicine_page.dart';

import 'medicine_detail_page.dart';
import 'my_caregivers_page.dart';
import '../auth/login_page.dart';
import '../monitor/monitor_dashboard.dart';
import '../../theme/theme_manager.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../common/content_display_page.dart';
import '../common/report_bug_page.dart';
import '../../utils/translations.dart';

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

  String _currentLanguage = 'en';

  // History Tab State
  StreamSubscription<List<Medicine>>? _medicinesSubscription;
  String _historyFilterStatus = "All"; // All, Taken, Skipped, Missed, Untracked
  String _medicineFilterStatus = "All"; // All, Daily, Weekly, As Needed

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser!;
    _fetchUserData();

    _subscribeToMedicines();
  }

  // ... (dispose and other methods) ...

  Widget _buildMedicinesTab(List<Medicine> medicines) {
    final theme = Theme.of(context);

    // Filter Groups logic
    List<Medicine> daily = [];
    List<Medicine> weekly = [];
    List<Medicine> asNeeded = [];
    List<Medicine> other = [];

    // 1. Group raw medicines
    for (var m in medicines) {
      final freq = m.frequency.toLowerCase();
      if (freq == 'weekly') {
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

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  Translations.get('my_medicines', _currentLanguage),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge!.color,
                  ),
                ),
                Row(
                  children: [
                    _buildSwitchDashboardIcon(
                      color: theme.textTheme.bodyLarge!.color,
                    ),
                    _buildThemeToggle(color: theme.textTheme.bodyLarge!.color),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 20),
            child: _buildMedicineFilterChips(theme),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: medicines.isEmpty ? _buildEmptyState() : content,
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineFilterChips(ThemeData theme) {
    final filters = ["All", "Daily", "Weekly", "As Needed"];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _medicineFilterStatus == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _medicineFilterStatus = filter;
                  });
                }
              },
              backgroundColor: theme.cardColor,
              selectedColor: theme.primaryColor.withValues(alpha: 0.2),
              side: BorderSide(
                color: isSelected ? theme.primaryColor : theme.dividerColor,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? theme.primaryColor : theme.dividerColor,
                ),
              ),
              labelStyle: TextStyle(
                color: isSelected
                    ? theme.primaryColor
                    : theme.textTheme.bodyMedium?.color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNoMedicinesFound(String filter) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(
              Icons.medication_outlined,
              size: 64,
              color: theme.disabledColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              "No $filter medicines found.",
              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
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
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ...medicines.map(
          (m) => _buildMedicineCard(m, showTakeAction: showTakeAction),
        ),
        const SizedBox(height: 12),
      ],
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
    ) {
      if (mounted) {
        setState(() {
          _medicines = medicines;
          _sortMedicines();
        });
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

  void _navigateToAddMedicine() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMedicinePage(
          userId: _currentUser.uid,
          currentLanguage: _currentLanguage,
        ),
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
            setState(() {
              _medicines.removeWhere((m) => m.id == medicine.id);
            });
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

  String _getGreeting() {
    final List<String> greetings = [
      "Hello,",
      "Welcome back,",
      "Stay healthy,",
      "Have a great day,",
      "Hope you are well,",
    ];
    // Use a simple hash of the day to keep it consistent for the day? Or random every reload?
    // Random every reload is fine.
    return greetings[DateTime.now().microsecond % greetings.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _buildCurrentTab(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
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
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: theme.cardColor,
          selectedItemColor: theme.primaryColor,
          unselectedItemColor: theme.textTheme.bodyMedium!.color,
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
      floatingActionButton: _selectedIndex == 0 || _selectedIndex == 1
          ? FloatingActionButton(
              onPressed: _navigateToAddMedicine,
              backgroundColor: theme.colorScheme.primary,
              child: Icon(Icons.add, color: theme.colorScheme.onPrimary),
            )
          : null,
    );
  }

  Widget _buildCurrentTab() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeTab(_medicines);
      case 1:
        return _buildMedicinesTab(_medicines);
      case 2:
        return _buildHistoryTab(_medicines);
      case 3:
        return _buildSettingsTab();
      default:
        return _buildHomeTab(_medicines);
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
      icon: Icon(Icons.swap_horiz, color: iconColor),
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
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MonitorDashboard(),
                    ),
                  );
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
          Container(
            color: theme.primaryColor,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
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
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
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
                  () {},
                ),
                _buildSettingsTile(
                  Icons.language,
                  Translations.get('language', _currentLanguage),
                  _showLanguageDialog,
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
                          builder: (context) => const LoginPage(),
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
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "History",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge!.color,
                  ),
                ),
                Row(
                  children: [
                    _buildSwitchDashboardIcon(
                      color: theme.textTheme.bodyLarge!.color,
                    ),
                    _buildThemeToggle(color: theme.textTheme.bodyLarge!.color),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildTimelineView(),
          ],
        ),
      ),
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
              'dosage': med.dosage,
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
              'dosage': med.dosage,
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
              'dosage': med.dosage,
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
            // IF checkDate is TODAY
            if (checkDate.year == today.year &&
                checkDate.month == today.month &&
                checkDate.day == today.day) {
              // If time passed, it's Missed
              if (scheduledDateTime.isBefore(now)) {
                historyEvents.add({
                  'name': med.name,
                  'dosage': med.dosage,
                  'type': Translations.get(med.type, _currentLanguage),
                  'time': scheduledDateTime,
                  'status': Translations.get('Missed', _currentLanguage),
                  'isExplicit':
                      false, // Implicit Missed (Overdue) -> Interactive
                });
              }
            } else {
              // IF checkDate is YESTERDAY or BEFORE (Past)
              // And we have no record, it is "Unknown" / "No Track"
              historyEvents.add({
                'name': med.name,
                'dosage': med.dosage,
                'type': Translations.get(med.type, _currentLanguage),
                'time': scheduledDateTime,
                'status': 'No Track',
              });
            }
          }
        }

        // Add any "Extra" taken/skipped doses that exceeded the schedule count
        while (takenIndex < takenDoses.length) {
          historyEvents.add({
            'name': med.name,
            'dosage': med.dosage,
            'type': Translations.get(med.type, _currentLanguage),
            'time': takenDoses[takenIndex],
            'status': Translations.get('taken', _currentLanguage),
          });
          takenIndex++;
        }
        while (skippedIndex < skippedDoses.length) {
          historyEvents.add({
            'name': med.name,
            'dosage': med.dosage,
            'type': Translations.get(med.type, _currentLanguage),
            'time': skippedDoses[skippedIndex],
            'status': 'Skipped',
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

    return Column(
      children: [
        _buildHistoryFilterChips(theme),
        const SizedBox(height: 16),
        ...historyEvents.map((event) {
          Color statusColor;
          if (event['status'] == Translations.get('taken', _currentLanguage) ||
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
            "${event['dosage']} • ${event['type']}",
            event['time'] as DateTime,
            statusColor,
            event['status'],
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
                  DateFormat('h:mm a').format(time),
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
          Container(
            height: 220, // Adjusted for perfect 50/50 overlap
            decoration: BoxDecoration(
              color: theme.primaryColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
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
                    GestureDetector(
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                // Random greeting or based on time
                                _getGreeting(),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
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

              const SizedBox(height: 20),

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
    List<Map<String, dynamic>> dailyEvents = [];

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
      // They don't track against a schedule. Only show if acted upon.
      if (med.frequency == 'As Needed') {
        // Add Taken events
        for (var date in dosesToday) {
          dailyEvents.add({
            'medicine': med,
            'time': date,
            'status': 'Taken',
            'isImmutable': true,
          });
        }
        // Add Skipped events (rare for PRN but possible)
        for (var date in skippedToday) {
          dailyEvents.add({
            'medicine': med,
            'time': date,
            'status': 'Skipped',
            'isImmutable': true,
          });
        }

        continue; // Skip the standard schedule loop
      }

      // Special handling for "Weekly" - only show on selected days
      if (med.frequency == 'Weekly') {
        if (med.weeklyDays.isEmpty) {
          print('DEBUG: ${med.name} has empty weeklyDays, skipping');
          continue; // No days selected, skip this medicine
        }
        // Get today's day name (e.g., "Monday", "Tuesday")
        final todayDayName = _getDayName(now.weekday);
        print(
          'DEBUG: ${med.name} Weekly check - Today: $todayDayName, Scheduled: ${med.weeklyDays}',
        );
        if (!med.weeklyDays.contains(todayDayName)) {
          print('DEBUG: ${med.name} not scheduled for today, skipping');
          continue; // Not scheduled for today, skip
        }
        print('DEBUG: ${med.name} IS scheduled for today!');
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

        String status = "Untracked"; // Default to Untracked (Pending)
        bool isImmutable = false;

        // Sequential Matching
        if (takenIndex < dosesToday.length) {
          status = "Taken";
          isImmutable = true;
          takenIndex++;
        } else if (skippedIndex < skippedToday.length) {
          status = "Skipped";
          isImmutable = true;
          skippedIndex++;
        } else if (missedIndex < missedToday.length) {
          status = "Missed"; // Explicitly Missed
          isImmutable = true;
          missedIndex++;
        } else {
          // Standard untracked logic
        }

        dailyEvents.add({
          'medicine': med,
          'time': scheduledTime,
          'status': status,
          'isImmutable': isImmutable,
        });
      }
    }

    // Sort by time
    dailyEvents.sort(
      (a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime),
    );

    // Group by status
    final untracked = dailyEvents
        .where((e) => e['status'] == 'Untracked')
        .toList();
    final taken = dailyEvents.where((e) => e['status'] == 'Taken').toList();
    final skipped = dailyEvents.where((e) => e['status'] == 'Skipped').toList();
    final missed = dailyEvents.where((e) => e['status'] == 'Missed').toList();

    return Column(
      children: [
        if (untracked.isNotEmpty)
          _buildSection(
            "Upcoming",
            untracked,
            theme.primaryColor,
            Icons.radio_button_unchecked,
            isExpanded: true,
          )
        else
          _buildAllCaughtUpCard(),

        // History Sections
        _buildSection("Taken", taken, Colors.green, Icons.check_circle),
        _buildSection(
          "Skipped",
          skipped,
          Colors.amber,
          Icons.remove_circle_outline,
        ),
        _buildSection("Missed", missed, Colors.red, Icons.error_outline),
      ],
    );
  }

  Widget _buildAllCaughtUpCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24, top: 8),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              size: 48,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "No medicines left for today!",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    String title,
    List<Map<String, dynamic>> events,
    Color color,
    IconData icon, {
    bool isExpanded = false,
  }) {
    if (events.isEmpty) return const SizedBox.shrink();

    final count = events.length;
    final headerTitle = "$title ($count)";

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: isExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        iconColor: color,
        collapsedIconColor: color.withValues(alpha: 0.7),
        title: Row(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(width: 12),
            Text(
              headerTitle.toUpperCase(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(height: 1, color: color.withValues(alpha: 0.1)),
            ),
          ],
        ),
        children: events.map((event) => _buildEventCard(event)).toList(),
      ),
    );
  }

  // Removed old _buildSectionHeader as it's integrated into ExpansionTile title

  Widget _buildEventCard(Map<String, dynamic> event) {
    final Medicine med = event['medicine'];
    final DateTime time = event['time'];
    final String status = event['status'];
    final bool isImmutable = event['isImmutable'];
    final theme = Theme.of(context);

    // Status Colors/Icons
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'Taken':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'Skipped':
        statusColor = Colors.amber;
        statusIcon = Icons.remove_circle_outline;
        break;
      case 'Missed':
        statusColor = Colors.red;
        statusIcon = Icons.error_outline;
        break;
      default: // Untracked
        statusColor = Colors.grey;
        statusIcon = Icons.radio_button_unchecked;
    }

    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: status == 'Untracked'
              ? () => _showUntrackedOptions(med, time)
              : null,
          borderRadius: BorderRadius.circular(24),
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
                  child: Icon(
                    _getMedicineIcon(med.type),
                    color: statusColor,
                    size: 24,
                  ),
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
                      Row(
                        children: [
                          Text(
                            "${med.type} • ${med.dosage} • ${DateFormat('h:mm a').format(time)}",
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withValues(alpha: 0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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

                // Status/Action
                if (isImmutable)
                  Icon(statusIcon, color: statusColor, size: 28)
                else
                  Container(
                    width: 36,
                    height: 36,
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
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getMedicineIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pill':
      case 'tablet':
      case 'capsule':
        return Icons.medication;
      case 'syrup':
      case 'liquid':
        return Icons.local_drink;
      case 'injection':
      case 'syringe':
        return Icons.vaccines;
      case 'inhaler':
        return Icons.air;
      case 'drops':
        return Icons.water_drop;
      case 'cream':
      case 'ointment':
        return Icons.healing;
      default:
        return Icons.medication_liquid;
    }
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
                "Update Status for ${med.name}",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Scheduled: ${DateFormat('h:mm a').format(scheduledTime)}",
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // Taken Options
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text("Taken Now"),
                onTap: () {
                  Navigator.pop(context);
                  _db.logDose(med.id, DateTime.now());
                },
              ),
              ListTile(
                leading: const Icon(Icons.history, color: Colors.green),
                title: const Text("Taken (Select Time)"),
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
                title: const Text("Skipped (Intentional)"),
                subtitle: const Text("Doctor advised or not needed"),
                onTap: () {
                  Navigator.pop(context);
                  _db.skipDose(med.id, scheduledTime);
                },
              ),
              ListTile(
                leading: const Icon(Icons.error, color: Colors.red),
                title: const Text("Missed (Forgot)"),
                subtitle: const Text("Did not take it"),
                onTap: () {
                  Navigator.pop(context);
                  _db.markAsMissed(med.id, scheduledTime);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medication_outlined,
            size: 64,
            color: theme.textTheme.bodyMedium!.color,
          ),
          const SizedBox(height: 16),
          Text(
            Translations.get('no_medicines', _currentLanguage),
            style: TextStyle(
              color: theme.textTheme.bodyMedium!.color,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.medical_services, color: theme.primaryColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge!.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${medicine.type} • ${medicine.dosage}",
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textTheme.bodyMedium!.color?.withValues(
                        alpha: 0.7,
                      ),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Translations.get(medicine.frequency, _currentLanguage),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodyMedium!.color?.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                  // Show weekly days if it's a weekly medicine
                  if (medicine.frequency == 'Weekly' &&
                      medicine.weeklyDays.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      medicine.weeklyDays
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
            if (showTakeAction)
              ElevatedButton(
                onPressed: () {
                  _db.logDose(medicine.id, DateTime.now());
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Took ${medicine.name}'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: const Text("Take"),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  DateFormat('hh:mm a').format(medicine.time),
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
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
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Name",
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _userName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_outlined, size: 18),
                    color: theme.primaryColor,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      Navigator.pop(context);
                      _showEditNameDialog();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Email
              Text(
                "Email",
                style: TextStyle(
                  fontSize: 11,
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _userEmail,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 20),

              // Close Button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    Translations.get('close', _currentLanguage).toUpperCase(),
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Translations.get('monitor_requests', _currentLanguage),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _db.getPendingRequests(_currentUser.uid),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final requests = snapshot.data ?? [];
                    if (requests.isEmpty) {
                      return Center(
                        child: Text(
                          Translations.get(
                            'no_pending_requests',
                            _currentLanguage,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final req = requests[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                            title: Text(
                              req['monitorEmail'] ?? 'Unknown Monitor',
                            ),
                            subtitle: const Text(
                              "Wants to view your medicine data",
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.check,
                                    color: Colors.green,
                                  ),
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    final navigator = Navigator.of(context);
                                    await _db.acceptRequest(
                                      req['id'],
                                      req['monitorId'],
                                      _currentUser.uid,
                                    );
                                    if (context.mounted) {
                                      navigator.pop();
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            Translations.get(
                                              'request_accepted',
                                              _currentLanguage,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    final navigator = Navigator.of(context);
                                    await _db.declineRequest(req['id']);
                                    if (context.mounted) {
                                      navigator.pop();
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            Translations.get(
                                              'request_declined',
                                              _currentLanguage,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(Translations.get('select_language', _currentLanguage)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(Translations.get('english', _currentLanguage)),
              onTap: () {
                setState(() => _currentLanguage = 'en');
                Navigator.pop(context);
              },
              trailing: _currentLanguage == 'en'
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
            ),
            ListTile(
              title: Text(Translations.get('bangla', _currentLanguage)),
              onTap: () {
                setState(() => _currentLanguage = 'bn');
                Navigator.pop(context);
              },
              trailing: _currentLanguage == 'bn'
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  void _showTakeDialog(Medicine med, DateTime scheduledTime) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Take ${med.name}"),
        content: const Text("When did you take this dose?"),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(context);
              final localizations = MaterialLocalizations.of(context);

              // Select Time
              final TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );

              if (!mounted) return;

              if (picked != null) {
                final formattedTime = localizations.formatTimeOfDay(picked);

                final now = DateTime.now();
                final pickedTime = DateTime(
                  now.year,
                  now.month,
                  now.day,
                  picked.hour,
                  picked.minute,
                );
                await _db.logDose(med.id, pickedTime); // Log ACTUAL time

                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text("Logged ${med.name} at $formattedTime"),
                  ),
                );
              }
            },
            child: const Text("Select Time"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(context);
              await _db.logDose(med.id, DateTime.now()); // Log NOW

              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(content: Text("Logged ${med.name} now")),
              );
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
