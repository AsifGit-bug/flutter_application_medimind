import 'package:flutter/material.dart';

import '../../theme/theme_manager.dart';
import '../auth/login_page.dart';
import '../../services/database_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  bool _showAdmins = false;
  bool _showTotalUsers = false;

  // No Mock Users List anymore

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
        return "Issue Management";
      case 2:
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
        return _buildIssuesTab();
      case 2:
        return _buildContentTab();
      default:
        return returnContainer();
    }
  }

  Widget returnContainer() => Container();

  // --- 1. System Overview ---
  // --- 1. System Overview ---
  Widget _buildOverviewTab(List<Map<String, dynamic>> users) {
    // Filter Users
    // Only show "Verified" users (those who successfully logged in/verified email)
    // We exclude admins from "Total Users" count to distinguish staff from customers
    final verifiedUsers = users.where((u) {
      final bool isVerified = u['isVerified'] ?? false;
      // We also hide "isDeleted" users if we want to be clean, but user just said "remove delete function"
      // so we rely on "Ban" (active: false).
      // If we previously soft-deleted users, they might have isDeleted: true.
      // Let's hide them if they are soft-deleted to keep list clean, or show them?
      // User said "show proper users... like those who are logged in".
      // Usually softly deleted users shouldn't show up.
      final bool isDeleted = u['isDeleted'] ?? false;
      return isVerified && !isDeleted;
    }).toList();

    final admins = verifiedUsers
        .where((u) => u['role']?.toString().toLowerCase() == "admin")
        .take(3)
        .toList();

    final normalUsers = verifiedUsers
        .where((u) => u['role']?.toString().toLowerCase() != "admin")
        .toList();

    // Total Users count should be the number of verified normal users
    final totalUserCount = normalUsers.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "System Overview",
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // --- STATS CARDS ROW ---
          Row(
            children: [
              // Admins Card
              Expanded(
                child: _buildInteractiveCard(
                  title: "Admins",
                  count: admins.length.toString(),
                  icon: Icons.admin_panel_settings,
                  color: Colors.purple,
                  isSelected: _showAdmins,
                  onTap: () {
                    setState(() {
                      _showAdmins = !_showAdmins;
                      // Optional: Auto-close others if we want accordion style
                      // _showTotalUsers = false;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Total Users Card (Verified Only)
              Expanded(
                child: _buildInteractiveCard(
                  title: "Total Users",
                  count: totalUserCount.toString(),
                  icon: Icons.group,
                  color: Colors.blue,
                  isSelected: _showTotalUsers,
                  onTap: () {
                    setState(() {
                      _showTotalUsers = !_showTotalUsers;
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // --- ADMINS LIST ---
          if (_showAdmins) ...[
            Text(
              "Administrative Staff",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (admins.isEmpty)
              const Text("No admins found")
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: admins.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final admin = admins[index];
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.purple.withValues(alpha: 0.1),
                        child: Icon(
                          Icons.admin_panel_settings,
                          color: Colors.purple,
                        ),
                      ),
                      title: Text(
                        admin['name'] ?? 'Unknown Admin',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _showAdminDetails(admin),
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),
          ],

          // --- USERS LIST ---
          if (_showTotalUsers) ...[
            Text(
              "Registered Users",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (normalUsers.isEmpty)
              const Text("No verified users found")
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: normalUsers.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final user = normalUsers[index];
                  final bool isActive = user['active'] ?? true;
                  final name = user['name'] ?? 'Unknown';
                  final email = user['email'] ?? 'No Email';
                  final initial = name.isNotEmpty ? name[0] : '?';

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.1),
                          child: Text(
                            initial,
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                            ),
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
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.color,
                                ),
                              ),
                              Text(
                                email,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Switch(
                              value: isActive,
                              onChanged: (val) async {
                                await DatabaseService().toggleUserActiveStatus(
                                  user['id'],
                                  val,
                                );
                              },
                              activeTrackColor: Colors.green,
                              activeThumbColor: Colors.white,
                            ),
                            Text(
                              isActive ? "Active" : "Banned",
                              style: TextStyle(
                                fontSize: 10,
                                color: isActive ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        // DELETE BUTTON REMOVED AS REQUESTED
                      ],
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }

  // _confirmDeleteUser removed or unused

  Widget _buildInteractiveCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: color, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
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
                color: isSelected
                    ? color.withValues(alpha: 0.2)
                    : color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              count,
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
      ),
    );
  }

  void _showAdminDetails(Map<String, dynamic> admin) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.purple.withValues(alpha: 0.1),
              child: const Icon(
                Icons.admin_panel_settings,
                color: Colors.purple,
              ),
            ),
            const SizedBox(width: 12),
            const Text("Admin Details"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow("Name", admin['name']),
            const SizedBox(height: 12),
            _detailRow("Email", admin['email']),
            const SizedBox(height: 12),
            _detailRow("Role", "System Administrator"),
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

  Widget _detailRow(String label, String? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(value ?? "N/A", style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  // --- 2. User Management ---

  Widget _buildIssuesTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: DatabaseService().getAllBugs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final bugs = snapshot.data ?? [];

        if (bugs.isEmpty) {
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
          itemCount: bugs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final bug = bugs[index];
            final theme = Theme.of(context);
            final bool isResolved = bug['status'] == 'Resolved';
            final Color statusColor = isResolved ? Colors.green : Colors.red;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border(left: BorderSide(color: statusColor, width: 4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          bug['title'] ?? 'No Title',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
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
                          bug['status'] ?? 'Open',
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
                    bug['description'] ?? 'No Description',
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Reported by ${bug['userEmail']} on ${bug['date']}",
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Delete Button
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.grey,
                        ),
                        onPressed: () async {
                          // Confirm delete logic could go here, for now quick delete
                          await DatabaseService().deleteBug(bug['id']);
                        },
                      ),
                      // Mark Done Button
                      if (!isResolved) ...[
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await DatabaseService().resolveBug(bug['id']);
                          },
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text("Mark Done"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
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
