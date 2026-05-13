/// Model: MarketRateItem — Mặt bằng lương tham khảo theo danh mục + khu vực
/// Được tính toán từ jobPosts (status: approved | active) trong Firestore.
class MarketRateItem {
  final String category; // "phuc_vu", "pha_che", ...
  final String categoryLabel; // "Phục vụ", "Pha chế", ...
  final String city; // "TP.HCM"
  final String district; // "Quận 1"
  final double minSalary;
  final double maxSalary;
  final double avgSalary;
  final String salaryType; // "per_hour" | "per_day" | "per_month"
  final int totalActiveJobs; // số lượng job đang active/approved
  final int totalSlots; // tổng số vị trí cần tuyển
  final String demandLevel; // "high" | "medium" | "low"

  const MarketRateItem({
    required this.category,
    required this.categoryLabel,
    required this.city,
    required this.district,
    required this.minSalary,
    required this.maxSalary,
    required this.avgSalary,
    required this.salaryType,
    required this.totalActiveJobs,
    required this.totalSlots,
    required this.demandLevel,
  });

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get locationLabel => '$city, $district';

  String get salaryTypeLabel {
    switch (salaryType) {
      case 'per_hour':
        return '/giờ';
      case 'per_day':
        return '/ngày';
      case 'per_month':
        return '/tháng';
      default:
        return '';
    }
  }

  String get salaryRangeFormatted {
    final min = _formatVnd(minSalary);
    final max = _formatVnd(maxSalary);
    return 'Mức giá chung: $min - $max${salaryTypeLabel}';
  }

  String get demandLabel {
    switch (demandLevel) {
      case 'high':
        return 'Nhu cầu cao';
      case 'medium':
        return 'Bình thường';
      default:
        return 'Nhu cầu thấp';
    }
  }

  String _formatVnd(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(amount % 1000000 == 0 ? 0 : 1)}tr';
    }
    if (amount >= 1000) {
      final k = (amount / 1000).round();
      return '${k}.000đ';
    }
    return '${amount.toStringAsFixed(0)}đ';
  }

  // ── SQLite serialization ────────────────────────────────────────────────────

  Map<String, dynamic> toSqlite() => {
        'category': category,
        'categoryLabel': categoryLabel,
        'city': city,
        'district': district,
        'minSalary': minSalary,
        'maxSalary': maxSalary,
        'avgSalary': avgSalary,
        'salaryType': salaryType,
        'totalActiveJobs': totalActiveJobs,
        'totalSlots': totalSlots,
        'demandLevel': demandLevel,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      };

  factory MarketRateItem.fromSqlite(Map<String, dynamic> row) => MarketRateItem(
        category: row['category'] as String,
        categoryLabel: row['categoryLabel'] as String,
        city: row['city'] as String,
        district: row['district'] as String,
        minSalary: (row['minSalary'] as num).toDouble(),
        maxSalary: (row['maxSalary'] as num).toDouble(),
        avgSalary: (row['avgSalary'] as num).toDouble(),
        salaryType: row['salaryType'] as String,
        totalActiveJobs: row['totalActiveJobs'] as int,
        totalSlots: row['totalSlots'] as int,
        demandLevel: row['demandLevel'] as String,
      );
}

// ── Category mapping constants ───────────────────────────────────────────────

const Map<String, String> kCategoryLabels = {
  'all': 'Tất cả',
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

const Map<String, String> kCategoryIcons = {
  'boc_vac': '🏋️',
  'lau_don': '🧹',
  'bung_be': '🍽️',
  'phuc_vu': '👔',
  'pha_che': '☕',
  'tiep_thi': '📢',
  'van_chuyen': '🚚',
  'bao_ve': '🛡️',
  'other': '💼',
};
