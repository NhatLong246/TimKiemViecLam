import 'package:flutter_test/flutter_test.dart';
import 'package:viecnow/data/services/candidate_payment_amount_resolver.dart';
import 'package:viecnow/utils/work_day_helper.dart';

void main() {
  group('CandidatePaymentAmountResolver', () {
    test('shows the candidate allocation instead of the full job budget', () {
      final amount = CandidatePaymentAmountResolver.resolve(
        candidateId: 'candidate-1',
        candidateAmounts: const {'candidate-1': 2000},
        fallbackSalary: 2000,
        completed: false,
      );

      expect(amount, 2000);
    });

    test('prefers actual earnings after payment is completed', () {
      final amount = CandidatePaymentAmountResolver.resolve(
        candidateId: 'candidate-1',
        candidateAmounts: const {'candidate-1': 2000},
        fallbackSalary: 2000,
        completed: true,
        actualEarnings: 1800,
      );

      expect(amount, 1800);
    });
  });

  group('WorkDayHelper attendance display dates', () {
    test('excludes an attendance session before the job start date', () {
      final dates = WorkDayHelper.validAttendanceDisplayDates(
        mandatoryDates: const ['2026-06-24'],
        sessionDates: const ['2026-06-23', '2026-06-24'],
      );

      expect(dates, const ['2026-06-24']);
    });

    test('selects the first work date when today is before job start', () {
      final date = WorkDayHelper.selectAttendanceDate(
        targetDate: '2026-06-23',
        mandatoryDates: const ['2026-06-24'],
      );

      expect(date, '2026-06-24');
    });
  });
}
