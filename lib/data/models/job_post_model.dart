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

  int get remainingSlots => (slots - filledSlots).clamp(0, slots);
  bool get isFull => remainingSlots == 0;

  String get locationDisplay {
    final district = location['district'] as String? ?? '';
    final city = location['city'] as String? ?? '';
    if (district.isNotEmpty && city.isNotEmpty) return '$district, $city';
    return city.isNotEmpty ? city : (location['address'] as String? ?? '');
  }

  double? get locationLat => (location['lat'] as num?)?.toDouble();

  double? get locationLng => (location['lng'] as num?)?.toDouble();

  /// Tọa độ hợp lệ từ Firestore (`location.lat` / `location.lng`).
  bool get hasMapCoordinates {
    final lat = locationLat;
    final lng = locationLng;
    if (lat == null || lng == null) return false;
    if (lat.abs() < 1e-6 && lng.abs() < 1e-6) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  /// Chuỗi đích cho Google Maps khi không có tọa độ.
  String get mapsDestinationQuery {
    final address = (location['address'] as String?)?.trim() ?? '';
    if (address.isNotEmpty) return address;
    final display = locationDisplay.trim();
    if (display.isNotEmpty) return display;
    return title;
  }

  String get salaryDisplay {
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
      if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
      if (workHoursPerDay != null) 'workHoursPerDay': workHoursPerDay,
      if (startTime != null) 'startTime': startTime,
      if (requirements != null) 'requirements': requirements,
      'status': status,
      'totalBudget': totalBudget,
      if (groupChatId != null) 'groupChatId': groupChatId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
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
    double? totalBudget,
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
      totalBudget: totalBudget ?? this.totalBudget,
      groupChatId: groupChatId ?? this.groupChatId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
