import 'dart:math' as math;

class DisbursementAmountException implements Exception {
  final String message;

  const DisbursementAmountException(this.message);

  @override
  String toString() => message;
}

class DisbursementAllocation {
  final Map<String, double> candidateAmounts;
  final double totalEarned;
  final double excessRefund;

  const DisbursementAllocation({
    required this.candidateAmounts,
    required this.totalEarned,
    required this.excessRefund,
  });
}

class DisbursementCalculator {
  const DisbursementCalculator._();

  static DisbursementAllocation allocate({
    required double availableAmount,
    required Map<String, double> calculatedSalaries,
  }) {
    if (availableAmount < 0) {
      throw const DisbursementAmountException(
        'Số tiền giải ngân không được nhỏ hơn 0.',
      );
    }

    final candidateAmounts = <String, double>{};
    for (final entry in calculatedSalaries.entries) {
      candidateAmounts[entry.key] = math.max(entry.value, 0).toDouble();
    }

    final totalEarned = grossCandidatePayment(candidateAmounts);
    if (totalEarned - availableAmount > 0.01) {
      throw DisbursementAmountException(
        'Số tiền giải ngân ${availableAmount.toStringAsFixed(0)}đ '
        'nhỏ hơn tổng lương thực tế ${totalEarned.toStringAsFixed(0)}đ.',
      );
    }

    return DisbursementAllocation(
      candidateAmounts: Map.unmodifiable(candidateAmounts),
      totalEarned: totalEarned,
      excessRefund: math.max(availableAmount - totalEarned, 0).toDouble(),
    );
  }

  static double grossCandidatePayment(Map<String, double> candidateAmounts) {
    return candidateAmounts.values.fold<double>(
      0,
      (sum, value) => sum + math.max(value, 0),
    );
  }

  static double refundFromHeldBudget({
    required double heldAmount,
    required double grossPayment,
  }) {
    return math.max(heldAmount - grossPayment, 0).toDouble();
  }
}
