import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

        // Filter for "Today" (MVP: Show all active daily meds)
        final todayMeds = medicines.toList();
        todayMeds.sort((a, b) => a.time.compareTo(b.time));

        if (todayMeds.isEmpty) {
          return const Center(child: Text("No medicines scheduled for today."));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: todayMeds.length,
          itemBuilder: (context, index) {
            final med = todayMeds[index];
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);

            // Check if taken today
            bool isTaken = med.doseHistory.any(
              (d) =>
                  d.year == today.year &&
                  d.month == today.month &&
                  d.day == today.day,
            );

            // Med sched time for today
            final medTime = DateTime(
              today.year,
              today.month,
              today.day,
              med.time.hour,
              med.time.minute,
            );

            String status;
            Color statusColor;
            IconData statusIcon;

            if (isTaken) {
              status = "Taken";
              statusColor = Colors.green;
              statusIcon = Icons.check_circle;
            } else if (now.isAfter(medTime)) {
              status = "Missed";
              statusColor = Colors.red;
              statusIcon = Icons.error_outline;
            } else {
              status = "Upcoming";
              statusColor = Colors.orange;
              statusIcon = Icons.access_time;
            }

            return Card(
              elevation: 0,
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
              ),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                title: Text(
                  med.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("${med.dosage} • ${med.frequency}"),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      "${med.time.hour > 12 ? med.time.hour - 12 : med.time.hour}:${med.time.minute.toString().padLeft(2, '0')} ${med.time.hour >= 12 ? 'PM' : 'AM'}",
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
