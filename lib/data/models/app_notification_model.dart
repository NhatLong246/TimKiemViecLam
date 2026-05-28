import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationCategory { job, system, promo, profile, message }

class AppNotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final NotificationCategory category;
  final bool isRead;
  final Map<String, dynamic> data;

  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.category,
    this.isRead = false,
    this.data = const {},
  });

  factory AppNotificationItem.fromMap(String id, Map<String, dynamic> map) {
    return AppNotificationItem(
      id: id,
      title: (map['title'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      category: _parseCategory(map['category']),
      isRead: map['isRead'] == true,
      data: Map<String, dynamic>.from(map['data'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'category': category.name,
        'isRead': isRead,
        if (data.isNotEmpty) 'data': data,
        'createdAt': FieldValue.serverTimestamp(),
      };

  String? get messageGroupId => data['groupId']?.toString();

  bool get isWorkAssignment => data['type']?.toString() == 'work_assignment';

  String? get workAssignmentGroupId => data['groupId']?.toString();

  String? get workAssignmentDate => data['date']?.toString();

  bool get isAttendanceRequest =>
      data['type']?.toString() == 'attendance_request';

  /// NTD: nhân viên vừa chụp ảnh điểm danh.
  bool get isAttendanceResult =>
      data['type']?.toString() == 'attendance_result';

  /// Nhận diện thông báo điểm danh (kể cả bản cũ chưa có `type` trong data).
  bool get isAttendanceNotification {
    if (isAttendanceRequest || isAttendanceResult) return true;
    final phase = data['phase']?.toString();
    if ((phase == 'check_in' || phase == 'check_out') && _hasGroupId) {
      return true;
    }
    final t = title.trim().toLowerCase();
    if (category == NotificationCategory.job && _hasGroupId) {
      if (t.startsWith('điểm danh') || t.contains('nhân viên điểm danh')) {
        return true;
      }
    }
    return false;
  }

  bool get _hasGroupId {
    final id = data['groupId']?.toString() ?? '';
    return id.isNotEmpty;
  }

  String? get attendanceGroupId => data['groupId']?.toString();

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
