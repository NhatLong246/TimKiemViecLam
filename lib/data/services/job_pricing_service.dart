import '../models/job_post_model.dart';

class JobDepositQuote {
  final bool requiresDeposit;
  final double totalBudget;
  final double depositAmount;
  final int workDays;
  final double payableUnitsPerWorker;
  final String calculationUnit;

  const JobDepositQuote({
    required this.requiresDeposit,
    required this.totalBudget,
    required this.depositAmount,
    required this.workDays,
    required this.payableUnitsPerWorker,
    required this.calculationUnit,
  });

  Map<String, dynamic> toMap() => {
    'requiresDeposit': requiresDeposit,
    'totalBudget': totalBudget,
    'depositAmount': depositAmount,
    'workDays': workDays,
    'payableUnitsPerWorker': payableUnitsPerWorker,
    'calculationUnit': calculationUnit,
  };
}

class JobPricingService {
  const JobPricingService._();

  static JobDepositQuote quote(JobPostModel post) {
    if (!post.isPartTimeManaged) {
      final estimatedBudget = _ceilVnd(post.salary * post.slots);
      return JobDepositQuote(
        requiresDeposit: false,
        totalBudget: estimatedBudget,
        depositAmount: 0,
        workDays: 0,
        payableUnitsPerWorker: 0,
        calculationUnit: 'referral_only',
      );
    }

    if (post.salary <= 0) {
      throw Exception('Mức lương phải lớn hơn 0.');
    }
    if (post.slots <= 0) {
      throw Exception('Số lượng người thuê phải lớn hơn 0.');
    }

    final workDays = _workDays(post);
    final amountPerWorker = switch (post.salaryType) {
      'per_hour' => _amountForHourly(post, workDays),
      'per_day' => post.salary * workDays,
      'per_month' => (post.salary / 30) * workDays,
      'fixed' => post.salary,
      _ => throw Exception('Đơn vị tính lương không hợp lệ.'),
    };

    final unit = switch (post.salaryType) {
      'per_hour' => 'hour',
      'per_day' => 'day',
      'per_month' => 'month_prorated_30_days',
      'fixed' => 'fixed_per_worker',
      _ => 'unknown',
    };

    final payableUnits = switch (post.salaryType) {
      'per_hour' => (post.workHoursPerDay ?? 0) * workDays,
      'per_day' => workDays.toDouble(),
      'per_month' => workDays.toDouble(),
      'fixed' => 1.0,
      _ => 0.0,
    };

    final total = _ceilVnd(amountPerWorker * post.slots);
    return JobDepositQuote(
      requiresDeposit: true,
      totalBudget: total,
      depositAmount: total,
      workDays: workDays,
      payableUnitsPerWorker: payableUnits,
      calculationUnit: unit,
    );
  }

  static int _workDays(JobPostModel post) {
    final start = DateTime(
      post.startDate.year,
      post.startDate.month,
      post.startDate.day,
    );
    final endSource = post.endDate ?? post.startDate;
    final end = DateTime(endSource.year, endSource.month, endSource.day);
    if (end.isBefore(start)) {
      throw Exception('Ngày kết thúc không được trước ngày bắt đầu.');
    }
    return end.difference(start).inDays + 1;
  }

  static double _amountForHourly(JobPostModel post, int workDays) {
    final hours = post.workHoursPerDay ?? 0;
    if (hours <= 0) {
      throw Exception('Việc trả theo giờ cần nhập số giờ làm mỗi ngày.');
    }
    return post.salary * hours * workDays;
  }

  static double _ceilVnd(double value) => value.ceilToDouble();
}
