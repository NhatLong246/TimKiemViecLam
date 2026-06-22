import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/job_categories.dart' as job_cats;
import 'full_time_job_details.dart';

class JobPostModel {
  final String jobId;
  final String employerId;
  final String title;
  final String description;
  final String category;
  final String? customCategory;
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
  final List<Map<String, dynamic>> candidateRequirements;
  final String
  status; // "draft"|"pending"|"approved"|"active"|"closed"|"rejected"|"cancelled"|"deleted"
  final double totalBudget;
  final String depositStatus; // "none"|"held"|"refunded"|"released"
  final String? depositTransactionId;
  final DateTime? depositHeldAt;
  final DateTime? depositRefundedAt;
  final DateTime? depositReleasedAt;
  final double? depositRefundAmount;
  final double? depositCompensationAmount;
  final Map<String, dynamic>? depositCalculation;
  final String? groupChatId;
  final List<String> imageUrls;
  final FullTimeJobDetails? fullTimeDetails;
  final String? requiredLanguage;
  final String? requiredLanguageLevel;
  final String? requiredExperience;
  final DateTime? applicationDeadline;
  final bool underfilledAccepted;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? closedAt;

  JobPostModel({
    required this.jobId,
    required this.employerId,
    required this.title,
    required this.description,
    required this.category,
    this.customCategory,
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
    this.candidateRequirements = const [],
    required this.status,
    required this.totalBudget,
    this.depositStatus = 'none',
    this.depositTransactionId,
    this.depositHeldAt,
    this.depositRefundedAt,
    this.depositReleasedAt,
    this.depositRefundAmount,
    this.depositCompensationAmount,
    this.depositCalculation,
    this.groupChatId,
    this.imageUrls = const [],
    this.fullTimeDetails,
    this.requiredLanguage,
    this.requiredLanguageLevel,
    this.requiredExperience,
    this.applicationDeadline,
    this.underfilledAccepted = false,
    this.createdAt,
    this.updatedAt,
    this.closedAt,
  });

  int get remainingSlots => (slots - filledSlots).clamp(0, slots);
  bool get isFull => remainingSlots == 0;

