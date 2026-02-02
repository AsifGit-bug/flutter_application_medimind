import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../auth/login_page.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../common/report_bug_page.dart';
import '../../models/notification_model.dart';
import '../../models/medicine_model.dart';
import '../../theme/theme_manager.dart';
import '../patient/patient_dashboard.dart';
import '../common/notifications_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/notification_service.dart';

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
  bool _allowNotifications = true; // Default to true

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _linkPatient();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _allowNotifications =
              prefs.getBool(NotificationService.keyAllowNotifications) ?? true;
        });
      }
    } catch (e) {
      debugPrint("Error loading settings: $e");
    }
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
              if (_currentUser == null) return;
              String email = _inviteCodeController.text.trim();
              if (email.isEmpty) return;

              String result = await _db.sendMonitorRequest(
                _currentUser!.uid,
                email,
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
                  content: const Text("Switch to Patient Dashboard?"),
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
          StreamBuilder<List<NotificationModel>>(
            stream: _db.getNotifications(_currentUser!.uid),
            builder: (context, snapshot) {
              final hasUnread = snapshot.data?.any((n) => !n.isRead) ?? false;
              return IconButton(
                icon: Badge(
                  isLabelVisible: hasUnread,
                  smallSize: 8,
                  child: Icon(
                    hasUnread
                        ? Icons.notifications_active
                        : Icons.notifications_none,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          NotificationsPage(userId: _currentUser!.uid),
                    ),
                  );
                },
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
            onPressed: () => ThemeManager.toggleTheme(),
          ),
        ],
      ),
      body: _selectedIndex == 0 ? _buildPatientsList() : _buildSettingsTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (idx) => setState(() => _selectedIndex = idx),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.people_rounded),
            label: "Patients",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: "Settings",
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? StreamBuilder<List<Map<String, dynamic>>>(
              stream: _db.getLinkedPatients(_currentUser!.uid),
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                return FloatingActionButton.extended(
                  onPressed: count < 5
                      ? _linkPatient
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "You have reached the maximum limit of 5 patients.",
                              ),
                            ),
                          );
                        },
                  label: Text(count < 5 ? "Link Patient" : "Limit Reached"),
                  icon: Icon(count < 5 ? Icons.add_link : Icons.lock_outline),
                  backgroundColor: count < 5 ? theme.primaryColor : Colors.grey,
                );
              },
            )
          : null,
    );
  }

  Widget _buildPatientsList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _db.getLinkedPatients(_currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text("Error: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final patients = snapshot.data ?? [];
        final int left = 5 - patients.length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "My Patients (${patients.length}/5)",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    "$left left",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: left > 0
                          ? Theme.of(context).primaryColor
                          : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            if (patients.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 80,
                        color: Colors.grey.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "No patients linked yet.",
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      TextButton(
                        onPressed: _linkPatient,
                        child: const Text("Link your first patient"),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: patients.length,
                  itemBuilder: (context, index) {
                    final patient = patients[index];
                    final String displayName =
                        patient['nickname']?.toString().isNotEmpty == true
                        ? patient['nickname']
                        : (patient['name']?.toString() ?? 'Patient');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          radius: 25,
                          backgroundColor: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.1),
                          child: Text(
                            displayName[0].toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(patient['email'] ?? ''),
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) async {
                            if (val == 'nickname') {
                              _showEditNicknameSheet(
                                patient['id'],
                                patient['nickname'] ?? '',
                              );
                            } else if (val == 'toggle_mute') {
                              final isMuted = patient['isMuted'] ?? false;
                              if (isMuted) {
                                await _db.unmutePatient(
                                  _currentUser!.uid,
                                  patient['id'],
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Notifications unmuted"),
                                    ),
                                  );
                                }
                              } else {
                                await _db.mutePatient(
                                  _currentUser!.uid,
                                  patient['id'],
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Notifications muted"),
                                    ),
                                  );
                                }
                              }
                              setState(() {
                                // Stream will auto-update UI
                              });
                            } else if (val == 'remove') {
                              _removePatient(patient['id']);
                            }
                          },
                          itemBuilder: (context) {
                            final isMuted = patient['isMuted'] ?? false;
                            return [
                              PopupMenuItem(
                                value: 'toggle_mute',
                                child: Row(
                                  children: [
                                    Icon(
                                      isMuted
                                          ? Icons.notifications_off
                                          : Icons.notifications_active,
                                      color: isMuted
                                          ? Colors.grey
                                          : Theme.of(context).primaryColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isMuted
                                          ? "Unmute Notifications"
                                          : "Mute Notifications",
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'nickname',
                                child: Text("Edit Nickname"),
                              ),
                              const PopupMenuItem(
                                value: 'remove',
                                child: Text(
                                  "Remove",
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ];
                          },
                        ),
                        onTap: () => _showPatientDetails(patient),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  void _showPatientDetails(Map<String, dynamic> patient) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: theme.primaryColor.withValues(
                          alpha: 0.1,
                        ),
                        child: Text(
                          (patient['nickname'] ?? patient['name'] ?? 'P')[0]
                              .toUpperCase(),
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (patient['nickname'] != null &&
                                      patient['nickname'].toString().isNotEmpty)
                                  ? "${patient['nickname']} (${patient['name'] ?? ''})"
                                  : (patient['nickname'] ??
                                        patient['name'] ??
                                        'Patient'),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              patient['email'] ?? '',
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
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
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final medicines = snapshot.data!.where((m) => !m.isDeleted).toList();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        List<Map<String, dynamic>> historyEvents = [];

        for (int i = 0; i < 2; i++) {
          final checkDate = today.subtract(Duration(days: i));
          for (var med in medicines) {
            List<DateTime> schedules = med.scheduleTimes.isNotEmpty
                ? med.scheduleTimes
                : [med.time];

            final dosesOnDay =
                med.doseHistory.where((d) => isSameDay(d, checkDate)).toList()
                  ..sort();
            final skippedOnDay =
                med.skipHistory.where((d) => isSameDay(d, checkDate)).toList()
                  ..sort();
            final missedOnDay =
                med.missedHistory.where((d) => isSameDay(d, checkDate)).toList()
                  ..sort();

            for (var sched in schedules) {
              final scheduledDateTime = DateTime(
                checkDate.year,
                checkDate.month,
                checkDate.day,
                sched.hour,
                sched.minute,
              );
              int idx = schedules.indexOf(sched);
              String status = "Upcoming";
              DateTime? actualTime;

              if (idx < dosesOnDay.length) {
                status = "Taken";
                actualTime = dosesOnDay[idx];
              } else if (idx < dosesOnDay.length + skippedOnDay.length) {
                status = "Skipped";
                actualTime = skippedOnDay[idx - dosesOnDay.length];
              } else if (idx <
                  dosesOnDay.length +
                      skippedOnDay.length +
                      missedOnDay.length) {
                status = "Missed";
                actualTime =
                    missedOnDay[idx - dosesOnDay.length - skippedOnDay.length];
              } else if (now.isAfter(scheduledDateTime)) {
                status = "Missed";
              }

              // Only add if it's today or if it's a past dose that has a record or is missed
              if (isSameDay(checkDate, today) || status != "Upcoming") {
                historyEvents.add({
                  'medicine': med,
                  'scheduledTime': scheduledDateTime,
                  'actualTime': actualTime,
                  'status': status,
                  'date': checkDate,
                });
              }
            }
          }
        }

        // Separate today's events for the progress gauge
        final dailyEvents = historyEvents
            .where((e) => isSameDay(e['date'], today))
            .toList();
        dailyEvents.sort(
          (a, b) => (a['actualTime'] ?? a['scheduledTime']).compareTo(
            b['actualTime'] ?? b['scheduledTime'],
          ),
        );

        // Group history by date
        Map<DateTime, List<Map<String, dynamic>>> groupedHistory = {};
        for (var event in historyEvents) {
          final date = event['date'];
          if (!groupedHistory.containsKey(date)) {
            groupedHistory[date] = [];
          }
          groupedHistory[date]!.add(event);
        }
        final sortedDates = groupedHistory.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        final total = dailyEvents.length;
        final takenCount = dailyEvents
            .where((e) => e['status'] == 'Taken')
            .length;
        final progress = total > 0 ? takenCount / total : 1.0;
        final theme = Theme.of(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Daily Adherence",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "${(progress * 100).toInt()}% completed today",
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 5,
                      backgroundColor: theme.primaryColor.withValues(
                        alpha: 0.1,
                      ),
                    ),
                    Text(
                      "${(progress * 100).toInt()}%",
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 32),
            const Text(
              "Adherence History",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...sortedDates.map((date) {
              final events = groupedHistory[date]!;
              final isToday = isSameDay(date, today);
              final isYesterday = isSameDay(
                date,
                today.subtract(const Duration(days: 1)),
              );

              String dateHeader;
              if (isToday)
                dateHeader = "Today";
              else if (isYesterday)
                dateHeader = "Yesterday";
              else
                dateHeader = DateFormat('EEEE, MMM d').format(date);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      dateHeader,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  if (isToday) ...[
                    _buildSection(
                      context,
                      "Upcoming",
                      events.where((e) => e['status'] == 'Upcoming').toList(),
                      theme.primaryColor,
                      Icons.schedule,
                      isExpanded: true,
                    ),
                    _buildSection(
                      context,
                      "Taken",
                      events.where((e) => e['status'] == 'Taken').toList(),
                      Colors.green,
                      Icons.check_circle,
                    ),
                    _buildSection(
                      context,
                      "Other",
                      events
                          .where(
                            (e) => ['Skipped', 'Missed'].contains(e['status']),
                          )
                          .toList(),
                      Colors.orange,
                      Icons.info_outline,
                    ),
                  ] else ...[
                    // For past days, show list of event cards
                    ...events.map((e) => _buildEventCard(context, e)),
                  ],
                  const SizedBox(height: 8),
                ],
              );
            }),
          ],
        );
      },
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
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: isExpanded,
        tilePadding: EdgeInsets.zero,
        title: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 10,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Text(
                events.length.toString(),
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        children: events.map((e) => _buildEventCard(context, e)).toList(),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, Map<String, dynamic> event) {
    final Medicine med = event['medicine'];
    final String status = event['status'];
    final DateTime time = event['actualTime'] ?? event['scheduledTime'];
    final theme = Theme.of(context);

    Color statusColor = status == 'Taken'
        ? Colors.green
        : (status == 'Upcoming' ? Colors.grey : Colors.red);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(_getMedicineIcon(med.type), color: statusColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  med.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  isSameDay(time, DateTime.now())
                      ? "${med.dosage} • ${DateFormat('h:mm a').format(time)}"
                      : "${med.dosage} • ${DateFormat('MMM d, h:mm a').format(time)}",
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
          Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
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
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
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
                  controller.text,
                );
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  void _removePatient(String patientId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Patient"),
        content: const Text("Are you sure?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true)
      await _db.removePatientFromMonitor(_currentUser!.uid, patientId);
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.notifications_active),
            title: const Text("Notification Settings"),
            subtitle: const Text("Manage caregiver alerts"),
            trailing: Switch(
              value: _allowNotifications,
              activeColor: Theme.of(context).primaryColor,
              onChanged: (val) {
                setState(() {
                  _allowNotifications = val;
                });
                SharedPreferences.getInstance().then((prefs) {
                  prefs.setBool(NotificationService.keyAllowNotifications, val);
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 1),
                      content: Text(
                        "Notifications ${val ? 'enabled' : 'disabled'}",
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.person),
          title: Text(_currentUser?.email ?? 'User'),
          subtitle: const Text("Monitor Account"),
        ),
        ListTile(
          leading: const Icon(Icons.bug_report),
          title: const Text("Report an Issue"),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ReportBugPage()),
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text("Logout"),
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

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
