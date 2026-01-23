import 'package:flutter/material.dart';

import 'login_page.dart';
import 'medicine_model.dart';
import 'medicine_detail_page.dart';
import 'add_medicine_page.dart';
import 'theme_manager.dart';

class MonitorDashboard extends StatefulWidget {
  const MonitorDashboard({super.key});

  @override
  State<MonitorDashboard> createState() => _MonitorDashboardState();
}

class _MonitorDashboardState extends State<MonitorDashboard> {
  int _selectedIndex = 0;

  // Mock Linked Patients Data
  final List<Map<String, dynamic>> _linkedPatients = [
    {
      'id': 'p1',
      'name': 'John Patient',
      'email': 'john.patient@example.com',
      'adherence': 0.88,
      'missed': 3,
      'medicines': <Medicine>[], // Populated in initState
    },
  ];

  @override
  void initState() {
    super.initState();
    // Simulate some medicine data for the mock patient
    final now = DateTime.now();
    _linkedPatients[0]['medicines'] = [
      Medicine(
        id: 'm1',
        name: 'Metformin',
        dosage: '500mg',
        frequency: 'Daily',
        time: DateTime(now.year, now.month, now.day, 8, 0),
        doseHistory: [],
        type: 'Pill',
        instructions: 'Take with food',
      ),
      Medicine(
        id: 'm2',
        name: 'Lisinopril',
        dosage: '10mg',
        frequency: 'Daily',
        time: DateTime(now.year, now.month, now.day, 9, 0),
        doseHistory: [],
        type: 'Pill',
        instructions: 'Take in the morning',
      ),
    ];
  }

  void _linkPatient() {
    if (_linkedPatients.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maximum of 2 patients allowed.")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Link Patient"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter the invite code from the patient's app."),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: "Invite Code",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
            ),
            const SizedBox(height: 16),
            const Center(child: Text("- OR -")),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                // Mock QR Scan
                Navigator.pop(context);
                _mockAddPatient();
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text("Scan QR Code"),
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
            child: const Text("Link"),
          ),
        ],
      ),
    );
  }

  void _mockAddPatient() {
    setState(() {
      _linkedPatients.add({
        'id': 'p2',
        'name': 'Jane Doe',
        'email': 'jane.doe@example.com',
        'adherence': 0.95,
        'missed': 0,
        'medicines': <Medicine>[],
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Patient linked successfully!")),
    );
  }

  void _removePatient(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Patient?"),
        content: const Text(
          "Are you sure you want to stop monitoring this patient?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _linkedPatients.removeWhere((p) => p['id'] == id);
              });
              Navigator.pop(context);
            },
            child: const Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
    if (_linkedPatients.isEmpty) {
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
      itemCount: _linkedPatients.length,
      itemBuilder: (context, index) {
        final patient = _linkedPatients[index];
        return _buildPatientCard(patient);
      },
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final theme = Theme.of(context);
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
                      patient['name'][0],
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
                          patient['name'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          patient['email'],
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
                  _buildMiniStat(
                    "Adherence",
                    "${(patient['adherence'] * 100).toInt()}%",
                    Colors.green,
                  ),
                  _buildMiniStat(
                    "Missed (7d)",
                    "${patient['missed']}",
                    Colors.red,
                  ),
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
          onTap: () {},
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text("About Us"),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {},
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text("Privacy Policy"),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {},
        ),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: const Text("FAQ"),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {},
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
  late List<Medicine> _medicines;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _medicines = widget.patient['medicines'];
  }

  void _addMedicine() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddMedicinePage()),
    );

    if (result != null && result is Medicine) {
      if (!mounted) return;
      setState(() {
        _medicines.add(result);
        _sortMedicines();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Medicine added for patient")),
      );
    }
  }

  void _editMedicine(Medicine medicine) async {
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
          onUpdate: (updated) {
            setState(() {
              final idx = _medicines.indexWhere((m) => m.id == updated.id);
              if (idx != -1) _medicines[idx] = updated;
              _sortMedicines();
            });
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _sortMedicines() {
    _medicines.sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              widget.patient['name'],
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
          _buildStatusCard("Taken", 2, Colors.green, Icons.check_circle),
          const SizedBox(height: 12),
          _buildStatusCard("Missed", 0, Colors.red, Icons.warning),
          const SizedBox(height: 12),
          _buildStatusCard("Pending", 3, Colors.orange, Icons.schedule),

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
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _medicines.length,
      itemBuilder: (context, index) {
        final medicine = _medicines[index];
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
        // Mock timeline items
        _buildTimelineItem("8:00 AM", "Metformin 500mg", "Taken", Colors.green),
        _buildTimelineItem("9:00 AM", "Lisinopril 10mg", "Taken", Colors.green),
        _buildTimelineItem(
          "12:00 PM",
          "Aspirin 81mg",
          "Pending",
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildTimelineItem(
    String time,
    String desc,
    String status,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              time,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
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
                  Expanded(child: Text(desc)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