  /// Yêu cầu có cấu trúc dùng để kiểm tra điều kiện ứng tuyển.
  ///
  /// Các bài đăng cũ chưa có `candidateRequirements` vẫn được bảo vệ bằng
  /// những trường yêu cầu riêng đã lưu từ phiên bản trước.
  List<Map<String, dynamic>> get effectiveCandidateRequirements {
    final effective = candidateRequirements
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final availableTypes = effective
        .map((item) => item['type']?.toString() ?? '')
        .toSet();
    final language = requiredLanguage?.trim() ?? '';
    var languageMinimum = requiredLanguageLevel?.trim() ?? '';
    if (!availableTypes.contains('languages') &&
        language.isNotEmpty &&
        language != 'Tất cả' &&
        languageMinimum.isNotEmpty &&
        languageMinimum != 'Tất cả') {
      var levelType = language == 'Tiếng Anh' ? 'CEFR' : 'certificate';
      final scoreMatch = RegExp(
        r'^(IELTS|TOEIC)\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(languageMinimum);
      if (scoreMatch != null) {
        levelType = scoreMatch.group(1)!.toUpperCase();
        languageMinimum = scoreMatch.group(2)!.trim();
      }
      effective.add({
        'type': 'languages',
        'language': language,
        'levelType': levelType,
        'minimum': languageMinimum,
      });
    }

    final minimumEducation = fullTimeDetails?.minEducation?.trim() ?? '';
    if (!availableTypes.contains('education') &&
        minimumEducation.isNotEmpty &&
        minimumEducation != 'none') {
      effective.add({
        'type': 'education',
        'minimum': minimumEducation,
      });
    }

    final experience = requiredExperience?.trim() ?? '';
    if (!availableTypes.contains('experience') &&
        experience.isNotEmpty &&
        experience != 'Tất cả' &&
        experience != 'no_exp' &&
        experience != 'none') {
      effective.add({'type': 'experience', 'minimum': experience});
    }
    return List<Map<String, dynamic>>.unmodifiable(effective);
  }

  /// Part-time: ViecNow quản lý điểm danh, giải ngân… Full-time: chỉ giới thiệu tin.
  bool get isPartTimeManaged => jobType == 'part_time';
  bool get isFullTimeReferral => jobType == 'full_time';

  /// Tính thời gian kết thúc chính xác của ca làm cuối cùng (hỗ trợ ca qua đêm)
  DateTime get exactEndTime {
    if (endDate == null) return DateTime(2099);
    var end = DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59);
    if (startTime != null && startTime!.isNotEmpty && workHoursPerDay != null) {
      final parts = startTime!.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final startDt = DateTime(endDate!.year, endDate!.month, endDate!.day, h, m);
        final minutesToAdd = (workHoursPerDay! * 60).toInt();
        end = startDt.add(Duration(minutes: minutesToAdd));
      }
    }
    return end;
  }

  String get locationDisplay {
    final district = location['district'] as String? ?? '';
    final city = location['city'] as String? ?? '';
    if (district.isNotEmpty && city.isNotEmpty) return '$district, $city';
    return city.isNotEmpty ? city : (location['address'] as String? ?? '');
  }

  String get fullLocationDisplay {
    final address = (location['address'] as String?)?.trim() ?? '';
    final district = (location['district'] as String?)?.trim() ?? '';
    final city = (location['city'] as String?)?.trim() ?? '';
    
    final parts = [address, district, city].where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'Chưa có địa điểm';
    return parts.join(', ');
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
    DateTime toDateTime(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.now();
    }

    final rawDepositCalculation = map['depositCalculation'];

    return JobPostModel(
      jobId: map['jobId'] as String? ?? '',
      employerId: map['employerId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? '',
      customCategory: map['customCategory'] as String?,
      jobType: map['jobType'] as String? ?? 'part_time',
      location: (map['location'] as Map<String, dynamic>?) ?? {},
      salary: (map['salary'] as num?)?.toDouble() ?? 0,
      salaryType: map['salaryType'] as String? ?? 'per_day',
      slots: (map['slots'] as num?)?.toInt() ?? 1,
      filledSlots: (map['filledSlots'] as num?)?.toInt() ?? 0,
      startDate: toDateTime(map['startDate']),
      endDate: map['endDate'] != null ? toDateTime(map['endDate']) : null,
      workHoursPerDay: (map['workHoursPerDay'] as num?)?.toDouble(),
      startTime: map['startTime'] as String?,
      requirements: map['requirements'] as String?,
      candidateRequirements: (map['candidateRequirements'] as List?)
              ?.whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList() ??
          const [],
      status: map['status'] as String? ?? 'draft',
      totalBudget: (map['totalBudget'] as num?)?.toDouble() ?? 0,
      depositStatus: map['depositStatus'] as String? ?? 'none',
      depositTransactionId: map['depositTransactionId'] as String?,
      depositHeldAt: map['depositHeldAt'] != null
          ? toDateTime(map['depositHeldAt'])
          : null,
      depositRefundedAt: map['depositRefundedAt'] != null
          ? toDateTime(map['depositRefundedAt'])
          : null,
      depositReleasedAt: map['depositReleasedAt'] != null
          ? toDateTime(map['depositReleasedAt'])
          : null,
      depositRefundAmount: (map['depositRefundAmount'] as num?)?.toDouble(),
      depositCompensationAmount: (map['depositCompensationAmount'] as num?)
          ?.toDouble(),
      depositCalculation: rawDepositCalculation is Map
          ? Map<String, dynamic>.from(rawDepositCalculation)
          : null,
      groupChatId: map['groupChatId'] as String?,
      imageUrls:
          (map['imageUrls'] as List?)
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          const [],
      fullTimeDetails: map['fullTimeDetails'] != null
          ? FullTimeJobDetails.fromMap(
              map['fullTimeDetails'] as Map<String, dynamic>,
            )
          : null,
      requiredLanguage: map['requiredLanguage'] as String?,
      requiredLanguageLevel: map['requiredLanguageLevel'] as String?,
      requiredExperience: map['requiredExperience'] as String?,
      applicationDeadline: map['applicationDeadline'] != null
          ? toDateTime(map['applicationDeadline'])
          : null,
      underfilledAccepted: map['underfilledAccepted'] == true,
      createdAt: map['createdAt'] != null ? toDateTime(map['createdAt']) : null,
      updatedAt: map['updatedAt'] != null ? toDateTime(map['updatedAt']) : null,
      closedAt: map['closedAt'] != null ? toDateTime(map['closedAt']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'jobId': jobId,
      'employerId': employerId,
      'title': title,
      'description': description,
      'category': category,
      'customCategory': customCategory?.trim(),
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
      'requirements': requirements,
      'candidateRequirements': candidateRequirements,
      'status': status,
      'totalBudget': totalBudget,
      'depositStatus': depositStatus,
      if (depositTransactionId != null)
        'depositTransactionId': depositTransactionId,
      if (depositHeldAt != null)
        'depositHeldAt': Timestamp.fromDate(depositHeldAt!),
      if (depositRefundedAt != null)
        'depositRefundedAt': Timestamp.fromDate(depositRefundedAt!),
      if (depositReleasedAt != null)
        'depositReleasedAt': Timestamp.fromDate(depositReleasedAt!),
      if (depositRefundAmount != null)
        'depositRefundAmount': depositRefundAmount,
      if (depositCompensationAmount != null)
        'depositCompensationAmount': depositCompensationAmount,
      if (depositCalculation != null) 'depositCalculation': depositCalculation,
      if (groupChatId != null) 'groupChatId': groupChatId,
      if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
      if (fullTimeDetails != null) 'fullTimeDetails': fullTimeDetails!.toMap(),
      if (requiredLanguage != null) 'requiredLanguage': requiredLanguage,
      if (requiredLanguageLevel != null) 'requiredLanguageLevel': requiredLanguageLevel,
      if (requiredExperience != null) 'requiredExperience': requiredExperience,
      if (applicationDeadline != null)
        'applicationDeadline': Timestamp.fromDate(applicationDeadline!),
      'underfilledAccepted': underfilledAccepted,
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
    String? customCategory,
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
    List<Map<String, dynamic>>? candidateRequirements,
    String? status,
    double? totalBudget,
    String? depositStatus,
    String? depositTransactionId,
    DateTime? depositHeldAt,
    DateTime? depositRefundedAt,
    DateTime? depositReleasedAt,
    double? depositRefundAmount,
    double? depositCompensationAmount,
    Map<String, dynamic>? depositCalculation,
    String? groupChatId,
    List<String>? imageUrls,
    FullTimeJobDetails? fullTimeDetails,
    String? requiredLanguage,
    String? requiredLanguageLevel,
    String? requiredExperience,
    DateTime? applicationDeadline,
    bool? underfilledAccepted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JobPostModel(
      jobId: jobId ?? this.jobId,
      employerId: employerId ?? this.employerId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      customCategory: customCategory ?? this.customCategory,
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
      candidateRequirements:
          candidateRequirements ?? this.candidateRequirements,
      status: status ?? this.status,
      totalBudget: totalBudget ?? this.totalBudget,
      depositStatus: depositStatus ?? this.depositStatus,
      depositTransactionId: depositTransactionId ?? this.depositTransactionId,
      depositHeldAt: depositHeldAt ?? this.depositHeldAt,
      depositRefundedAt: depositRefundedAt ?? this.depositRefundedAt,
      depositReleasedAt: depositReleasedAt ?? this.depositReleasedAt,
      depositRefundAmount: depositRefundAmount ?? this.depositRefundAmount,
      depositCompensationAmount:
          depositCompensationAmount ?? this.depositCompensationAmount,
      depositCalculation: depositCalculation ?? this.depositCalculation,
      groupChatId: groupChatId ?? this.groupChatId,
      imageUrls: imageUrls ?? this.imageUrls,
      fullTimeDetails: fullTimeDetails ?? this.fullTimeDetails,
      requiredLanguage: requiredLanguage ?? this.requiredLanguage,
      requiredLanguageLevel: requiredLanguageLevel ?? this.requiredLanguageLevel,
      requiredExperience: requiredExperience ?? this.requiredExperience,
      applicationDeadline: applicationDeadline ?? this.applicationDeadline,
      underfilledAccepted: underfilledAccepted ?? this.underfilledAccepted,
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
  static String categoryLabel(String category) =>
      job_cats.categoryLabel(category);

  /// Tên danh mục thực tế, gồm cả giá trị doanh nghiệp tự nhập khi chọn Khác.
  String get categoryDisplay {
    final custom = customCategory?.trim() ?? '';
    if (category == 'other' && custom.isNotEmpty) return custom;
    return categoryLabel(category);
  }
}
