class JobCriteriaModel {
  final bool hasExperience;
  final String position;
  final List<String> careers;
  final List<String> locations;
  final double? salaryMin;
  final double? salaryMax;
  final bool salaryNegotiable;
  final String? salary;
  final List<String> workTypes;
  final String? level;

  const JobCriteriaModel({
    this.hasExperience = false,
    this.position = '',
    this.careers = const [],
    this.locations = const [],
    this.salaryMin,
    this.salaryMax,
    this.salaryNegotiable = false,
    this.salary,
    this.workTypes = const [],
    this.level,
  });

  String? get salaryDisplay {
    if (salaryNegotiable) return 'Lương thỏa thuận';
    if (salaryMin != null && salaryMax != null) {
      return '${_formatNum(salaryMin!)} - ${_formatNum(salaryMax!)} triệu';
    }
    if (salaryMin != null) return 'Từ ${_formatNum(salaryMin!)} triệu';
    if (salaryMax != null) return 'Đến ${_formatNum(salaryMax!)} triệu';
    if (salary != null && salary!.trim().isNotEmpty) return salary;
    return null;
  }

  static String formatSalaryNum(double v) {
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  static String _formatNum(double v) => formatSalaryNum(v);

  bool get hasData =>
      position.trim().isNotEmpty ||
      careers.isNotEmpty ||
      locations.isNotEmpty ||
      salaryDisplay != null ||
      workTypes.isNotEmpty ||
      (level != null && level!.isNotEmpty);

  Map<String, dynamic> toMap() {
    return {
      'hasExperience': hasExperience,
      'position': position.trim(),
      'careers': careers,
      'locations': locations,
      if (salaryMin != null) 'salaryMin': salaryMin,
      if (salaryMax != null) 'salaryMax': salaryMax,
      'salaryNegotiable': salaryNegotiable,
      if (salaryDisplay != null) 'salary': salaryDisplay,
      'workTypes': workTypes,
      if (level != null && level!.isNotEmpty) 'level': level,
    };
  }

  factory JobCriteriaModel.fromMap(Map<String, dynamic> map) {
    return JobCriteriaModel(
      hasExperience: (map['hasExperience'] as bool?) ?? false,
      position: (map['position'] ?? '').toString(),
      careers: _parseStringList(map['careers'], map['career']),
      locations: _parseStringList(map['locations'], map['location']),
      salaryMin: _parseDouble(map['salaryMin']),
      salaryMax: _parseDouble(map['salaryMax']),
      salaryNegotiable: (map['salaryNegotiable'] as bool?) ?? false,
      salary: map['salary']?.toString(),
      workTypes: _parseStringList(map['workTypes'], map['workType']),
      level: map['level']?.toString(),
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static List<String> _parseStringList(dynamic listValue, dynamic legacyValue) {
    if (listValue is List) {
      return listValue
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (legacyValue != null && legacyValue.toString().trim().isNotEmpty) {
      return [legacyValue.toString().trim()];
    }
    return [];
  }

  static JobCriteriaModel? fromUserData(Map<String, dynamic> data) {
    final raw = data['jobCriteria'];
    if (raw is! Map) return null;
    final model = JobCriteriaModel.fromMap(Map<String, dynamic>.from(raw));
    return model.hasData ? model : null;
  }
}
