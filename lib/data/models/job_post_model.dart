import 'package:cloud_firestore/cloud_firestore.dart';

class JobPostModel {
  final String jobId;
  final String employerId;
  final String title;
  final String description;
  final String category;
  final String jobType; // "part_time" | "full_time"
  final Map<String, dynamic> location;
  final double salary;
  final String salaryType; // "per_day" | "per_hour" | "per_month" | "fixed"
  final int slots;
  final int filledSlots;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? workHoursPerDay;
  final String? startTime;
  final String? requirements;
  final String status; // "pending"|"approved"|"active"|"closed"|"rejected"
  final String? groupChatId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const JobPostModel({
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
    this.startDate,
    this.endDate,
    this.workHoursPerDay,
    this.startTime,
    this.requirements,
    required this.status,
    this.groupChatId,
    this.createdAt,
    this.updatedAt,
  });

  int get remainingSlots => (slots - filledSlots).clamp(0, slots);
  bool get isFull => remainingSlots == 0;

  String get locationDisplay {
    final district = location['district'] as String? ?? '';
    final city = location['city'] as String? ?? '';
    if (district.isNotEmpty && city.isNotEmpty) return '$district, $city';
    return city.isNotEmpty ? city : (location['address'] as String? ?? '');
  }

  String get salaryDisplay {
    final s = salary.toStringAsFixed(salary.truncateToDouble() == salary ? 0 : 0);
    final formatted = _formatNumber(salary.toInt());
    switch (salaryType) {
      case 'per_hour':
        return '$formatted₫/giờ';
      case 'per_day':
        return '$formatted₫/ngày';
      case 'per_month':
        return '$formatted₫/tháng';
      default:
        return '$formatted₫';
    }
  }

  static String _formatNumber(int n) {
    final s = n.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  JobPostModel copyWith({
    String? jobId,
    String? employerId,
    String? title,
    String? description,
    String? category,
    String? jobType,
    Map<String, dynamic>? location,
    double? salary,
    String? salaryType,
    int? slots,
    int? filledSlots,
    DateTime? startDate,
    DateTime? endDate,
    double? workHoursPerDay,
    String? startTime,
    String? requirements,
    String? status,
    String? groupChatId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JobPostModel(
      jobId: jobId ?? this.jobId,
      employerId: employerId ?? this.employerId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      jobType: jobType ?? this.jobType,
      location: location ?? this.location,
      salary: salary ?? this.salary,
      salaryType: salaryType ?? this.salaryType,
      slots: slots ?? this.slots,
      filledSlots: filledSlots ?? this.filledSlots,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      workHoursPerDay: workHoursPerDay ?? this.workHoursPerDay,
      startTime: startTime ?? this.startTime,
      requirements: requirements ?? this.requirements,
      status: status ?? this.status,
      groupChatId: groupChatId ?? this.groupChatId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory JobPostModel.fromMap(Map<String, dynamic> map) {
    return JobPostModel(
      jobId: map['jobId'] as String? ?? '',
      employerId: map['employerId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? '',
      jobType: map['jobType'] as String? ?? 'part_time',
      location: (map['location'] as Map<String, dynamic>?) ?? {},
      salary: (map['salary'] as num?)?.toDouble() ?? 0.0,
      salaryType: map['salaryType'] as String? ?? 'per_day',
      slots: (map['slots'] as int?) ?? 1,
      filledSlots: (map['filledSlots'] as int?) ?? 0,
      startDate: (map['startDate'] as Timestamp?)?.toDate(),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      workHoursPerDay: (map['workHoursPerDay'] as num?)?.toDouble(),
      startTime: map['startTime'] as String?,
      requirements: map['requirements'] as String?,
      status: map['status'] as String? ?? 'pending',
      groupChatId: map['groupChatId'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
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
      if (startDate != null) 'startDate': Timestamp.fromDate(startDate!),
      if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
      if (workHoursPerDay != null) 'workHoursPerDay': workHoursPerDay,
      if (startTime != null) 'startTime': startTime,
      if (requirements != null) 'requirements': requirements,
      'status': status,
      if (groupChatId != null) 'groupChatId': groupChatId,
    };
  }
}
