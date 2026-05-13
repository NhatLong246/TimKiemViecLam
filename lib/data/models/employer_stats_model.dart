/// Model cho tổng hợp thống kê Employer
class EmployerStatsSummary {
  final int approvedPosts;   // Bài đăng đã duyệt
  final int cancelledPosts;  // Bài đăng bị hủy/quá hạn
  final int totalHired;      // Số người đã thuê
  final double totalSpent;   // Tổng tiền đã chi
  final double totalDeposited; // Tổng tiền đã nạp

  const EmployerStatsSummary({
    required this.approvedPosts,
    required this.cancelledPosts,
    required this.totalHired,
    required this.totalSpent,
    required this.totalDeposited,
  });

  factory EmployerStatsSummary.empty() => const EmployerStatsSummary(
        approvedPosts: 0,
        cancelledPosts: 0,
        totalHired: 0,
        totalSpent: 0.0,
        totalDeposited: 0.0,
      );
}

/// Một điểm dữ liệu trên biểu đồ (theo khoảng thời gian)
class EmployerChartPoint {
  final String label;    // nhãn trục X (e.g. "Jan", "T2", "10/5")
  final double spent;    // tiền đã chi (thanh toán lương)
  final double deposited; // tiền đã nạp
  final int hired;       // số người được thuê
  final int posts;       // số bài đăng

  const EmployerChartPoint({
    required this.label,
    required this.spent,
    required this.deposited,
    required this.hired,
    required this.posts,
  });
}

/// Enum khoảng thời gian lọc
enum StatsPeriod { day, week, month, year }

extension StatsPeriodExt on StatsPeriod {
  String get label {
    switch (this) {
      case StatsPeriod.day:
        return 'Ngày';
      case StatsPeriod.week:
        return 'Tuần';
      case StatsPeriod.month:
        return 'Tháng';
      case StatsPeriod.year:
        return 'Năm';
    }
  }
}
