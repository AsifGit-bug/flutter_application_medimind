import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../auth/login_page.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../common/report_bug_page.dart';
import '../patient/patient_dashboard.dart';
import '../../models/medicine_model.dart';
import '../../theme/theme_manager.dart';

class MonitorDashboard extends StatefulWidget {
  const MonitorDashboard({super.key});

  @override
  State<MonitorDashboard> createState() => _MonitorDashboardState();
}

class _MonitorDashboardState extends State<MonitorDashboard> {
  int _selectedIndex = 0;
  final DatabaseService _db = DatabaseService();
  final AuthService _auth = AuthService();
  User? _currentUser;
  final TextEditingController _inviteCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
  }

  void _linkPatient() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Link Patient"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter the patient's email address to link them."),
            const SizedBox(height: 16),
            TextField(
              controller: _inviteCodeController,
              decoration: InputDecoration(
                hintText: "Patient Email",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              String result = await _db.sendMonitorRequest(
                _currentUser!.uid,
                _inviteCodeController.text.trim(),
              );
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(result)));
              _inviteCodeController.clear();
            },
            child: const Text("Send Request"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? "My Patients" : "Settings"),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Switch Dashboard"),
                  content: const Text(
                    "Are you sure you want to switch to Patient Dashboard?",
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
                            builder: (context) => const PatientDashboard(),
                          ),
                        );
                      },
                      child: const Text("Yes"),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              ThemeManager.themeNotifier.value == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
              color: theme.iconTheme.color,
            ),
            onPressed: () {
              ThemeManager.toggleTheme();
              setState(() {});
            },
          ),
        ],
      ),
      body: _selectedIndex == 0 ? _buildPatientsList() : _buildSettingsTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (idx) => setState(() => _selectedIndex = idx),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "Patients"),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Settings",
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _linkPatient,
              label: const Text("Link Patient"),
              icon: const Icon(Icons.add_link),
            )
          : null,
    );
  }

  // --- PATIENTS TAB ---

  Widget _buildPatientsList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _db.getLinkedPatients(_currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final patients = snapshot.data ?? [];

        if (patients.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  "No patients linked yet.",
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _linkPatient,
                  child: const Text("Link your first patient"),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: patients.length,
          itemBuilder: (context, index) {
            final patient = patients[index];
            final String nickname = patient['nickname']?.toString() ?? '';
            final String officialName = patient['name']?.toString() ?? '';

            // Priority: Nickname > Official Name > 'Patient'
            String displayName = nickname.isNotEmpty
                ? nickname
                : (officialName.isNotEmpty ? officialName : 'Patient');

            final bool hasNickname = nickname.isNotEmpty;

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showPatientDetails(patient),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.1),
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : 'P',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (hasNickname)
                              Text(
                                officialName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            Text(
                              patient['email'] ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) {
                          if (value == 'nickname') {
                            _showEditNicknameSheet(
                              patient['id'],
                              patient['nickname'] ?? '',
                            );
                          } else if (value == 'remove') {
                            _removePatient(patient['id']);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'nickname',
                            child: Text("Edit Nickname"),
                          ),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Text(
                              "Remove Patient",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPatientDetails(Map<String, dynamic> patient) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patient['nickname'] ??
                                  patient['name'] ??
                                  'Patient',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              patient['email'] ?? '',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    "Medicine Adherence",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildTodaysProgress(patient['id']),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTodaysProgress(String patientId) {
    return StreamBuilder<List<Medicine>>(
      stream: _db.getMedicines(patientId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final medicines = snapshot.data!;

        // 1. Generate all daily events
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        List<Map<String, dynamic>> dailyEvents = [];

        for (var med in medicines) {
          // Flatten schedule times
          // If scheduleTimes is empty, fall back to 'time' (backward compat)
          List<DateTime> schedules = med.scheduleTimes.isNotEmpty
              ? med.scheduleTimes
              : [med.time];

          // For each scheduled time, determine status
          for (var sched in schedules) {
            // Construct today's scheduled instance
            final scheduledDateTime = DateTime(
              today.year,
              today.month,
              today.day,
              sched.hour,
              sched.minute,
            );

            // Check if TAKEN near this time (simplistic check: same day)
            // In a real app, we might match specific slots.
            // Here we just look for ANY dose taken today that hasn't been matched yet?
            // Simpler approach for MVP:
            // List all doses taken today. List all scheduled.
            // But we need to link them.

            // Revised Approach:
            // 1. Find all doses taken today for this med.
            // 2. Map them to the closest scheduled time?
            //    Or just list them as "Taken".

            // Let's stick to the list of items the patient sees.

            // Find specific dose taken corresponding to this schedule?
            // Since we don't have slot IDs, we just look for *any* dose taken today.
            // If med is "Twice a day", and valid doses count is 1, then 1 is taken, 1 pending.

            // Count doses taken today
            final dosesToday = med.doseHistory
                .where(
                  (d) =>
                      d.year == today.year &&
                      d.month == today.month &&
                      d.day == today.day,
                )
                .toList();
            dosesToday.sort(); // Earliest first

            // Count skipped doses today
            final skippedToday = med.skipHistory
                .where(
                  (d) =>
                      d.year == today.year &&
                      d.month == today.month &&
                      d.day == today.day,
                )
                .toList();
            skippedToday.sort();

            // Count explicitly missed doses today
            final missedToday = med.missedHistory
                .where(
                  (d) =>
                      d.year == today.year &&
                      d.month == today.month &&
                      d.day == today.day,
                )
                .toList();
            missedToday.sort();

            // Sequential Slot Mapping Logic
            // Slot 1 maps to Taken[0], then Skipped[0], then Missed[0]

            int schedIndex = schedules.indexOf(sched);

            DateTime? actualTakenTime;
            DateTime? actualSkippedTime;
            DateTime? actualMissedTime;
            String status;

            if (schedIndex < dosesToday.length) {
              status = "Taken";
              actualTakenTime = dosesToday[schedIndex];
            } else if ((schedIndex - dosesToday.length) < skippedToday.length) {
              status = "Skipped";
              actualSkippedTime = skippedToday[schedIndex - dosesToday.length];
            } else if ((schedIndex - dosesToday.length - skippedToday.length) <
                missedToday.length) {
              status = "Missed";
              actualMissedTime =
                  missedToday[schedIndex -
                      dosesToday.length -
                      skippedToday.length];
            } else {
              if (now.isAfter(scheduledDateTime)) {
                status = "Missed";
              } else {
                status = "Upcoming";
              }
            }

            dailyEvents.add({
              'medicine': med,
              'scheduledTime': scheduledDateTime,
              'actualTime':
                  actualTakenTime ?? actualSkippedTime ?? actualMissedTime,
              'status': status,
            });
          }
        }

        // Sort by time
        dailyEvents.sort((a, b) {
          DateTime timeA = a['actualTime'] ?? a['scheduledTime'];
          DateTime timeB = b['actualTime'] ?? b['scheduledTime'];
          return timeA.compareTo(timeB);
        });

        final theme = Theme.of(context);

        // Group by status
        final untracked = dailyEvents
            .where(
              (e) => e['status'] == 'Upcoming' || e['status'] == 'Untracked',
            )
            .toList(); // Monitor calls it "Upcoming" sometimes?
        // Wait, previous code used "Upcoming" for future.
        // Let's check logic:
        // } else {
        //   if (now.isAfter(scheduledDateTime)) {
        //     status = "Missed";
        //   } else {
        //     status = "Upcoming";
        //   }
        // }
        // So we have "Upcoming". Let's map "Upcoming" to "Untracked" section.

        final taken = dailyEvents.where((e) => e['status'] == 'Taken').toList();
        final skipped = dailyEvents
            .where((e) => e['status'] == 'Skipped')
            .toList();
        final missed = dailyEvents
            .where((e) => e['status'] == 'Missed')
            .toList();

        return Column(
          children: [
            if (untracked.isNotEmpty)
              _buildSection(
                context,
                "Upcoming",
                untracked,
                theme.primaryColor,
                Icons.radio_button_unchecked,
                isExpanded: true,
              )
            else
              _buildAllCaughtUpCard(),
            _buildSection(
              context,
              "Taken",
              taken,
              Colors.green,
              Icons.check_circle,
            ),
            _buildSection(
              context,
              "Skipped",
              skipped,
              Colors.amber,
              Icons.remove_circle_outline,
            ),
            _buildSection(
              context,
              "Missed",
              missed,
              Colors.red,
              Icons.error_outline,
            ),
          ],
        );
      },
    );
  }

  Widget _buildAllCaughtUpCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24, top: 8),
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
    BuildContext context,
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
        collapsedIconColor: color.withOpacity(0.7),
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
              child: Container(height: 1, color: color.withOpacity(0.1)),
            ),
          ],
        ),
        children: events
            .map((event) => _buildMonitorEventCard(context, event))
            .toList(),
      ),
    );
  }

  // Removed old _buildSectionHeader

  Widget _buildMonitorEventCard(
    BuildContext context,
    Map<String, dynamic> event,
  ) {
    final Medicine med = event['medicine'];
    final String status = event['status']; // Taken, Skipped, Missed, Upcoming
    // Note: Upcoming is mapped to Untracked section but status string might still be "Upcoming"

    final DateTime displayTime = event['actualTime'] ?? event['scheduledTime'];
    final theme = Theme.of(context);

    // ... inside _buildMonitorEventCard

    // Unused variables removed: statusIcon, timeLabel
    // logic simplified to only what is needed

    Color statusColor;
    // IconData statusIcon; // Removed
    // String timeLabel; // Removed

    if (status == "Taken") {
      statusColor = Colors.green;
      // statusIcon = Icons.check_circle;
      // timeLabel = "Taken at ...";
    } else if (status == "Skipped") {
      statusColor = Colors.amber;
      // statusIcon = Icons.remove_circle_outline;
      // timeLabel = "Skipped at ...";
    } else if (status == "Missed") {
      statusColor = Colors.red;
      // statusIcon = Icons.error_outline;
      // timeLabel = "Missed ...";
    } else {
      statusColor = Colors.grey;
      // statusIcon = Icons.radio_button_unchecked;
      // timeLabel = "Scheduled ...";
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
                    "${med.dosage} • ${DateFormat('h:mm a').format(displayTime)}",
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.7,
                      ),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  status == "Upcoming" ? "Untracked" : status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
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

  void _showEditNicknameSheet(String patientId, String currentNickname) {
    final controller = TextEditingController(text: currentNickname);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: "Nickname"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await _db.updatePatientNickname(
                  _currentUser!.uid,
                  patientId,
                  controller.text.trim(),
                );
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _removePatient(String patientId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Patient"),
        content: const Text("Are you sure you want to remove this patient?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.removePatientFromMonitor(_currentUser!.uid, patientId);
    }
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const Icon(Icons.person),
          title: Text(_currentUser?.email ?? 'User'),
          subtitle: const Text("Monitor Account"),
        ),
        ListTile(
          leading: const Icon(Icons.bug_report_outlined),
          title: const Text("Report an Issue"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReportBugPage()),
            );
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text("Logout", style: TextStyle(color: Colors.red)),
          onTap: () {
            _auth.signOut();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
            );
          },
        ),
      ],
    );
  }
}
