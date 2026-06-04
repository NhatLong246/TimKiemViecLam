import 'package:cloud_firestore/cloud_firestore.dart';

/// Trạng thái giải ngân (luồng mới)
/// approved → complaints_pending → complaints_reviewed → completed
///                                                    → no_complaint → completed
class DisbursementNoticeModel {
  final String noticeId;
  final String jobId;
  final String groupId;
  final String employerId;
  final String workDate;
  final double amount;
  final String jobTitle;
  final String status;
  final bool employerAck;
  final bool adminAck;
  final DateTime createdAt;

  /// Số tiền mỗi ứng viên nhận (chia đều)
  /// { candidateId: amount }
  final Map<String, double> candidateAmounts;

  /// Số tiền đền bù mỗi ứng viên bị khiếu nại (NTD đề xuất)
  /// { candidateId: compensationAmount }
  final Map<String, double> deductions;

  /// Danh sách ID ứng viên bị khiếu nại
  final List<String> complainedCandidates;

  /// Lý do khiếu nại cho từng ứng viên
  /// { candidateId: reason }
  final Map<String, String> complaintReasons;

  /// Bằng chứng khiếu nại (ảnh URL)
  /// { candidateId: [url1, url2] }
  final Map<String, List<String>> complaintEvidence;

  /// Kết quả admin duyệt cho từng khiếu nại: 'approved' | 'rejected'
  /// { candidateId: 'approved' | 'rejected' }
  final Map<String, String> complaintResults;

  /// Số tiền admin chốt cho từng ứng viên bị khiếu nại
  /// { candidateId: finalCompensation }
  final Map<String, double> adminFinalDeductions;

  /// Ghi chú admin
  final String adminNote;

  /// Tổng số ứng viên
  final int totalCandidates;

  /// Danh sách ứng viên đã được đánh giá
  final List<String> ratedCandidates;

  /// Thời điểm Admin duyệt khiếu nại xong
  final DateTime? complaintsReviewedAt;

  /// User nợ chênh lệch (tiền đền bù > lương)
  /// { candidateId: { 'owed': amount, 'deadline': Timestamp, 'paid': bool } }
  final Map<String, Map<String, dynamic>> userDebts;

  const DisbursementNoticeModel({
    required this.noticeId,
    required this.jobId,
    required this.groupId,
    required this.employerId,
    required this.workDate,
    required this.amount,
    this.jobTitle = '',
    required this.status,
    this.employerAck = false,
    this.adminAck = false,
    required this.createdAt,
    this.candidateAmounts = const {},
    this.deductions = const {},
    this.complainedCandidates = const [],
    this.complaintReasons = const {},
    this.complaintEvidence = const {},
    this.complaintResults = const {},
    this.adminFinalDeductions = const {},
    this.adminNote = '',
    this.totalCandidates = 0,
    this.ratedCandidates = const [],
    this.complaintsReviewedAt,
    this.userDebts = const {},
  });

  bool get isFullyAcknowledged => employerAck && adminAck;
  bool get canEmployerDisburse => status == 'approved';
  bool get isWaitingAdmin => status == 'pending_admin';
  bool get isRatingInProgress => status == 'rating_in_progress';
  bool get isComplaintsPending => status == 'complaints_pending';
  bool get isComplaintsReviewed => status == 'complaints_reviewed';
  bool get isCompleted => status == 'completed';
  bool get hasComplaints => complainedCandidates.isNotEmpty;

  bool get allRated =>
      totalCandidates > 0 && ratedCandidates.length >= totalCandidates;

  /// Tổng tiền sau trừ khiếu nại
  double get totalAfterDeductions {
    final totalDeducted =
        adminFinalDeductions.values.fold<double>(0, (sum, v) => sum + v);
    return amount - totalDeducted;
  }

  factory DisbursementNoticeModel.fromMap(
      Map<String, dynamic> map, String id) {
    return DisbursementNoticeModel(
      noticeId: id,
      jobId: map['jobId'] as String? ?? '',
      groupId: map['groupId'] as String? ?? '',
      employerId: map['employerId'] as String? ?? '',
      workDate: map['workDate'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      jobTitle: map['jobTitle'] as String? ?? '',
      status: map['status'] as String? ?? 'approved',
      employerAck: map['employerAck'] as bool? ?? false,
      adminAck: map['adminAck'] as bool? ?? false,
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      candidateAmounts: _parseDoubleMap(map['candidateAmounts']),
      deductions: _parseDoubleMap(map['deductions']),
      complainedCandidates:
          (map['complainedCandidates'] as List?)?.cast<String>() ?? [],
      complaintReasons: _parseStringMap(map['complaintReasons']),
      complaintEvidence: _parseStringListMap(map['complaintEvidence']),
      complaintResults: _parseStringMap(map['complaintResults']),
      adminFinalDeductions: _parseDoubleMap(map['adminFinalDeductions']),
      adminNote: map['adminNote'] as String? ?? '',
      totalCandidates: (map['totalCandidates'] as num?)?.toInt() ?? 0,
      ratedCandidates:
          (map['ratedCandidates'] as List?)?.cast<String>() ?? [],
      complaintsReviewedAt:
          (map['complaintsReviewedAt'] as Timestamp?)?.toDate(),
      userDebts: _parseDynamicMapMap(map['userDebts']),
    );
  }

  static Map<String, double> _parseDoubleMap(dynamic raw) {
    if (raw == null || raw is! Map) return {};
    return raw.map(
        (k, v) => MapEntry(k.toString(), (v as num?)?.toDouble() ?? 0));
  }

  static Map<String, String> _parseStringMap(dynamic raw) {
    if (raw == null || raw is! Map) return {};
    return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  static Map<String, List<String>> _parseStringListMap(dynamic raw) {
    if (raw == null || raw is! Map) return {};
    return raw.map((k, v) {
      final list = (v as List?)?.cast<String>() ?? [];
      return MapEntry(k.toString(), list);
    });
  }

  static Map<String, Map<String, dynamic>> _parseDynamicMapMap(dynamic raw) {
    if (raw == null || raw is! Map) return {};
    return raw.map((k, v) {
      final inner = v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
      return MapEntry(k.toString(), inner);
    });
  }

  Map<String, dynamic> toMap() => {
        'jobId': jobId,
        'groupId': groupId,
        'employerId': employerId,
        'workDate': workDate,
        'amount': amount,
        'jobTitle': jobTitle,
        'status': status,
        'employerAck': employerAck,
        'adminAck': adminAck,
        'createdAt': FieldValue.serverTimestamp(),
        'candidateAmounts': candidateAmounts,
        'deductions': deductions,
        'complainedCandidates': complainedCandidates,
        'complaintReasons': complaintReasons,
        'complaintEvidence': complaintEvidence,
        'complaintResults': complaintResults,
        'adminFinalDeductions': adminFinalDeductions,
        'adminNote': adminNote,
        'totalCandidates': totalCandidates,
        'ratedCandidates': ratedCandidates,
        'userDebts': userDebts,
      };
}
