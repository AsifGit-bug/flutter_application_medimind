import 'package:flutter/material.dart';

import 'theme_manager.dart';
import 'login_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  // --- Mock Data ---
  final List<Map<String, dynamic>> _users = [
    {
      "id": 1,
      "name": "John Patient",
      "role": "Patient",
      "active": true,
      "email": "john@example.com",
    },
    {
      "id": 2,
      "name": "Dr. Smith",
      "role": "Monitor",
      "active": true,
      "email": "dr.smith@example.com",
    },
    {
      "id": 3,
      "name": "Admin User",
      "role": "Admin",
      "active": true,
      "email": "admin@medimind.com",
    },
    {
      "id": 4,
      "name": "Jane Doe",
      "role": "Patient",
      "active": false,
      "email": "jane@example.com",
    },
    {
      "id": 5,
      "name": "Nurse Joy",
      "role": "Monitor",
      "active": true,
      "email": "joy@example.com",
    },
  ];

  final List<Map<String, dynamic>> _issues = [
    {
      "id": 101,
      "title": "Login failing",
      "status": "Open",
      "user": "John Patient",
      "date": "2023-10-25",
    },
    {
      "id": 102,
      "title": "Crash on history",
      "status": "In Progress",
      "user": "Dr. Smith",
      "date": "2023-10-24",
    },
    {
      "id": 103,
      "title": "Typo in FAQ",
      "status": "Resolved",
      "user": "Jane Doe",
      "date": "2023-10-20",
    },
  ];

  // Content Management Controllers
  final TextEditingController _aboutUsController = TextEditingController(
    text:
        "MediMind is dedicated to helping patients manage their medication adherence through smart monitoring and reminders.",
  );
  final TextEditingController _privacyPolicyController = TextEditingController(
    text: "Your data is secure with us. We adhere to HIPAA guidelines...",
  );
  final TextEditingController _faqController = TextEditingController(
    text: "Q: How do I add medicine?\nA: Go to the Medicine tab and click +.",
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _getTitle(_selectedIndex),
          style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
        ),
        backgroundColor: theme.cardColor,
        elevation: 0,
        iconTheme: theme.iconTheme,
        actions: [
          IconButton(
            icon: Icon(
              ThemeManager.themeNotifier.value == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () {
              ThemeManager.toggleTheme();
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
          ),
        ],
      ),
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
          unselectedItemColor: theme.textTheme.bodyMedium?.color,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: "Overview",
            ),
            BottomNavigationBarItem(icon: Icon(Icons.people), label: "Users"),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics),
              label: "Reports",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bug_report),
              label: "Issues",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.edit_note),
              label: "Content",
            ),
          ],
        ),
      ),
    );
  }

  String _getTitle(int index) {
    switch (index) {
      case 0:
        return "System Overview";
      case 1:
        return "User Management";
      case 2:
        return "Reports & Analysis";
      case 3:
        return "Issue Management";
      case 4:
        return "Content Management";
      default:
        return "Admin Dashboard";
    }
  }

  Widget _buildCurrentTab() {
    switch (_selectedIndex) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildUsersTab();
      case 2:
        return _buildReportsTab();
      case 3:
        return _buildIssuesTab();
      case 4:
        return _buildContentTab();
      default:
        return returnContainer();
    }
  }

  Widget returnContainer() => Container();

  // --- 1. System Overview ---
  Widget _buildOverviewTab() {
    final activeUsers = _users.where((u) => u['active'] == true).length;
    final inactiveUsers = _users.length - activeUsers;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatCard(
            "Total Users",
            _users.length.toString(),
            Icons.group,
            Colors.blue,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Active",
                  activeUsers.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  "Inactive",
                  inactiveUsers.toString(),
                  Icons.cancel,
                  Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Patients",
                  _users.where((u) => u['role'] == "Patient").length.toString(),
                  Icons.medical_services,
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  "Monitors",
                  _users.where((u) => u['role'] == "Monitor").length.toString(),
                  Icons.remove_red_eye,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            "Recent Activity",
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 12),
          _buildActivityItem("New user registration: John Doe", "2 mins ago"),
          _buildActivityItem("Issue reported: Login Error", "1 hour ago"),
          _buildActivityItem("Content updated: Privacy Policy", "Yesterday"),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          Text(
            time,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. User Management ---
  Widget _buildUsersTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _users.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final user = _users[index];
        final bool isActive = user['active'];
        final theme = Theme.of(context);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                child: Text(
                  user['name'][0],
                  style: TextStyle(color: theme.primaryColor),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    Text(
                      user['role'],
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                    Text(
                      user['email'],
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isActive,
                onChanged: (val) {
                  setState(() {
                    user['active'] = val;
                  });
                },
                activeTrackColor: Colors.green,
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 3. Reports & Analysis ---
  Widget _buildReportsTab() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Adherence Overview", style: theme.textTheme.titleLarge),
          const SizedBox(height: 20),
          _buildChartPlaceholder("Overall Adherence", "85%"),
          const SizedBox(height: 24),
          Text("Missed Dose Trends", style: theme.textTheme.titleLarge),
          const SizedBox(height: 20),
          Container(
            height: 200,
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBar(0.4, "Mon", Colors.red),
                _buildBar(0.2, "Tue", Colors.red),
                _buildBar(0.6, "Wed", Colors.red),
                _buildBar(0.3, "Thu", Colors.red),
                _buildBar(0.1, "Fri", Colors.red),
                _buildBar(0.5, "Sat", Colors.red),
                _buildBar(0.2, "Sun", Colors.red),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text("Summary", style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildSummaryItem("Daily Average", "92% Adherence"),
          _buildSummaryItem("Weekly Average", "88% Adherence"),
          _buildSummaryItem("Most Missed", "Lunch Doses"),
        ],
      ),
    );
  }

  Widget _buildChartPlaceholder(String title, String mainValue) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(color: theme.textTheme.bodyMedium?.color),
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 150,
                width: 150,
                child: CircularProgressIndicator(
                  value: 0.85,
                  strokeWidth: 12,
                  backgroundColor: theme.dividerColor,
                  color: theme.colorScheme.secondary,
                ),
              ),
              Text(
                mainValue,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBar(double heightFactor, String label, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          height: 120 * heightFactor,
          width: 20,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. Issue Management ---
  Widget _buildIssuesTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _issues.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final issue = _issues[index];
        final theme = Theme.of(context);

        Color statusColor = Colors.grey;
        if (issue['status'] == 'Open') statusColor = Colors.red;
        if (issue['status'] == 'In Progress') statusColor = Colors.orange;
        if (issue['status'] == 'Resolved') statusColor = Colors.green;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: statusColor, width: 4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    issue['title'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      issue['status'],
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Reported by ${issue['user']} on ${issue['date']}",
                style: TextStyle(
                  fontSize: 12,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (issue['status'] != 'Resolved')
                    TextButton(
                      child: const Text("Mark Resolved"),
                      onPressed: () {
                        setState(() {
                          issue['status'] = "Resolved";
                        });
                      },
                    ),
                  if (issue['status'] == 'Open')
                    TextButton(
                      child: const Text("Mark In Progress"),
                      onPressed: () {
                        setState(() {
                          issue['status'] = "In Progress";
                        });
                      },
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 5. Content Management ---
  Widget _buildContentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildContentEditor("About Us", _aboutUsController),
          const SizedBox(height: 24),
          _buildContentEditor("Privacy Policy", _privacyPolicyController),
          const SizedBox(height: 24),
          _buildContentEditor("FAQ", _faqController),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Content updated successfully!"),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text("Save All Changes"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentEditor(String label, TextEditingController controller) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 5,
          style: TextStyle(color: theme.textTheme.bodyLarge?.color),
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
