import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../utils/translations.dart';

class MonitorRequestsPage extends StatelessWidget {
  final String userId;
  MonitorRequestsPage({super.key, required this.userId});

  final DatabaseService _db = DatabaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Translations.get('monitor_requests', 'en'))),
      body: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Manage your caregiver requests",
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _db.getLinkedCaregivers(userId),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.length ?? 0;
                    final left = 5 - count;
                    return Text(
                      "$left slots left",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: left > 0
                            ? Theme.of(context).primaryColor
                            : Colors.red,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _db.getPendingRequests(userId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final requests = snapshot.data ?? [];
                  if (requests.isEmpty) {
                    return Center(
                      child: Text(
                        Translations.get('no_pending_requests', 'en'),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final req = requests[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(req['monitorEmail'] ?? 'Unknown Monitor'),
                          subtitle: const Text(
                            "Wants to view your medicine data",
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.check,
                                  color: Colors.green,
                                ),
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  final result = await _db.acceptRequest(
                                    req['id'],
                                    req['monitorId'],
                                    userId,
                                  );
                                  if (context.mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(content: Text(result)),
                                    );
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  await _db.declineRequest(req['id']);
                                  if (context.mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          Translations.get(
                                            'request_declined',
                                            'en',
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
