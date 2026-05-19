import 'package:cloud_firestore/cloud_firestore.dart';

/// type: 'application' | 'post_approved' | 'post_rejected' | 'message' | 'system'
class NotificationModel {
  final String notifId;
  final String recipientId;    // employerId
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data; // extra: postId, groupId, candidateId…
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.notifId,
    required this.recipientId,
    required this.type,
    required this.title,
    required this.body,
    this.data = const {},
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String docId) {
    return NotificationModel(
      notifId: docId,
      recipientId: map['recipientId'] as String? ?? '',
      type: map['type'] as String? ?? 'system',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      data: Map<String, dynamic>.from(map['data'] as Map? ?? {}),
      isRead: map['isRead'] == true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'recipientId': recipientId,
        'type': type,
        'title': title,
        'body': body,
        'data': data,
        'isRead': isRead,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
