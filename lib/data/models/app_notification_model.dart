import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationCategory { job, system, promo, profile }

class AppNotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final NotificationCategory category;
  final bool isRead;

  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.category,
    this.isRead = false,
  });

  factory AppNotificationItem.fromMap(String id, Map<String, dynamic> map) {
    return AppNotificationItem(
      id: id,
      title: (map['title'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      category: _parseCategory(map['category']),
      isRead: map['isRead'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'category': category.name,
        'isRead': isRead,
        'createdAt': FieldValue.serverTimestamp(),
      };

  AppNotificationItem copyWith({bool? isRead}) => AppNotificationItem(
        id: id,
        title: title,
        body: body,
        createdAt: createdAt,
        category: category,
        isRead: isRead ?? this.isRead,
      );

  static NotificationCategory _parseCategory(dynamic v) {
    final s = (v ?? 'system').toString();
    return NotificationCategory.values.firstWhere(
      (c) => c.name == s,
      orElse: () => NotificationCategory.system,
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}
