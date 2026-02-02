import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyCaregiversPage extends StatelessWidget {
  const MyCaregiversPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not Logged In")));
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("My Caregivers"),
        backgroundColor: theme.cardColor,
        elevation: 0,
        iconTheme: theme.iconTheme,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: DatabaseService().getLinkedCaregivers(user.uid),
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? 0;
              final left = 5 - count;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  "$count/5 Caregivers Linked • $left left",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: left > 0 ? theme.primaryColor : Colors.red,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: DatabaseService().getLinkedCaregivers(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final caregivers = snapshot.data ?? [];

          if (caregivers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 80,
                    color: Colors.grey.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No Caregivers Linked",
                    style: TextStyle(
                      fontSize: 18,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Share your email with a monitor to get started.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: caregivers.length,
            itemBuilder: (context, index) {
              final caregiver = caregivers[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: theme.cardColor,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                    child: Text(
                      (caregiver['name'] ?? 'M')[0].toUpperCase(),
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  title: Text(
                    caregiver['name'] ?? 'Unknown Monitor',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (caregiver['email'] != null)
                        Text(
                          caregiver['email'],
                          style: const TextStyle(fontSize: 12),
                        ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Access Granted",
                          style: TextStyle(color: Colors.green, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red,
                    ),
                    onPressed: () async {
                      final TextEditingController confirmController =
                          TextEditingController();
                      final userId = FirebaseAuth.instance.currentUser?.uid;
                      if (userId == null) return;

                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Remove Caregiver"),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Are you sure you want to remove ${caregiver['name']}? They will no longer be able to monitor your medicines.\n\nTo confirm, please type \"unlink\" below.",
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: confirmController,
                                decoration: const InputDecoration(
                                  hintText: "Type 'unlink'",
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text("Cancel"),
                            ),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: confirmController,
                              builder: (context, value, child) {
                                return TextButton(
                                  onPressed:
                                      value.text.toLowerCase() == 'unlink'
                                      ? () => Navigator.pop(context, true)
                                      : null,
                                  child: const Text(
                                    "Remove",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await DatabaseService().unlinkPatient(
                          caregiver['uid'],
                          userId,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Caregiver removed successfully"),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
