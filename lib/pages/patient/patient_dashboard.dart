import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/medicine_model.dart';
import 'add_medicine_page.dart';
import 'medicine_detail_page.dart';
import 'my_caregivers_page.dart'; // NEW IMPORT
import '../auth/login_page.dart';
import '../monitor/monitor_dashboard.dart';
import '../../theme/theme_manager.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../common/content_display_page.dart';
import '../common/report_bug_page.dart';

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
  final int _takenCount = 0;
  final int _pendingCount = 0;

  // History Tab State
  StreamSubscription<List<Medicine>>? _medicinesSubscription;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser!;
    _fetchUserData();
    _subscribeToMedicines();
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
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.medication),
              label: "Medicines",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: "History",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: "Settings",
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
                _buildSettingsSectionHeader("General"),
                _buildSettingsTile(
                  Icons.person_outline,
                  "Personal Data",
                  _showProfileDetails,
                ),
                _buildSettingsTile(Icons.group_outlined, "My Caregivers", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyCaregiversPage(),
                    ),
                  );
                }),
                _buildSettingsTile(
                  Icons.people_outline,
                  "Monitor Requests",
                  () => _showMonitorRequests(),
                ),
                _buildSettingsTile(
                  Icons.notifications_none,
                  "Notifications",
                  () {},
                ),
                const SizedBox(height: 24),
                _buildSettingsSectionHeader("Support"),
                _buildSettingsTile(Icons.bug_report, "Report an Issue", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReportBugPage(),
                    ),
                  );
                }),
                _buildSettingsTile(Icons.info_outline, "About Us", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ContentDisplayPage(
                        title: "About Us",
                        contentKey: "aboutUs",
                      ),
                    ),
                  );
                }),
                _buildSettingsTile(Icons.help_outline, "Help & FAQ", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ContentDisplayPage(
                        title: "Help & FAQ",
                        contentKey: "faq",
                      ),
                    ),
                  );
                }),
                _buildSettingsTile(
                  Icons.privacy_tip_outlined,
                  "Privacy Policy",
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
                    child: const Text("Log Out"),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    "App Version 1.0.0",
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
      for (int i = 0; i < 7; i++) {
        final checkDate = today.subtract(Duration(days: i));
        final scheduledTime = DateTime(
          checkDate.year,
          checkDate.month,
          checkDate.day,
          med.time.hour,
          med.time.minute,
        );

        // Check if taken on this day
        final takenDoses = med.doseHistory
            .where(
              (d) =>
                  d.year == checkDate.year &&
                  d.month == checkDate.month &&
                  d.day == checkDate.day,
            )
            .toList();

        if (takenDoses.isNotEmpty) {
          // Add 'Taken' events
          for (var dose in takenDoses) {
            historyEvents.add({
              'name': med.name,
              'dosage': med.dosage,
              'type': med.type,
              'time': dose, // Actual time taken
              'status': 'Taken',
            });
          }
        } else {
          // Check for 'Missed'
          // If the scheduled time is in the past, it's missed
          if (scheduledTime.isBefore(now)) {
            historyEvents.add({
              'name': med.name,
              'dosage': med.dosage,
              'type': med.type,
              'time': scheduledTime, // Scheduled time
              'status': 'Missed',
            });
          }
        }
      }
    }

    // Sort by time descending (newest first)
    historyEvents.sort((a, b) => b['time'].compareTo(a['time']));

    if (historyEvents.isEmpty) {
      return Center(
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
                "No history (last 7 days).",
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: historyEvents.map((event) {
        return _buildTimelineItem(
          event['name'],
          "${event['dosage']} • ${event['type']}",
          DateFormat('MMM d, h:mm a').format(event['time']),
          event['status'] == 'Taken' ? Colors.green : Colors.red,
          event['status'],
        );
      }).toList(),
    );
  }

  Widget _buildTimelineItem(
    String name,
    String details,
    String time,
    Color color,
    String status,
  ) {
    final theme = Theme.of(context);
    bool isTaken = status == 'Taken';

    return Container(
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
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isTaken ? Icons.check : Icons.medication,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                Text(
                  details,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isTaken
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: isTaken ? Colors.green : Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
                                "Good Morning,",
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

              // Hero Section (Overlaps background naturally)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildHeroSection(),
              ),

              // Rest of the content
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard("Taken", _takenCount, const [
                            Color(0xFF66BB6A),
                            Color(0xFF43A047),
                          ], Icons.check_circle_outline),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            "Pending",
                            _pendingCount,
                            const [Color(0xFFFFA726), Color(0xFFFB8C00)],
                            Icons.schedule,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Text(
                      "Today's Medicines",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge!.color,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _medicines.isEmpty
                        ? _buildEmptyState()
                        : Column(
                            children: _medicines
                                .map((m) => _buildMedicineCard(m))
                                .toList(),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMedicinesTab(List<Medicine> medicines) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Medicines',
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
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: medicines.isEmpty
                ? _buildEmptyState()
                : Column(
                    children: medicines
                        .map((m) => _buildMedicineCard(m))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    int count,
    List<Color> gradientColors,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(icon, color: Colors.white70, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "$count",
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    Medicine? nextDose;
    if (_medicines.isNotEmpty) {
      final now = DateTime.now();
      try {
        nextDose = _medicines.firstWhere(
          (m) => !m.doseHistory.any((d) => isSameDay(d, now)),
        );
      } catch (e) {
        // Silently ignore
        // No pending doses found
      }
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF311B92), Color(0xFF673AB7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF673AB7).withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.notifications_active,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      "Next Dose",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.more_horiz, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            nextDose != null ? nextDose.name : "All Clear!",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            nextDose != null
                ? "Scheduled for ${DateFormat('h:mm a').format(nextDose.time)}"
                : "You have taken all your meds.",
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 20),
          if (nextDose != null)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  await _db.logDose(nextDose!.id, DateTime.now());
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Dose logged successfully!")),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF673AB7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "Mark as Taken",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
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
            "No medicines added yet",
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

  Widget _buildMedicineCard(Medicine medicine) {
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
                    "${medicine.dosage} • ${medicine.frequency}",
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.textTheme.bodyMedium!.color,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Profile Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _buildDetailRow("Patient Name", _userName)),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () {
                    Navigator.pop(context);
                    _showEditNameDialog();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow("Email", _userEmail),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
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
        title: const Text("Edit Name"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: "Full Name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                await _db.updateUserName(_currentUser.uid, newName);
                if (mounted) {
                  setState(() => _userName = newName);
                  Navigator.pop(context); // Close dialog
                  // Re-open details to show updated info (optional, but nice)
                  _showProfileDetails();
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodyMedium!.color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge!.color,
          ),
        ),
      ],
    );
  }

  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
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
                "Monitor Requests",
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
                      return const Center(child: Text("No pending requests."));
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
                                    if (mounted) {
                                      navigator.pop();
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text("Request Accepted"),
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
                                    if (mounted) {
                                      navigator.pop();
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text("Request Declined"),
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
}
