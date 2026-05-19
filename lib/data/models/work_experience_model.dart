class WorkExperienceModel {
  final String id;
  final String company;
  final String position;
  final String description;
  final String startDate;
  final String? endDate;
  final bool currentlyWorking;

  const WorkExperienceModel({
    required this.id,
    required this.company,
    required this.position,
    required this.description,
    required this.startDate,
    this.endDate,
    this.currentlyWorking = false,
  });

  String get dateRange {
    if (currentlyWorking) {
      return '$startDate - Hiện tại';
    }
    if (endDate != null && endDate!.isNotEmpty) {
      return '$startDate - $endDate';
    }
    return startDate;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'company': company,
      'position': position,
      'description': description,
      'startDate': startDate,
      'endDate': endDate,
      'currentlyWorking': currentlyWorking,
    };
  }

  factory WorkExperienceModel.fromMap(Map<String, dynamic> map) {
    return WorkExperienceModel(
      id: (map['id'] ?? '').toString(),
      company: (map['company'] ?? '').toString(),
      position: (map['position'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      startDate: (map['startDate'] ?? '').toString(),
      endDate: map['endDate']?.toString(),
      currentlyWorking: (map['currentlyWorking'] as bool?) ?? false,
    );
  }

  static List<WorkExperienceModel> listFromUserData(
    Map<String, dynamic> data,
  ) {
    final raw = data['workExperiences'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => WorkExperienceModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Người dùng đã chọn "Chưa có" kinh nghiệm làm việc trên hồ sơ.
  static bool hasDeclaredNoExperience(Map<String, dynamic> data) {
    return data['hasWorkExperience'] == false;
  }
}
