/// Mức độ ngoại ngữ theo từng ngôn ngữ (không dùng chung Sơ/Trung/Cao cấp).
class LanguageProficiencyLevels {
  LanguageProficiencyLevels._();

  static const englishCefrLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  static const languageOptions = [
    'Tiếng Anh',
    'Tiếng Trung',
    'Tiếng Nhật',
    'Tiếng Hàn',
    'Tiếng Pháp',
    'Tiếng Đức',
    'Tiếng Nga',
    'Tiếng Thái',
    'Tiếng Tây Ban Nha',
    'Tiếng Bồ Đào Nha',
    'Tiếng Ý',
    'Tiếng Ả Rập',
    'Khác',
  ];

  static List<String> forLanguage(String language) {
    switch (language) {
      case 'Tiếng Anh':
        return englishCefrLevels;
      case 'Tiếng Trung':
        return const [
          'HSK 1',
          'HSK 2',
          'HSK 3',
          'HSK 4',
          'HSK 5',
          'HSK 6',
        ];
      case 'Tiếng Nhật':
        return const [
          'JLPT N5',
          'JLPT N4',
          'JLPT N3',
          'JLPT N2',
          'JLPT N1',
        ];
      case 'Tiếng Hàn':
        return const [
          'TOPIK I (1-2)',
          'TOPIK II (3)',
          'TOPIK II (4)',
          'TOPIK II (5)',
          'TOPIK II (6)',
        ];
      case 'Tiếng Pháp':
        return const [
          'DELF A1',
          'DELF A2',
          'DELF B1',
          'DELF B2',
          'DALF C1',
          'DALF C2',
        ];
      case 'Tiếng Đức':
        return const [
          'Goethe A1',
          'Goethe A2',
          'Goethe B1',
          'Goethe B2',
          'Goethe C1',
          'Goethe C2',
        ];
      case 'Tiếng Nga':
        return const [
          'ТЭУ A1',
          'ТЭУ A2',
          'ТРКИ B1',
          'ТРКИ B2',
          'ТРКИ C1',
          'ТРКИ C2',
        ];
      case 'Tiếng Thái':
        return const [
          'Cơ bản',
          'Trung cấp',
          'Khá',
          'Thành thạo',
        ];
      case 'Tiếng Tây Ban Nha':
        return const [
          'DELE A1',
          'DELE A2',
          'DELE B1',
          'DELE B2',
          'DELE C1',
          'DELE C2',
        ];
      case 'Tiếng Bồ Đào Nha':
        return const [
          'CELPE-Bras Básico',
          'CELPE-Bras Intermediário',
          'CELPE-Bras Avançado',
        ];
      case 'Tiếng Ý':
        return const [
          'CELI A1',
          'CELI A2',
          'CELI B1',
          'CELI B2',
          'CELI C1',
          'CELI C2',
        ];
      case 'Tiếng Ả Rập':
        return const [
          'Cơ bản',
          'Trung cấp',
          'Khá',
          'Thành thạo',
        ];
      case 'Khác':
        return const [
          'A1',
          'A2',
          'B1',
          'B2',
          'C1',
          'C2',
          'Giao tiếp cơ bản',
          'Giao tiếp tốt',
          'Thành thạo',
        ];
      default:
        return const ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
    }
  }

  /// Gợi ý chuyển mức cũ (Sơ/Trung/Cao cấp) sang mức mới khi đổi ngôn ngữ.
  static String? mapLegacyLevel(String language, String oldLevel) {
    final normalized = oldLevel.trim();
    if (!normalized.contains('cấp') && !normalized.contains('Cấp')) {
      return null;
    }
    final isBasic = normalized.contains('Sơ');
    final isMid = normalized.contains('Trung');
    final isHigh = normalized.contains('Cao');

    final levels = forLanguage(language);
    if (levels.isEmpty) return null;

    int index;
    if (language == 'Tiếng Nhật') {
      if (isBasic) index = 0; // N5
      else if (isMid) index = 2; // N3
      else index = levels.length - 1; // N1
    } else if (language == 'Tiếng Trung') {
      if (isBasic) index = 0;
      else if (isMid) index = 2;
      else index = levels.length - 1;
    } else {
      // CEFR-like lists: pick low/mid/high
      if (isBasic) index = 0;
      else if (isMid) index = (levels.length / 2).floor().clamp(0, levels.length - 1);
      else index = levels.length - 1;
    }
    return levels[index.clamp(0, levels.length - 1)];
  }

