import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'patient_dashboard.dart';
import 'medicine_model.dart';
import 'medicine_detail_page.dart';
import 'theme_manager.dart';
import 'services/database_service.dart';
import 'content_display_page.dart';
import 'services/auth_service.dart';
import 'report_bug_page.dart';

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
            onPressed: () {
              Navigator.pop(context);
              _mockAddPatient();
            },
            child: const Text("Send Request"),
          ),
        ],
      ),
    );
  }

  void _removePatient(String patientId) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Remove Patient?"),
            content: const Text(
              "Are you sure you want to unlink this patient?",
            ),
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
        ) ??
        false;

    if (confirm && mounted && _currentUser != null) {
      await _db.unlinkPatient(_currentUser!.uid, patientId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
        title: Text(
          "Monitor Dashboard",
          style: TextStyle(
            color: theme.textTheme.bodyLarge?.color, // Adaptive text color
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.cardColor, // Adaptive background
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.swap_horiz, color: theme.iconTheme.color),
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

        final linkedPatients = snapshot.data ?? [];

        if (linkedPatients.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  "No patients linked yet",
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: linkedPatients.length,
          itemBuilder: (context, index) {
            final patient = linkedPatients[index];
            return _buildPatientCard(patient);
          },
        );
      },
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final theme = Theme.of(context);
    final int medCount = patient['medicineCount'] ?? 0;
    // Mock stats for now since we don't aggregate adherence in backend yet
    final int adherence = 0;
    final int missed = 0;

    String displayName = patient['nickname'] ?? patient['name'] ?? 'Unknown';
    bool hasNickname =
        patient['nickname'] != null && patient['nickname'].isNotEmpty;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.cardColor,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PatientDetailView(patient: patient),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Hero(
                    tag: 'avatar_${patient['id']}',
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: theme.primaryColor.withValues(
                        alpha: 0.1,
                      ),
                      child: Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (hasNickname)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              patient['name'] ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          patient['email'] ?? 'No Email',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                    onSelected: (value) {
                      if (value == 'nickname') {
                        _showEditNicknameSheet(
                          patient['id'],
                          patient['nickname'] ?? '',
                        );
                      } else if (value == 'delete') {
                        _removePatient(patient['id']);
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'nickname',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 12),
                                Text('Set Nickname'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Remove Patient',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(
                height: 1,
                color: theme.dividerColor.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat("Medicines", "$medCount", Colors.blue),
                  _buildMiniStat("Adherence", "$adherence%", Colors.green),
                  _buildMiniStat("Missed (7d)", "$missed", Colors.red),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // --- SETTINGS/SUPPORT TAB ---

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          "Support",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        ListTile(
          leading: const Icon(Icons.bug_report_outlined),
          title: const Text("Report an Issue"),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReportBugPage()),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text("About Us"),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
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
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text("Privacy Policy"),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
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
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: const Text("FAQ"),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const ContentDisplayPage(title: "FAQ", contentKey: "faq"),
              ),
            );
          },
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            child: const Text("Log Out"),
          ),
        ),
      ],
    );
  }
}

// --- PATIENT DETAIL VIEW ---

class PatientDetailView extends StatefulWidget {
  final Map<String, dynamic> patient;
  const PatientDetailView({super.key, required this.patient});

  @override
  State<PatientDetailView> createState() => _PatientDetailViewState();
}

class _PatientDetailViewState extends State<PatientDetailView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              widget.patient['nickname'] != null &&
                      widget.patient['nickname'].isNotEmpty
                  ? widget.patient['nickname']
                  : widget.patient['name'] ?? 'Unknown',
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 16,
              ),
            ),
            const Text(
              "Monitoring",
              style: TextStyle(color: Colors.green, fontSize: 12),
            ),
          ],
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        centerTitle: true,
        iconTheme: theme.iconTheme,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: theme.primaryColor,
          tabs: const [
            Tab(text: "Today's Medicines"),
            Tab(text: "7 Days History"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildMedicinesTab(), _buildHistoryTab()],
      ),
    );
  }

  Widget _buildMedicinesTab() {
    return StreamBuilder<List<Medicine>>(
      stream: _db.getMedicines(widget.patient['id']),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allMedicines = snapshot.data ?? [];
        // Filter for Today
        final medicines = allMedicines.where(_isMedicineForToday).toList();
        medicines.sort((a, b) => a.time.compareTo(b.time));

        if (medicines.isEmpty) {
          return const Center(child: Text("No medicines scheduled for today."));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: medicines.length,
          itemBuilder: (context, index) {
            final medicine = medicines[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withValues(alpha: 0.1),
                  child: const Icon(Icons.medication, color: Colors.blue),
                ),
                title: Text(
                  medicine.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("${medicine.dosage} • ${medicine.frequency}"),
                trailing: const Icon(Icons.chevron_right),
                // Show details (Read-only)
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MedicineDetailPage(
                        medicine: medicine,
                        userId: widget.patient['id'],
                        isReadOnly: true,
                        // Callbacks can be null or empty since it is read-only
                        onDelete: null,
                        onUpdate: null,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  bool _isMedicineForToday(Medicine medicine) {
    if (medicine.frequency == 'Daily' ||
        medicine.frequency == 'Twice a day' ||
        medicine.frequency == 'As needed') {
      return true;
    }
    if (medicine.frequency == 'Weekly') {
      return DateTime.now().weekday == medicine.time.weekday;
    }
    return true;
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<List<Medicine>>(
      stream: _db.getMedicines(widget.patient['id']),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final medicines = snapshot.data!;
        final cutoff = DateTime.now().subtract(const Duration(days: 7));

        // Flatten and Filter History
        List<Map<String, dynamic>> historyItems = [];
        for (var med in medicines) {
          for (var doseTime in med.doseHistory) {
            if (doseTime.isAfter(cutoff)) {
              historyItems.add({
                'name': med.name,
                'time': doseTime,
                'status': 'Taken',
              });
            }
          }
        }

        historyItems.sort(
          (a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime),
        );

        if (historyItems.isEmpty) {
          return const Center(child: Text("No history in last 7 days."));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: historyItems.length,
          itemBuilder: (context, index) {
            final item = historyItems[index];
            final DateTime time = item['time'];
            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(
                  item['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("Taken on ${time.toString().split('.')[0]}"),
              ),
            );
          },
        );
      },
    );
  }
}
