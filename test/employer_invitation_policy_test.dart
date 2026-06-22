import 'package:flutter_test/flutter_test.dart';
import 'package:viecnow/data/models/job_post_model.dart';
import 'package:viecnow/data/services/employer_invitation_service.dart';

void main() {
  final now = DateTime(2026, 6, 22, 10);

  JobPostModel job({
    String status = 'active',
    DateTime? startDate,
    DateTime? applicationDeadline,
    int slots = 2,
    int filledSlots = 0,
  }) {
    return JobPostModel(
      jobId: 'job-1',
      employerId: 'employer-1',
      title: 'Công việc',
      description: 'Mô tả',
      category: 'other',
      jobType: 'part_time',
      location: const {},
      salary: 500000,
      salaryType: 'per_day',
      slots: slots,
      filledSlots: filledSlots,
      startDate: startDate ?? DateTime(2026, 6, 23),
      applicationDeadline:
          applicationDeadline ?? DateTime(2026, 6, 22, 23, 59),
      status: status,
      totalBudget: 1000000,
      candidateRequirements: const [
        {'type': 'gender', 'value': 'female'},
      ],
    );
  }

  group('EmployerInvitationPolicy', () {
    test('allows a valid invitation without checking profile requirements', () {
      expect(
        EmployerInvitationPolicy.rejectionReason(job(), now: now),
        isNull,
      );
    });

    test('rejects an invitation after the application deadline', () {
      expect(
        EmployerInvitationPolicy.rejectionReason(
          job(applicationDeadline: DateTime(2026, 6, 22, 9)),
          now: now,
        ),
        contains('quá hạn'),
      );
    });

    test('rejects an invitation after the job starts', () {
      expect(
        EmployerInvitationPolicy.rejectionReason(
          job(startDate: DateTime(2026, 6, 22, 9)),
          now: now,
        ),
        contains('đã bắt đầu'),
      );
    });

    test('rejects inactive or full jobs', () {
      expect(
        EmployerInvitationPolicy.rejectionReason(
          job(status: 'closed'),
          now: now,
        ),
        contains('không còn nhận'),
      );
      expect(
        EmployerInvitationPolicy.rejectionReason(
          job(slots: 1, filledSlots: 1),
          now: now,
        ),
        contains('đủ số lượng'),
      );
    });
  });
}
