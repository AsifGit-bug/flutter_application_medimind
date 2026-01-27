import 'package:flutter/material.dart';
import 'services/database_service.dart';

class ContentDisplayPage extends StatelessWidget {
  final String title;
  final String contentKey; // 'aboutUs', 'faq', 'privacyPolicy'

  const ContentDisplayPage({
    super.key,
    required this.title,
    required this.contentKey,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: DatabaseService().getAppContent(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final data = snapshot.data ?? {};
          final content = data[contentKey] ?? "Content not available.";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Text(
              content,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          );
        },
      ),
    );
  }
}
