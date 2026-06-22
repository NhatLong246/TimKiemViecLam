import 'dart:math' as math;

class CandidatePaymentAmountResolver {
  const CandidatePaymentAmountResolver._();

  static int resolve({
    required String candidateId,
    required Map<String, double> candidateAmounts,
    required double fallbackSalary,
    required bool completed,
    double? actualEarnings,
  }) {
    if (completed && actualEarnings != null) {
      return math.max(actualEarnings, 0).round();
    }

    final allocatedAmount = candidateAmounts[candidateId];
    if (allocatedAmount != null) {
      return math.max(allocatedAmount, 0).round();
    }

    return math.max(fallbackSalary, 0).round();
  }
}
