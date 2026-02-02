import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType { info, warning, request, success }

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final String
  targetId; // ID linked to the notification (e.g., patientId or medicineId)
  final bool isRead;
  final DateTime createdAt;
  final String? deepLink; // Optional: To navigate to specific page

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.targetId,
    this.isRead = false,
    required this.createdAt,
    this.deepLink,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'type': type.toString().split('.').last,
      'targetId': targetId,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'deepLink': deepLink,
    };
  }

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return NotificationModel(
      id: id,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => NotificationType.info,
      ),
      targetId: map['targetId'] ?? '',
      isRead: map['isRead'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      deepLink: map['deepLink'],
    );
  }
}
