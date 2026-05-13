import 'package:cloud_firestore/cloud_firestore.dart';

class JobPostModel {
  final String jobId;
  final String employerId;
  final String title;
  final String description;
  final String category;
  final String jobType; // "part_time" | "full_time"
  final Map<String, dynamic> location; // {address, city, district, lat, lng}
  final double salary;
  final String salaryType; // "per_day" | "per_hour" | "per_month" | "fixed"
  final int slots;
  final int filledSlots;
  final DateTime startDate;
  final DateTime? endDate;
  final double? workHoursPerDay;
  final String? startTime; // "HH:mm"
  final String? requirements;
  final String status; // "draft"|"pending"|"approved"|"active"|"closed"|"rejected"
  final double totalBudget;
  final String? groupChatId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  JobPostModel({
    required this.jobId,
    required this.employerId,
    required this.title,
    required this.description,
    required this.category,
    required this.jobType,
    required this.location,
    required this.salary,
    required this.salaryType,
    required this.slots,
    this.filledSlots = 0,
    required this.startDate,
    this.endDate,
    this.workHoursPerDay,
    this.startTime,
    this.requirements,
    required this.status,
    required this.totalBudget,
    this.groupChatId,
    this.createdAt,
    this.updatedAt,
  });

  factory JobPostModel.fromMap(Map<String, dynamic> map) {
    DateTime _toDateTime(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.now();
    }

    return JobPostModel(
      jobId: map['jobId'] as String? ?? '',
      employerId: map['employerId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? '',
      jobType: map['jobType'] as String? ?? 'part_time',
      location: (map['location'] as Map<String, dynamic>?) ?? {},
      salary: (map['salary'] as num?)?.toDouble() ?? 0,
      salaryType: map['salaryType'] as String? ?? 'per_day',
      slots: (map['slots'] as num?)?.toInt() ?? 1,
      filledSlots: (map['filledSlots'] as num?)?.toInt() ?? 0,
      startDate: _toDateTime(map['startDate']),
      endDate: map['endDate'] != null ? _toDateTime(map['endDate']) : null,
      workHoursPerDay: (map['workHoursPerDay'] as num?)?.toDouble(),
      startTime: map['startTime'] as String?,
      requirements: map['requirements'] as String?,
      status: map['status'] as String? ?? 'draft',
      totalBudget: (map['totalBudget'] as num?)?.toDouble() ?? 0,
      groupChatId: map['groupChatId'] as String?,
      createdAt: map['createdAt'] != null ? _toDateTime(map['createdAt']) : null,
      updatedAt: map['updatedAt'] != null ? _toDateTime(map['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'jobId': jobId,
      'employerId': employerId,
      'title': title,
      'description': description,
      'category': category,
      'jobType': jobType,
      'location': location,
      'salary': salary,
      'salaryType': salaryType,
      'slots': slots,
      'filledSlots': filledSlots,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'workHoursPerDay': workHoursPerDay,
      'startTime': startTime,
      'requirements': requirements,
      'status': status,
      'totalBudget': totalBudget,
      'groupChatId': groupChatId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  JobPostModel copyWith({
    String? status,
    String? groupChatId,
    int? filledSlots,
  }) {
    return JobPostModel(
      jobId: jobId,
      employerId: employerId,
      title: title,
      description: description,
      category: category,
      jobType: jobType,
      location: location,
      salary: salary,
      salaryType: salaryType,
      slots: slots,
      filledSlots: filledSlots ?? this.filledSlots,
      startDate: startDate,
      endDate: endDate,
      workHoursPerDay: workHoursPerDay,
      startTime: startTime,
      requirements: requirements,
      status: status ?? this.status,
      totalBudget: totalBudget,
      groupChatId: groupChatId ?? this.groupChatId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Nhãn hiển thị cho salaryType
  String get salaryTypeLabel {
    switch (salaryType) {
      case 'per_day':
        return '/ngày';
      case 'per_hour':
        return '/giờ';
      case 'per_month':
        return '/tháng';
      default:
        return '';
    }
  }

  /// Nhãn hiển thị cho category
  static String categoryLabel(String category) {
    const map = {
      'boc_vac': 'Bốc vác',
      'lau_don': 'Lau dọn',
      'bung_be': 'Bưng bê',
      'phuc_vu': 'Phục vụ',
      'pha_che': 'Pha chế',
      'tiep_thi': 'Tiếp thị',
      'van_chuyen': 'Vận chuyển',
      'bao_ve': 'Bảo vệ',
      'other': 'Khác',
    };
    return map[category] ?? category;
  }
}
