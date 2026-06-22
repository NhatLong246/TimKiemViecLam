import 'package:flutter_test/flutter_test.dart';
import 'package:viecnow/data/services/disbursement_calculator.dart';

void main() {
  group('DisbursementCalculator', () {
    test(
      'refunds unfilled slot budget instead of giving it to one candidate',
      () {
        final result = DisbursementCalculator.allocate(
          availableAmount: 3000000,
          calculatedSalaries: const {'candidate-1': 1000000},
        );

        expect(result.candidateAmounts, const {'candidate-1': 1000000});
        expect(result.totalEarned, 1000000);
        expect(result.excessRefund, 2000000);
      },
    );

    test('preserves each candidate calculated salary', () {
      final result = DisbursementCalculator.allocate(
        availableAmount: 3000000,
        calculatedSalaries: const {
          'candidate-1': 1000000,
          'candidate-2': 500000,
        },
      );

      expect(result.candidateAmounts, const {
        'candidate-1': 1000000,
        'candidate-2': 500000,
      });
      expect(result.totalEarned, 1500000);
      expect(result.excessRefund, 1500000);
    });

    test('refunds the full available amount when nobody earned salary', () {
      final result = DisbursementCalculator.allocate(
        availableAmount: 3000000,
        calculatedSalaries: const {'candidate-1': 0},
      );

      expect(result.totalEarned, 0);
      expect(result.excessRefund, 3000000);
    });

    test('rejects an available amount below total calculated salary', () {
      expect(
        () => DisbursementCalculator.allocate(
          availableAmount: 900000,
          calculatedSalaries: const {'candidate-1': 1000000},
        ),
        throwsA(isA<DisbursementAmountException>()),
      );
    });

    test('calculates gross payment and employer held-budget refund', () {
      const amounts = <String, double>{
        'candidate-1': 1000000,
        'candidate-2': 0,
      };

      final gross = DisbursementCalculator.grossCandidatePayment(amounts);
      final refund = DisbursementCalculator.refundFromHeldBudget(
        heldAmount: 3000000,
        grossPayment: gross,
      );

      expect(gross, 1000000);
      expect(refund, 2000000);
    });
  });
}
