import '../constants/language_proficiency_levels.dart';

class CandidateEligibilityIssue {
  final String type;
  final String message;

  const CandidateEligibilityIssue({
    required this.type,
    required this.message,
  });
}

class CandidateEligibilityResult {
  final List<CandidateEligibilityIssue> issues;

  const CandidateEligibilityResult(this.issues);

  bool get isEligible => issues.isEmpty;

  String get userMessage {
    if (isEligible) return '';
    final details = issues.map((issue) => '• ${issue.message}').join('\n');
    return 'Bạn chưa đáp ứng đủ điều kiện ứng tuyển:\n$details\n'
        'Vui lòng cập nhật hồ sơ rồi thử lại.';
  }
}

class CandidateEligibilityException implements Exception {
  final CandidateEligibilityResult result;

  const CandidateEligibilityException(this.result);

  @override
  String toString() => result.userMessage;
}

/// Đối chiếu các yêu cầu có cấu trúc của bài đăng với hồ sơ ứng viên.
///
/// Yêu cầu `other` là văn bản tham khảo cho nhà tuyển dụng nên không được dùng
/// để tự động chặn ứng viên. Các loại yêu cầu có cấu trúc khác đều phải đạt.
class CandidateEligibilityService {
  CandidateEligibilityService._();

  static CandidateEligibilityResult evaluate({
    required Map<String, dynamic> candidateData,
    required List<Map<String, dynamic>> requirements,
    DateTime? now,
  }) {
    final issues = <CandidateEligibilityIssue>[];
    for (final requirement in requirements) {
      final type = requirement['type']?.toString().trim() ?? '';
      switch (type) {
        case 'skills':
          _checkNamedItems(
            type: type,
            label: 'Kỹ năng',
            requiredValues: _stringList(requirement['values']),
            candidateValues: _candidateSkills(candidateData),
            issues: issues,
          );
          break;
        case 'certificates':
          _checkNamedItems(
            type: type,
            label: 'Chứng chỉ',
            requiredValues: _stringList(requirement['values']),
            candidateValues: _candidateCertificateNames(candidateData),
            issues: issues,
          );
          break;
        case 'languages':
          _checkLanguage(candidateData, requirement, issues);
          break;
        case 'gender':
          _checkGender(candidateData, requirement, issues);
          break;
        case 'education':
          _checkEducation(candidateData, requirement, issues);
          break;
        case 'experience':
          _checkExperience(
            candidateData,
            requirement,
            issues,
            now ?? DateTime.now(),
          );
          break;
        case 'other':
        case '':
          break;
        default:
          issues.add(
            CandidateEligibilityIssue(
              type: type,
              message:
                  'Hồ sơ chưa thể xác minh yêu cầu "${_requirementLabel(requirement)}".',
            ),
          );
      }
    }
    return CandidateEligibilityResult(
      List<CandidateEligibilityIssue>.unmodifiable(issues),
    );
  }

  static void ensureEligible({
    required Map<String, dynamic> candidateData,
    required List<Map<String, dynamic>> requirements,
    DateTime? now,
  }) {
    final result = evaluate(
      candidateData: candidateData,
      requirements: requirements,
      now: now,
    );
    if (!result.isEligible) throw CandidateEligibilityException(result);
  }

  static void _checkNamedItems({
    required String type,
    required String label,
    required List<String> requiredValues,
    required List<String> candidateValues,
    required List<CandidateEligibilityIssue> issues,
  }) {
    if (requiredValues.isEmpty) return;
    final available = candidateValues
        .map(_normalize)
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final missing = requiredValues
        .where((item) {
          final required = _normalize(item);
          return required.isNotEmpty &&
              !available.any(
                (candidate) => _containsWholePhrase(candidate, required),
              );
        })
        .toList(growable: false);
    if (missing.isEmpty) return;
    issues.add(
      CandidateEligibilityIssue(
        type: type,
        message: '$label còn thiếu: ${missing.join(', ')}.',
      ),
    );
  }

  static void _checkGender(
    Map<String, dynamic> candidateData,
    Map<String, dynamic> requirement,
    List<CandidateEligibilityIssue> issues,
  ) {
    final required = _genderCode(requirement['value']);
    if (required == null || required == 'any') return;
    final actual = _genderCode(candidateData['gender']);
    if (actual == required) return;
    issues.add(
      CandidateEligibilityIssue(
        type: 'gender',
        message:
            'Giới tính yêu cầu ${_genderLabel(required)}; hồ sơ hiện là ${actual == null ? 'chưa cập nhật' : _genderLabel(actual)}.',
      ),
    );
  }