  /// Gợi ý hệ thống đánh giá theo ngôn ngữ.
  static String levelHintFor(String language) {
    switch (language) {
      case 'Tiếng Anh':
        return 'Chọn CEFR (A1–C2) hoặc nhập điểm IELTS / TOEIC';
      case 'Tiếng Trung':
        return 'Chọn theo chứng chỉ HSK';
      case 'Tiếng Nhật':
        return 'Chọn theo chứng chỉ JLPT (N5 → N1)';
      case 'Tiếng Hàn':
        return 'Chọn theo chứng chỉ TOPIK';
      case 'Tiếng Pháp':
        return 'Chọn theo DELF / DALF';
      case 'Tiếng Đức':
        return 'Chọn theo chứng chỉ Goethe';
      case 'Tiếng Nga':
        return 'Chọn theo ТЭУ / ТРКИ';
      case 'Tiếng Tây Ban Nha':
        return 'Chọn theo DELE';
      case 'Tiếng Bồ Đào Nha':
        return 'Chọn theo CELPE-Bras';
      case 'Tiếng Ý':
        return 'Chọn theo CELI';
      case 'Tiếng Thái':
      case 'Tiếng Ả Rập':
        return 'Chọn mức phù hợp với khả năng của bạn';
      case 'Khác':
        return 'Chọn theo khung CEFR hoặc mức giao tiếp';
      default:
        return '';
    }
  }

  /// Phân tích mức Tiếng Anh đã lưu (`B2`, `IELTS 6.5`, `TOEIC 750`).
  static EnglishLevelParts parseEnglishLevel(String level) {
    final raw = level.trim();
    final upper = raw.toUpperCase();
    if (upper.startsWith('IELTS')) {
      final score = raw.replaceFirst(RegExp(r'^ielts\s*', caseSensitive: false), '').trim();
      return EnglishLevelParts(ieltsScore: score);
    }
    if (upper.startsWith('TOEIC')) {
      final score = raw.replaceFirst(RegExp(r'^toeic\s*', caseSensitive: false), '').trim();
      return EnglishLevelParts(toeicScore: score);
    }
    if (englishCefrLevels.contains(raw.toUpperCase())) {
      return EnglishLevelParts(cefr: raw.toUpperCase());
    }
    return EnglishLevelParts(other: raw);
  }

  /// Ghép mức Tiếng Anh để lưu Firestore (ưu tiên IELTS → TOEIC → CEFR).
  static String? composeEnglishLevel({
    String? cefr,
    String? ieltsScore,
    String? toeicScore,
  }) {
    final ielts = ieltsScore?.trim() ?? '';
    if (ielts.isNotEmpty) return 'IELTS $ielts';

    final toeic = toeicScore?.trim() ?? '';
    if (toeic.isNotEmpty) return 'TOEIC $toeic';

    final c = cefr?.trim().toUpperCase() ?? '';
    if (c.isNotEmpty && englishCefrLevels.contains(c)) return c;

    return null;
  }

  static bool isEnglish(String? language) => language == 'Tiếng Anh';

  /// Danh sách hiển thị: giữ mức đã lưu nếu không còn trong bảng mới (khi sửa).
  static List<String> optionsFor(String? language, {String? currentLevel}) {
    if (language == null || language.isEmpty) return const [];
    final base = forLanguage(language);
    final level = currentLevel?.trim() ?? '';
    if (level.isNotEmpty && !base.contains(level)) {
      return [level, ...base];
    }
    return base;
  }
}

class EnglishLevelParts {
  final String? cefr;
  final String? ieltsScore;
  final String? toeicScore;
  final String? other;

  const EnglishLevelParts({
    this.cefr,
    this.ieltsScore,
    this.toeicScore,
    this.other,
  });
}
