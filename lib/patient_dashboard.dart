import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'medicine_model.dart';
import 'add_medicine_page.dart';
import 'medicine_detail_page.dart';
import 'login_page.dart';
import 'monitor_dashboard.dart';
import 'theme_manager.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  int _selectedIndex = 0;
  final List<Medicine> _medicines = [];

  // History Tab State
  String _historyView = "Timeline";
  String _historyFilter = "All";

  // Stats (Placeholder)
  int get _takenCount => 0;
  int get _pendingCount => _medicines.length;

  void _navigateToAddMedicine() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddMedicinePage()),
    );

    if (!mounted) return;

    if (result != null && result is Medicine) {
      setState(() {
        _medicines.add(result);
        _sortMedicines();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${result.name} added"),
          backgroundColor: Theme.of(context).primaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _navigateToDetail(Medicine medicine) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicineDetailPage(
          medicine: medicine,
          onDelete: () {
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
              backgroundColor: theme.colorScheme.primary, // Ensure contrast
              child: Icon(Icons.add, color: theme.colorScheme.onPrimary),
            )
          : null,
    );
  }

  Widget _buildCurrentTab() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildMedicinesTab();
      case 2:
        return _buildHistoryTab();
      case 3:
        return _buildSettingsTab();
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildThemeToggle({Color? color}) {
    // If color is not provided, adaptive default
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

  // --- SETTINGS TAB ---

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
                  children: [_buildThemeToggle(color: Colors.white)],
                ),
                CircleAvatar(
                  radius: 40,
                  backgroundColor: theme.cardColor,
                  child: Icon(
                    Icons.person,
                    size: 40,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "John Patient",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  "john.patient@example.com",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
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
                  () {},
                ),
                _buildSettingsTile(Icons.people_outline, "Monitor", () {}),
                _buildSettingsTile(
                  Icons.notifications_none,
                  "Notifications",
                  () {},
                ),

                const SizedBox(height: 24),
                _buildSettingsSectionHeader("Support"),
                _buildSettingsTile(Icons.info_outline, "About Us", () {}),
                _buildSettingsTile(Icons.help_outline, "Help & FAQ", () {}),
                _buildSettingsTile(
                  Icons.privacy_tip_outlined,
                  "Privacy Policy",
                  () {},
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

  Widget _buildHistoryTab() {
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
                _buildThemeToggle(color: theme.textTheme.bodyLarge!.color),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildToggleOption("Timeline"),
                  _buildToggleOption("Calendar"),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_historyView == "Timeline")
              _buildTimelineView()
            else
              _buildCalendarView(),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleOption(String text) {
    final bool isSelected = _historyView == text;
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _historyView = text),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.secondary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : theme.textTheme.bodyMedium!.color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineView() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE, MMMM d, y').format(DateTime.now()),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: theme.textTheme.bodyLarge!.color,
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ["All", "Taken", "Missed", "Skipped"].map((filter) {
                    final isSelected = _historyFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (val) =>
                            setState(() => _historyFilter = filter),
                        selectedColor: theme.colorScheme.secondary,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : theme.textTheme.bodyLarge!.color,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        backgroundColor:
                            theme.scaffoldBackgroundColor, // Adaptive
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: theme.dividerColor),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              _buildTimelineItem(
                "Metformin",
                "500mg",
                "8:00 AM",
                const Color(0xFF009688),
                "Taken",
              ),
              _buildTimelineItem(
                "Lisinopril",
                "10mg",
                "9:00 AM",
                theme.colorScheme.secondary, // Adaptive color
                "Skipped",
              ),
              _buildTimelineItem(
                "Aspirin",
                "81mg",
                "12:00 PM",
                const Color(0xFF9C27B0),
                "Pending",
              ),
              _buildTimelineItem(
                "Vitamin D",
                "1000IU",
                "6:00 PM",
                const Color(0xFFE91E63),
                "Pending",
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(
    String name,
    String dosage,
    String time,
    Color color,
    String status,
  ) {
    IconData statusIcon;
    Color statusColor;
    if (status == "Taken") {
      statusIcon = Icons.check_circle_outline;
      statusColor = Colors.green;
    } else if (status == "Skipped") {
      statusIcon = Icons.remove_circle_outline;
      statusColor = Colors.orange;
    } else {
      statusIcon = Icons.access_time;
      statusColor = Colors.grey;
    }

    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.medication, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: theme
                                  .textTheme
                                  .bodyLarge!
                                  .color, // Ensure high contrast
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "$dosage • Scheduled: $time",
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium!.color,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(statusIcon, color: statusColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarView() {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: Icon(
                      Icons.chevron_left,
                      color: theme.iconTheme.color,
                    ),
                  ),
                  Text(
                    DateFormat('MMMM y').format(DateTime.now()),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge!.color,
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(
                      Icons.chevron_right,
                      color: theme.iconTheme.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Table(
                children: [
                  TableRow(
                    children: [
                      Center(
                        child: Text(
                          "S",
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium!.color,
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          "M",
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium!.color,
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          "T",
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium!.color,
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          "W",
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium!.color,
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          "T",
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium!.color,
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          "F",
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium!.color,
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          "S",
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium!.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const TableRow(
                    children: [
                      SizedBox(height: 8),
                      SizedBox(),
                      SizedBox(),
                      SizedBox(),
                      SizedBox(),
                      SizedBox(),
                      SizedBox(),
                    ],
                  ),
                  for (int week = 0; week < 4; week++)
                    TableRow(
                      children: List.generate(7, (day) {
                        final int dayNum = (week * 7) + day + 1;
                        if (dayNum > 31) return const SizedBox();
                        Color? dotColor;
                        if (dayNum < DateTime.now().day) {
                          dotColor = dayNum % 2 == 0
                              ? Colors.green
                              : Colors.red;
                        }

                        return Container(
                          height: 40,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                dayNum.toString(),
                                style: TextStyle(
                                  color: theme.textTheme.bodyLarge!.color,
                                  fontWeight: dayNum == DateTime.now().day
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              if (dotColor != null)
                                Container(
                                  width: 4,
                                  height: 4,
                                  margin: const EdgeInsets.only(top: 2),
                                  decoration: BoxDecoration(
                                    color: dotColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: _buildStatCard("Taken (Jan)", 24, [
                const Color(0xFF66BB6A),
                const Color(0xFF43A047),
              ], Icons.check_circle_outline),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard("Missed (Jan)", 3, [
                const Color(0xFFEF5350),
                const Color(0xFFC62828),
              ], Icons.error_outline),
            ),
          ],
        ),
        const SizedBox(height: 20),

        Card(
          elevation: 0,
          color: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Adherence",
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium!.color,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "88%",
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge!.color,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Superb!",
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    children: [
                      Center(
                        child: CircularProgressIndicator(
                          value: 0.88,
                          strokeWidth: 8,
                          backgroundColor: theme.brightness == Brightness.dark
                              ? Colors.grey[800]
                              : Colors.grey.shade100,
                          color: const Color(0xFF009688),
                        ),
                      ),
                      const Center(
                        child: Icon(Icons.thumb_up, color: Color(0xFF009688)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Last 7 Days Activity",
                style: TextStyle(
                  color: theme.textTheme.bodyLarge!.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(7, (index) {
                  final double height = [
                    40.0,
                    60.0,
                    80.0,
                    50.0,
                    80.0,
                    70.0,
                    30.0,
                  ][index];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 20,
                        height: height,
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ["S", "M", "T", "W", "T", "F", "S"][index],
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium!.color,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- HOME & MEDICINE TABS ---

  Widget _buildHomeTab() {
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
                  children: [
                    GestureDetector(
                      onTap: _showProfileDetails,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.person,
                              color: theme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Good morning",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "John Patient",
                                style: TextStyle(
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
                    const Spacer(),
                    _buildSwitchDashboardIcon(color: Colors.white),
                    _buildThemeToggle(color: Colors.white),
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

  Widget _buildMedicinesTab() {
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
                  "My Medicines",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge!.color,
                  ),
                ),
                _buildThemeToggle(color: theme.textTheme.bodyLarge!.color),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _medicines.isEmpty
                ? _buildEmptyState()
                : Column(
                    children: _medicines
                        .map((m) => _buildMedicineCard(m))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPER METHODS ---

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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF311B92),
            Color(0xFF673AB7),
          ], // Deep Purple Gradient
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Next Dose",
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Metformin 500mg",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(
                Icons.access_time_filled,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 6),
              const Text(
                "Scheduled for 8:00 PM",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF673AB7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: const Text("Mark Taken"),
              ),
            ],
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
          color: theme.brightness == Brightness.dark
              ? Colors.grey.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
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
            _buildDetailRow("Patient Name", "John Patient"),
            const SizedBox(height: 12),
            _buildDetailRow("Monitor Name", "Sarah Guardian"),
            const SizedBox(height: 12),
            _buildDetailRow("Email", "john.patient@example.com"),
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
}