  static void _checkLanguage(
    Map<String, dynamic> candidateData,
    Map<String, dynamic> requirement,
    List<CandidateEligibilityIssue> issues,
  ) {
    final requiredLanguage = requirement['language']?.toString().trim() ?? '';
    final minimum = requirement['minimum']?.toString().trim() ?? '';
    final levelType = requirement['levelType']?.toString().trim() ?? '';
    if (requiredLanguage.isEmpty || minimum.isEmpty) return;

    Map<String, dynamic>? candidateLanguage;
    final rawLanguages = candidateData['languages'];
    if (rawLanguages is List) {
      for (final raw in rawLanguages.whereType<Map>()) {
        final item = Map<String, dynamic>.from(raw);
        if (_normalize(item['language']?.toString() ?? '') ==
            _normalize(requiredLanguage)) {
          candidateLanguage = item;
          break;
        }
      }
    }

    if (candidateLanguage == null) {
      issues.add(
        CandidateEligibilityIssue(
          type: 'languages',
          message: 'Ngoại ngữ còn thiếu: $requiredLanguage.',
        ),
      );
      return;
    }

    final actualLevel = candidateLanguage['level']?.toString().trim() ?? '';
    final meetsMinimum = _languageLevelMeets(
      language: requiredLanguage,
      levelType: levelType,
      minimum: minimum,
      actual: actualLevel,
    );
    if (meetsMinimum) return;

    final requiredDisplay = levelType.isEmpty || levelType == 'certificate'
        ? minimum
        : '$levelType $minimum';
    issues.add(
      CandidateEligibilityIssue(
        type: 'languages',
        message:
            '$requiredLanguage yêu cầu tối thiểu $requiredDisplay; hồ sơ hiện là ${actualLevel.isEmpty ? 'chưa cập nhật trình độ' : actualLevel}.',
      ),
    );
  }

  static bool _languageLevelMeets({
    required String language,
    required String levelType,
    required String minimum,
    required String actual,
  }) {
    if (actual.isEmpty) return false;
    final scale = levelType.toUpperCase();
    if (scale == 'IELTS' || scale == 'TOEIC') {
      final match = RegExp(
        '^$scale\\s*([0-9]+(?:[.,][0-9]+)?)\$',
        caseSensitive: false,
      ).firstMatch(actual.trim());
      final actualScore = double.tryParse(
        (match?.group(1) ?? '').replaceAll(',', '.'),
      );
      final requiredScore = double.tryParse(minimum.replaceAll(',', '.'));
      return actualScore != null &&
          requiredScore != null &&
          actualScore >= requiredScore;
    }

    final levels = scale == 'CEFR'
        ? LanguageProficiencyLevels.englishCefrLevels
        : LanguageProficiencyLevels.forLanguage(language);
    final normalizedLevels = levels.map(_normalize).toList(growable: false);
    final requiredIndex = normalizedLevels.indexOf(_normalize(minimum));
    final actualIndex = normalizedLevels.indexOf(_normalize(actual));
    return requiredIndex >= 0 && actualIndex >= requiredIndex;
  }

  static void _checkEducation(
    Map<String, dynamic> candidateData,
    Map<String, dynamic> requirement,
    List<CandidateEligibilityIssue> issues,
  ) {
    final minimum = requirement['minimum']?.toString() ?? 'none';
    final requiredRank = _requiredEducationRank(minimum);
    if (requiredRank <= 0) return;

    var actualRank = 0;
    final educations = candidateData['educations'];
    if (educations is List) {
      for (final raw in educations.whereType<Map>()) {
        final rank = _candidateEducationRank(raw['degree']?.toString() ?? '');
        if (rank > actualRank) actualRank = rank;
      }
    }
    if (actualRank >= requiredRank) return;

    issues.add(
      CandidateEligibilityIssue(
        type: 'education',
        message:
            'Học vấn yêu cầu ${_educationRequirementLabel(minimum)}; hồ sơ ${actualRank == 0 ? 'chưa có bằng cấp phù hợp' : 'chỉ đạt ${_educationRankLabel(actualRank)}'}.',
      ),
    );
  }

  static void _checkExperience(
    Map<String, dynamic> candidateData,
    Map<String, dynamic> requirement,
    List<CandidateEligibilityIssue> issues,
    DateTime now,
  ) {
    final minimum = requirement['minimum']?.toString() ?? 'no_exp';
    final requiredMonths = switch (minimum) {
      'no_exp' || 'none' => 0,
      'under_1' => 1,
      '1_to_3' || '1_2' => 12,
      '3_to_5' => 36,
      '2_5' => 24,
      'over_5' => 61,
      _ => -1,
    };
    if (requiredMonths == 0) return;

    final actualMonths = _totalExperienceMonths(candidateData, now);
    if (requiredMonths > 0 && actualMonths >= requiredMonths) return;

    issues.add(
      CandidateEligibilityIssue(
        type: 'experience',
        message:
            'Kinh nghiệm yêu cầu ${_experienceRequirementLabel(minimum)}; hồ sơ hiện có ${_experienceDisplay(actualMonths)}.',
      ),
    );
  }

