class FullTimeJobDetails {
  final bool requiresCv;
  final bool interviewRequired;
  final int payDayOfMonth;
  final List<String> workingDays;
  final String workShift;
  final int? probationDays;
  final String? minEducation;
  final String? minExperience;
  final String? benefits;

  const FullTimeJobDetails({
    this.requiresCv = true,
    this.interviewRequired = true,
    required this.payDayOfMonth,
    this.workingDays = const ['mon', 'tue', 'wed', 'thu', 'fri'],
    this.workShift = 'flexible',
    this.probationDays,
    this.minEducation,
    this.minExperience,
    this.benefits,
  });

  static const weekdayOptions = [
    {'value': 'mon', 'label': 'T2'},
    {'value': 'tue', 'label': 'T3'},
    {'value': 'wed', 'label': 'T4'},
    {'value': 'thu', 'label': 'T5'},
    {'value': 'fri', 'label': 'T6'},
    {'value': 'sat', 'label': 'T7'},
    {'value': 'sun', 'label': 'CN'},
  ];

  static const educationOptions = [
    {'value': 'none', 'label': 'Không yêu cầu'},
    {'value': 'high_school', 'label': 'THPT trở lên'},
    {'value': 'college', 'label': 'Cao đẳng trở lên'},
    {'value': 'university', 'label': 'Đại học trở lên'},
  ];

  static const experienceOptions = [
    {'value': 'none', 'label': 'Không yêu cầu'},
    {'value': 'under_1', 'label': 'Dưới 1 năm'},
    {'value': '1_2', 'label': '1–2 năm'},
    {'value': '2_5', 'label': '2–5 năm'},
    {'value': 'over_5', 'label': 'Trên 5 năm'},
  ];

  static const shiftOptions = [
    {'value': 'morning', 'label': 'Ca sáng'},
    {'value': 'afternoon', 'label': 'Ca chiều'},
    {'value': 'night', 'label': 'Ca đêm'},
    {'value': 'flexible', 'label': 'Linh hoạt'},
  ];

  static String weekdayLabel(String value) {
    return weekdayOptions
            .cast<Map<String, String>>()
            .firstWhere((e) => e['value'] == value,
                orElse: () => {'value': value, 'label': value})['label'] ??
        value;
  }

  static String educationLabel(String? value) {
    if (value == null || value.isEmpty) return 'Không yêu cầu';
    return educationOptions
            .cast<Map<String, String>>()
            .firstWhere((e) => e['value'] == value,
                orElse: () => {'value': value, 'label': value})['label'] ??
        value;
  }

  static String experienceLabel(String? value) {
    if (value == null || value.isEmpty) return 'Không yêu cầu';
    return experienceOptions
            .cast<Map<String, String>>()
            .firstWhere((e) => e['value'] == value,
                orElse: () => {'value': value, 'label': value})['label'] ??
        value;
  }

  static String shiftLabel(String? value) {
    if (value == null || value.isEmpty) return 'Linh hoạt';
    return shiftOptions
            .cast<Map<String, String>>()
            .firstWhere((e) => e['value'] == value,
                orElse: () => {'value': value, 'label': value})['label'] ??
        value;
  }

  factory FullTimeJobDetails.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) {
      return const FullTimeJobDetails(payDayOfMonth: 5);
    }
    return FullTimeJobDetails(
      requiresCv: map['requiresCv'] as bool? ?? true,
      interviewRequired: map['interviewRequired'] as bool? ?? true,
      payDayOfMonth: (map['payDayOfMonth'] as num?)?.toInt() ?? 5,
      workingDays: (map['workingDays'] as List?)
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          const ['mon', 'tue', 'wed', 'thu', 'fri'],
      workShift: map['workShift'] as String? ?? 'flexible',
      probationDays: (map['probationDays'] as num?)?.toInt(),
      minEducation: map['minEducation'] as String?,
      minExperience: map['minExperience'] as String?,
      benefits: map['benefits'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requiresCv': requiresCv,
      'interviewRequired': interviewRequired,
      'payDayOfMonth': payDayOfMonth,
      'workingDays': workingDays,
      'workShift': workShift,
      if (probationDays != null) 'probationDays': probationDays,
      if (minEducation != null && minEducation!.isNotEmpty)
        'minEducation': minEducation,
      if (minExperience != null && minExperience!.isNotEmpty)
        'minExperience': minExperience,
      if (benefits != null && benefits!.isNotEmpty) 'benefits': benefits,
    };
  }

  FullTimeJobDetails copyWith({
    bool? requiresCv,
    bool? interviewRequired,
    int? payDayOfMonth,
    List<String>? workingDays,
    String? workShift,
    int? probationDays,
    String? minEducation,
    String? minExperience,
    String? benefits,
  }) {
    return FullTimeJobDetails(
      requiresCv: requiresCv ?? this.requiresCv,
      interviewRequired: interviewRequired ?? this.interviewRequired,
      payDayOfMonth: payDayOfMonth ?? this.payDayOfMonth,
      workingDays: workingDays ?? this.workingDays,
      workShift: workShift ?? this.workShift,
      probationDays: probationDays ?? this.probationDays,
      minEducation: minEducation ?? this.minEducation,
      minExperience: minExperience ?? this.minExperience,
      benefits: benefits ?? this.benefits,
    );
  }
}
