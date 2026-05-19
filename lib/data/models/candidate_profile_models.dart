class EducationModel {
  final String id;
  final String school;
  final String startYear;
  final String endYear;
  final String major;
  final String degree;
  final String description;

  const EducationModel({
    required this.id,
    required this.school,
    required this.startYear,
    required this.endYear,
    this.major = '',
    this.degree = '',
    this.description = '',
  });

  String get yearRange => '$startYear - $endYear';

  Map<String, dynamic> toMap() => {
        'id': id,
        'school': school,
        'startYear': startYear,
        'endYear': endYear,
        'major': major,
        'degree': degree,
        'description': description,
      };

  factory EducationModel.fromMap(Map<String, dynamic> map) {
    return EducationModel(
      id: (map['id'] ?? '').toString(),
      school: (map['school'] ?? '').toString(),
      startYear: (map['startYear'] ?? '').toString(),
      endYear: (map['endYear'] ?? '').toString(),
      major: (map['major'] ?? '').toString(),
      degree: (map['degree'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
    );
  }

  static List<EducationModel> listFromUserData(Map<String, dynamic> data) {
    return _listFromField(data, 'educations', EducationModel.fromMap);
  }
}

class ProjectModel {
  final String id;
  final String name;
  final String startDate;
  final String endDate;
  final String description;

  const ProjectModel({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.description = '',
  });

  String get dateRange => '$startDate - $endDate';

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'startDate': startDate,
        'endDate': endDate,
        'description': description,
      };

  factory ProjectModel.fromMap(Map<String, dynamic> map) {
    return ProjectModel(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      startDate: (map['startDate'] ?? '').toString(),
      endDate: (map['endDate'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
    );
  }

  static List<ProjectModel> listFromUserData(Map<String, dynamic> data) {
    return _listFromField(data, 'projects', ProjectModel.fromMap);
  }
}

class CertificateModel {
  final String id;
  final String name;
  final String? imageUrl;

  const CertificateModel({
    required this.id,
    required this.name,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
      };

  factory CertificateModel.fromMap(Map<String, dynamic> map) {
    return CertificateModel(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      imageUrl: map['imageUrl']?.toString(),
    );
  }

  static List<CertificateModel> listFromUserData(Map<String, dynamic> data) {
    return _listFromField(data, 'certificates', CertificateModel.fromMap);
  }
}

class LanguageModel {
  final String id;
  final String language;
  final String level;

  const LanguageModel({
    required this.id,
    required this.language,
    required this.level,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'language': language,
        'level': level,
      };

  factory LanguageModel.fromMap(Map<String, dynamic> map) {
    return LanguageModel(
      id: (map['id'] ?? '').toString(),
      language: (map['language'] ?? '').toString(),
      level: (map['level'] ?? '').toString(),
    );
  }

  static List<LanguageModel> listFromUserData(Map<String, dynamic> data) {
    return _listFromField(data, 'languages', LanguageModel.fromMap);
  }
}

List<T> _listFromField<T>(
  Map<String, dynamic> data,
  String field,
  T Function(Map<String, dynamic>) fromMap,
) {
  final raw = data[field];
  if (raw is! List) return [];
  return raw
      .whereType<Map>()
      .map((e) => fromMap(Map<String, dynamic>.from(e)))
      .toList();
}

List<String> skillsFromUserData(Map<String, dynamic> data) {
  final raw = data['skills'];
  if (raw is! List) return [];
  return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
}

String selfIntroductionFromUserData(Map<String, dynamic> data) {
  return (data['selfIntroduction'] ?? '').toString().trim();
}
