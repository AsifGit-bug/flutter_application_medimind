import 'package:flutter/material.dart';

import 'theme_manager.dart';
import 'login_page.dart';
import 'services/database_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  // No Mock Users List anymore

  final List<Map<String, dynamic>> _issues = [];

  // Content Management Controllers
  final TextEditingController _aboutUsController = TextEditingController();
  final TextEditingController _privacyPolicyController =
      TextEditingController();
  final TextEditingController _faqController = TextEditingController();

  bool _isLoadingContent = false;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() => _isLoadingContent = true);
    try {
      final content = await DatabaseService().getAppContent().first;
      if (mounted) {
        setState(() {
          _aboutUsController.text = content['aboutUs'] ?? '';
          _privacyPolicyController.text = content['privacyPolicy'] ?? '';
          _faqController.text = content['faq'] ?? '';
        });
      }
    } catch (e) {
      debugPrint("Error loading content: $e");
    } finally {
      if (mounted) setState(() => _isLoadingContent = false);
    }
  }

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
              // Logout
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
          ),
        ],
      ),
      // BODY NOW WRAPPED IN STREAM BUILDER
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: DatabaseService().getAllUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          final users = snapshot.data ?? [];
          return _buildCurrentTab(users);
        },
      ),
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
            // Removed Reports/Issues tabs which were heavily mock-reliant to simplify for now,
            // or we can keep them but they won't have real data yet.
            // Let's keep them but pass 'users' to them if needed.
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

  Widget _buildCurrentTab(List<Map<String, dynamic>> users) {
    switch (_selectedIndex) {
      case 0:
        return _buildOverviewTab(users);
      case 1:
        return _buildUsersTab(users);
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
  Widget _buildOverviewTab(List<Map<String, dynamic>> users) {
    // Calculate Stats Real-time
    final activeUsers = users
        .where((u) => u['active'] == true)
        .length; // Needs 'active' field in DB or default true
    final inactiveUsers = users.length - activeUsers;
    final patients = users
        .where((u) => u['role']?.toString().toLowerCase() == "patient")
        .length;
    final monitors = users
        .where(
          (u) =>
              u['role']?.toString().toLowerCase() == "monitor" ||
              u['role']?.toString().toLowerCase() == "guardian",
        )
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatCard(
            "Total Users",
            users.length.toString(),
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
                  patients.toString(),
                  Icons.medical_services,
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  "Monitors",
                  monitors.toString(),
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
          // Mock activity removed to avoid confusion
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              "Real-time logs coming soon...",
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
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

  // --- 2. User Management ---
  Widget _buildUsersTab(List<Map<String, dynamic>> users) {
    if (users.isEmpty) {
      return const Center(child: Text("No users found"));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: users.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final user = users[index];
        final bool isActive = user['active'] ?? true;
        final theme = Theme.of(context);
        final name = user['name'] ?? 'Unknown';
        final initial = name.isNotEmpty ? name[0] : '?';

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
                  initial,
                  style: TextStyle(color: theme.primaryColor),
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
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    Text(
                      user['role'] ?? 'Unknown Role',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                    Text(
                      user['email'] ?? 'No Email',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
              // Make switch read-only or implement update logic later
              Switch(
                value: isActive,
                onChanged: (val) async {
                  await DatabaseService().toggleUserActiveStatus(
                    user['id'],
                    val,
                  );
                },
                activeTrackColor: Colors.green,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 80, color: Colors.blueGrey[200]),
          const SizedBox(height: 16),
          const Text(
            "Reports & Analysis coming soon",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            "Once users start tracking medicines, charts will appear here.",
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildIssuesTab() {
    if (_issues.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              "No issues reported",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }
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
              onPressed: () async {
                setState(() => _isLoadingContent = true);
                try {
                  await DatabaseService().updateAppContent({
                    'aboutUs': _aboutUsController.text,
                    'privacyPolicy': _privacyPolicyController.text,
                    'faq': _faqController.text,
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Content updated successfully!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error updating: $e")),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoadingContent = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: _isLoadingContent
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Save All Changes"),
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
