import 'package:cloud_firestore/cloud_firestore.dart';

/// Một dòng trong danh mục khiếu nại (gộp incidents + jobComplaints).
enum ComplaintCatalogType { worker, job, warning }

/// Bạn gửi đi hay người khác gửi về bạn.
enum ComplaintDirection { sent, received }

class ComplaintCatalogItem {
  final String id;
  final ComplaintCatalogType type;
  final ComplaintDirection direction;
  final String jobId;
  final String groupId;
  final String jobTitle;
  final String reporterId;
  final String targetUserId;
  final String summary;
  final String status;
  final bool postDissolution;
  final DateTime createdAt;
  final String? appealStatus;
  final String? appealText;
  final String? adminResponse;

  const ComplaintCatalogItem({
    required this.id,
    required this.type,
    required this.direction,
    required this.jobId,
    required this.groupId,
    required this.jobTitle,
    required this.reporterId,
    required this.targetUserId,
    required this.summary,
    required this.status,
    this.postDissolution = false,
    required this.createdAt,
    this.appealStatus,
    this.appealText,
    this.adminResponse,
  });

  String get typeLabel {
    if (type == ComplaintCatalogType.warning) return 'Cảnh báo từ Admin';
    return type == ComplaintCatalogType.worker ? 'Khiếu nại nhân viên' : 'Khiếu nại công việc';
  }

  String get directionLabel =>
      direction == ComplaintDirection.sent ? 'Bạn gửi' : 'Gửi về bạn';

  String directionLabelForRole(String role) {
    if (role == 'candidate') {
      return direction == ComplaintDirection.sent ? 'Bạn gửi' : 'Ca làm của bạn';
    }
    if (role == 'employer') {
      return direction == ComplaintDirection.sent ? 'Bạn gửi' : 'Về tin đăng';
    }
    return directionLabel;
  }

  /// Nhãn theo vai trò người xem (UV / NTD).
  String headlineForRole(String role) {
    if (postDissolution && direction == ComplaintDirection.sent) {
      return 'Khiếu nại sau giải tán';
    }
    if (type == ComplaintCatalogType.warning) {
      return 'Cảnh báo từ Admin';
    }
    if (role == 'candidate') {
      if (direction == ComplaintDirection.sent) {
        return 'Bạn khiếu nại về công việc đã làm';
      }
      return 'Khiếu nại về công việc bạn làm';
    }
    if (role == 'employer') {
      if (direction == ComplaintDirection.sent) {
        return 'Bạn khiếu nại về công việc nhân viên làm';
      }
      return 'Khiếu nại về công việc bạn đăng';
    }
    if (direction == ComplaintDirection.sent) {
      return type == ComplaintCatalogType.worker
          ? 'NTD → nhân viên'
          : 'UV → công việc';
    }
    return type == ComplaintCatalogType.worker
        ? 'Về ca làm nhân viên'
        : 'Về tin tuyển dụng';
  }

  String subtitleForRole(String role) {
    if (jobTitle.isEmpty) return typeLabel;
    if (role == 'candidate' && direction == ComplaintDirection.received) {
      return 'Ca: $jobTitle';
    }
    return jobTitle;
  }

  factory ComplaintCatalogItem.fromIncident(
    Map<String, dynamic> map,
    String id, {
    required ComplaintDirection direction,
  }) {
    return ComplaintCatalogItem(
      id: id,
      type: ComplaintCatalogType.worker,
      direction: direction,
      jobId: map['jobId'] as String? ?? '',
      groupId: map['groupId'] as String? ?? '',
      jobTitle: (map['jobTitle'] as String?)?.trim().isNotEmpty == true
          ? map['jobTitle'] as String
          : (map['workerName'] as String? ?? 'Công việc'),
      reporterId: map['reportedBy'] as String? ?? '',
      targetUserId: map['workerId'] as String? ?? '',
      summary: map['description'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      postDissolution: map['postDissolution'] == true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      appealStatus: map['appealStatus'] as String?,
      appealText: map['appealText'] as String?,
      adminResponse: map['adminResponse'] as String?,
    );
  }

  factory ComplaintCatalogItem.fromJobComplaint(
    Map<String, dynamic> map,
    String id, {
    required ComplaintDirection direction,
  }) {
    return ComplaintCatalogItem(
      id: id,
      type: ComplaintCatalogType.job,
      direction: direction,
      jobId: map['jobId'] as String? ?? '',
      groupId: map['groupId'] as String? ?? '',
      jobTitle: map['jobTitle'] as String? ?? '',
      reporterId: map['candidateId'] as String? ?? '',
      targetUserId: map['employerId'] as String? ?? '',
      summary: map['description'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      postDissolution: map['postDissolution'] == true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      appealStatus: map['appealStatus'] as String?,
      appealText: map['appealText'] as String?,
      adminResponse: map['adminResponse'] as String?,
    );
  }

  factory ComplaintCatalogItem.fromAdminWarning(
    Map<String, dynamic> map,
    String id,
  ) {
    return ComplaintCatalogItem(
      id: id,
      type: ComplaintCatalogType.warning,
      direction: ComplaintDirection.received,
      jobId: '',
      groupId: '',
      jobTitle: map['title'] as String? ?? 'Cảnh báo hệ thống',
      reporterId: 'admin',
      targetUserId: map['targetUserId'] as String? ?? '',
      summary: map['description'] as String? ?? '',
      status: 'warning',
      postDissolution: false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      appealStatus: map['appealStatus'] as String?,
      appealText: map['appealText'] as String?,
      adminResponse: map['adminResponse'] as String?,
    );
  }
}