  static int _totalExperienceMonths(
    Map<String, dynamic> candidateData,
    DateTime now,
  ) {
    final currentMonth = now.year * 12 + now.month - 1;
    final ranges = <_MonthRange>[];
    final experiences = candidateData['workExperiences'];
    if (experiences is! List) return 0;

    for (final raw in experiences.whereType<Map>()) {
      final start = _parseMonth(raw['startDate']);
      if (start == null || start > currentMonth) continue;
      final isCurrent = raw['currentlyWorking'] == true;
      final parsedEnd = isCurrent ? currentMonth : _parseMonth(raw['endDate']);
      if (parsedEnd == null) continue;
      var end = parsedEnd;
      if (end < start + 1) end = start + 1;
      if (end > currentMonth + 1) end = currentMonth + 1;
      ranges.add(_MonthRange(start, end));
    }
    if (ranges.isEmpty) return 0;

    ranges.sort((a, b) => a.start.compareTo(b.start));
    var total = 0;
    var mergedStart = ranges.first.start;
    var mergedEnd = ranges.first.end;
    for (final range in ranges.skip(1)) {
      if (range.start <= mergedEnd) {
        if (range.end > mergedEnd) mergedEnd = range.end;
      } else {
        total += mergedEnd - mergedStart;
        mergedStart = range.start;
        mergedEnd = range.end;
      }
    }
    return total + mergedEnd - mergedStart;
  }

  static int? _parseMonth(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    final match = RegExp(r'^(0?[1-9]|1[0-2])/(\d{4})$').firstMatch(value);
    if (match == null) return null;
    final month = int.parse(match.group(1)!);
    final year = int.parse(match.group(2)!);
    return year * 12 + month - 1;
  }

  static List<String> _candidateSkills(Map<String, dynamic> candidateData) {
    return _stringList(candidateData['skills']);
  }

  static List<String> _candidateCertificateNames(
    Map<String, dynamic> candidateData,
  ) {
    final result = <String>[];
    final certificates = candidateData['certificates'];
    if (certificates is! List) return result;
    for (final raw in certificates) {
      if (raw is Map) {
        final name = raw['name']?.toString().trim() ?? '';
        if (name.isNotEmpty) result.add(name);
      } else {
        final name = raw.toString().trim();
        if (name.isNotEmpty) result.add(name);
      }
    }
    return result;
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! Iterable) return const [];
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static String? _genderCode(dynamic raw) {
    final value = _normalize(raw?.toString() ?? '');
    return switch (value) {
      'male' || 'nam' => 'male',
      'female' || 'nu' => 'female',
      'other' || 'khac' => 'other',
      'any' => 'any',
      _ => null,
    };
  }

  static String _genderLabel(String value) => switch (value) {
    'male' => 'Nam',
    'female' => 'Nữ',
    'other' => 'Khác',
    _ => value,
  };

  static int _requiredEducationRank(String value) => switch (value) {
    'high_school' => 1,
    'college' => 3,
    'university' => 4,
    _ => 0,
  };

  static int _candidateEducationRank(String value) {
    return switch (_normalize(value)) {
      'trung hoc pho thong' || 'thpt' => 1,
      'trung cap' => 2,
      'cao dang' => 3,
      'dai hoc' => 4,
      'thac si' => 5,
      'tien si' => 6,
      _ => 0,
    };
  }

  static String _educationRequirementLabel(String value) => switch (value) {
    'high_school' => 'THPT trở lên',
    'college' => 'Cao đẳng trở lên',
    'university' => 'Đại học trở lên',
    _ => value,
  };

  static String _educationRankLabel(int rank) => switch (rank) {
    1 => 'THPT',
    2 => 'Trung cấp',
    3 => 'Cao đẳng',
    4 => 'Đại học',
    5 => 'Thạc sĩ',
    6 => 'Tiến sĩ',
    _ => 'chưa xác định',
  };

  static String _experienceRequirementLabel(String value) => switch (value) {
    'under_1' => 'có kinh nghiệm thực tế',
    '1_to_3' || '1_2' => 'từ 1 năm',
    '3_to_5' => 'từ 3 năm',
    '2_5' => 'từ 2 năm',
    'over_5' => 'trên 5 năm',
    _ => value,
  };

  static String _experienceDisplay(int months) {
    if (months <= 0) return 'chưa có kinh nghiệm';
    final years = months ~/ 12;
    final remainingMonths = months % 12;
    if (years == 0) return '$remainingMonths tháng';
    if (remainingMonths == 0) return '$years năm';
    return '$years năm $remainingMonths tháng';
  }

  static String _requirementLabel(Map<String, dynamic> requirement) {
    final label = requirement['label']?.toString().trim() ?? '';
    return label.isEmpty
        ? (requirement['type']?.toString() ?? 'không xác định')
        : label;
  }

  static bool _containsWholePhrase(String candidate, String required) {
    if (candidate == required) return true;
    return ' $candidate '.contains(' $required ');
  }

  static String _normalize(String input) {
    var value = input.trim().toLowerCase();
    value = value
        .replaceAll(RegExp('[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
        .replaceAll(RegExp('[èéẹẻẽêềếệểễ]'), 'e')
        .replaceAll(RegExp('[ìíịỉĩ]'), 'i')
        .replaceAll(RegExp('[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
        .replaceAll(RegExp('[ùúụủũưừứựửữ]'), 'u')
        .replaceAll(RegExp('[ỳýỵỷỹ]'), 'y')
        .replaceAll('đ', 'd')
        .replaceAll(RegExp(r'[^a-z0-9+#.]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return value;
  }
}

class _MonthRange {
  final int start;
  final int end;

  const _MonthRange(this.start, this.end);
}
