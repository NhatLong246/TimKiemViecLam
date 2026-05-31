import 'package:cloud_firestore/cloud_firestore.dart';

class CandidatePayment {
  final String id;
  final String jobTitle;
  final String employerName;
  final int amountVnd;
  final String status; // pending | paid | disputed
  final DateTime? paidAt;
  final String? benefitNote;

  const CandidatePayment({
    required this.id,
    required this.jobTitle,
    required this.employerName,
    required this.amountVnd,
    required this.status,
    this.paidAt,
    this.benefitNote,
  });

  factory CandidatePayment.fromMap(String id, Map<String, dynamic> map) {
    return CandidatePayment(
      id: id,
      jobTitle: (map['jobTitle'] ?? '').toString(),
      employerName: (map['employerName'] ?? '').toString(),
      amountVnd: (map['amountVnd'] as num?)?.toInt() ?? 0,
      status: (map['status'] ?? 'pending').toString(),
      paidAt: _parseDate(map['paidAt']),
      benefitNote: map['benefitNote']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'jobTitle': jobTitle,
        'employerName': employerName,
        'amountVnd': amountVnd,
        'status': status,
        if (paidAt != null) 'paidAt': Timestamp.fromDate(paidAt!),
        if (benefitNote != null) 'benefitNote': benefitNote,
      };

  String get amountDisplay {
    final s = amountVnd.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return '$sđ';
  }

  String get statusLabel {
    switch (status) {
      case 'paid':
        return 'Đã thanh toán';
      case 'disputed':
        return 'Đang khiếu nại';
      default:
        return 'Chờ thanh toán';
    }
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}

class ReviewableJob {
  final String jobId;
  final String employerId;
  final String jobTitle;
  final String employerName;

  const ReviewableJob({
    required this.jobId,
    required this.employerId,
    required this.jobTitle,
    required this.employerName,
  });

  String get label => '$jobTitle · $employerName';
}

class CandidateReviewGiven {
  final String id;
  final String employerName;
  final String jobTitle;
  final double rating;
  final String? comment;
  final List<String> tags;
  final DateTime? createdAt;

  const CandidateReviewGiven({
    required this.id,
    required this.employerName,
    required this.jobTitle,
    required this.rating,
    this.comment,
    this.tags = const [],
    this.createdAt,
  });

  factory CandidateReviewGiven.fromMap(String id, Map<String, dynamic> map) {
    final rawTags = map['tags'];
    return CandidateReviewGiven(
      id: id,
      employerName: (map['employerName'] ?? '').toString(),
      jobTitle: (map['jobTitle'] ?? '').toString(),
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      comment: map['comment']?.toString(),
      tags: rawTags is List
          ? rawTags.map((e) => e.toString()).toList()
          : const [],
      createdAt: _parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'employerName': employerName,
        'jobTitle': jobTitle,
        'rating': rating,
        if (comment != null && comment!.isNotEmpty) 'comment': comment,
        'tags': tags,
        'createdAt': FieldValue.serverTimestamp(),
      };

  static DateTime? parseDate(dynamic v) => _parseDate(v);

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}

class WorkGroup {
  final String id;
  final String name;
  final String inviteCode;
  final String leaderId;
  final List<String> memberIds;
  final int completedShifts;
  final DateTime? createdAt;

  const WorkGroup({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.leaderId,
    required this.memberIds,
    this.completedShifts = 0,
    this.createdAt,
  });

  factory WorkGroup.fromMap(String id, Map<String, dynamic> map) {
    final members = map['memberIds'];
    return WorkGroup(
      id: id,
      name: (map['name'] ?? '').toString(),
      inviteCode: (map['inviteCode'] ?? '').toString(),
      leaderId: (map['leaderId'] ?? '').toString(),
      memberIds: members is List
          ? members.map((e) => e.toString()).toList()
          : const [],
      completedShifts: (map['completedShifts'] as num?)?.toInt() ?? 0,
      createdAt: _parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'inviteCode': inviteCode,
        'leaderId': leaderId,
        'memberIds': memberIds,
        'completedShifts': completedShifts,
        'createdAt': FieldValue.serverTimestamp(),
      };

  int get memberCount => memberIds.length;

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}

class CandidateEarningsSummary {
  final int totalPaidVnd;
  final int monthPaidVnd;
  final int pendingVnd;
  final int walletBalanceVnd;
  final int jobCount;
  final int hoursWorked;
  final double avgRating;

  const CandidateEarningsSummary({
    required this.totalPaidVnd,
    this.monthPaidVnd = 0,
    required this.pendingVnd,
    this.walletBalanceVnd = 0,
    required this.jobCount,
    required this.hoursWorked,
    required this.avgRating,
  });

  String formatVnd(int v) {
    final s = v.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return '$sđ';
  }
}
