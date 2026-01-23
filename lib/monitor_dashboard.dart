import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'medicine_model.dart';
import 'medicine_detail_page.dart';
import 'add_medicine_page.dart';
import 'theme_manager.dart';
import 'services/database_service.dart';
import 'content_display_page.dart';
import 'services/auth_service.dart';

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
              if (_inviteCodeController.text.trim().isEmpty) return;
              Navigator.pop(context);

              if (_currentUser == null) return;

              // Use sendMonitorRequest instead of linkPatient
              String result = await _db.sendMonitorRequest(
                _currentUser!.uid,
                _inviteCodeController.text.trim(),
              );

              if (!mounted) return;
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
        title: const Text(
          "Monitor Dashboard",
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
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

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PatientDetailView(patient: patient),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                    child: Text(
                      (patient['name'] is String &&
                              (patient['name'] as String).isNotEmpty)
                          ? patient['name'][0]
                          : '?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          patient['email'] ?? 'No Email',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removePatient(patient['id']),
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
            // Report issue
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
    _tabController = TabController(length: 3, vsync: this);
  }

  void _addMedicine() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMedicinePage(userId: widget.patient['id']),
      ),
    );
    // Stream will update view
  }

  void _editMedicine(Medicine medicine) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicineDetailPage(
          medicine: medicine,
          userId: widget.patient['id'],
          onDelete: () async {
            await _db.deleteMedicine(medicine.id);
            if (!mounted) return;
            Navigator.pop(context);
          },
          onUpdate: (updated) async {
            // Re-add to update
            await _db.addMedicine(updated, widget.patient['id']);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              widget.patient['name'] ?? 'Unknown',
              style: const TextStyle(color: Colors.black, fontSize: 16),
            ),
            const Text(
              "Monitoring",
              style: TextStyle(color: Colors.green, fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: theme.primaryColor,
          tabs: const [
            Tab(text: "Overview"),
            Tab(text: "Medicines"),
            Tab(text: "History"),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _addMedicine,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildMedicinesTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Activity",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // We can't easily get count without stream or fetching.
          // For now, these are placeholders or could be wrapped in stream builder too.
          _buildStatusCard("Taken", 0, Colors.green, Icons.check_circle),
          const SizedBox(height: 12),
          _buildStatusCard("Missed", 0, Colors.red, Icons.warning),
          const SizedBox(height: 12),
          _buildStatusCard("Pending", 0, Colors.orange, Icons.schedule),

          const SizedBox(height: 32),
          const Text(
            "Weekly Adherence",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: Text("Adherence Chart Placeholder")),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 16),
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            "$count",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
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

        final medicines = snapshot.data ?? [];
        medicines.sort((a, b) => a.time.compareTo(b.time));

        if (medicines.isEmpty) {
          return const Center(child: Text("No medicines yet."));
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
                onTap: () => _editMedicine(medicine),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          "Timeline (Read Only)",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),
        // Placeholder
        const Text("Real-time history coming soon."),
      ],
    );
  }
}
