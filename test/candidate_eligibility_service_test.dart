import 'package:flutter_test/flutter_test.dart';
import 'package:viecnow/data/models/full_time_job_details.dart';
import 'package:viecnow/data/models/job_post_model.dart';
import 'package:viecnow/data/services/candidate_eligibility_service.dart';

void main() {
  group('CandidateEligibilityService', () {
    test('passes when every structured requirement is satisfied', () {
      final result = CandidateEligibilityService.evaluate(
        candidateData: {
          'gender': 'female',
          'skills': ['Lập trình Dart', 'Microsoft Excel'],
          'certificates': [
            {'name': 'An toàn lao động'},
          ],
          'languages': [
            {'language': 'Tiếng Anh', 'level': 'B2'},
          ],
          'educations': [
            {'degree': 'Đại học'},
          ],
          'workExperiences': [
            {
              'startDate': '01/2020',
              'endDate': '01/2024',
              'currentlyWorking': false,
            },
          ],
        },
        requirements: [
          {
            'type': 'skills',
            'values': ['lap trinh dart', 'EXCEL'],
          },
          {
            'type': 'certificates',
            'values': ['AN TOÀN LAO ĐỘNG'],
          },
          {
            'type': 'languages',
            'language': 'Tiếng Anh',
            'levelType': 'CEFR',
            'minimum': 'B1',
          },
          {'type': 'gender', 'value': 'female'},
          {'type': 'education', 'minimum': 'college'},
          {'type': 'experience', 'minimum': '3_to_5'},
          {
            'type': 'other',
            'text': 'Có phương tiện đi lại',
          },
        ],
        now: DateTime(2026, 6, 22),
      );

      expect(result.isEligible, isTrue);
      expect(result.issues, isEmpty);
    });

    test('reports every missing or mismatched profile condition', () {
      final result = CandidateEligibilityService.evaluate(
        candidateData: {
          'gender': 'male',
          'skills': ['Dart'],
          'certificates': <Map<String, dynamic>>[],
          'languages': <Map<String, dynamic>>[],
          'educations': [
            {'degree': 'Trung học phổ thông'},
          ],
          'workExperiences': <Map<String, dynamic>>[],
        },
        requirements: [
          {
            'type': 'skills',
            'values': ['Dart', 'Flutter'],
          },
          {
            'type': 'certificates',
            'values': ['An toàn lao động'],
          },
          {
            'type': 'languages',
            'language': 'Tiếng Anh',
            'levelType': 'CEFR',
            'minimum': 'B1',
          },
          {'type': 'gender', 'value': 'female'},
          {'type': 'education', 'minimum': 'university'},
          {'type': 'experience', 'minimum': '1_to_3'},
        ],
        now: DateTime(2026, 6, 22),
      );

      expect(result.isEligible, isFalse);
      expect(
        result.issues.map((issue) => issue.type).toSet(),
        {
          'skills',
          'certificates',
          'languages',
          'gender',
          'education',
          'experience',
        },
      );
      expect(result.userMessage, contains('Flutter'));
      expect(result.userMessage, contains('Giới tính yêu cầu Nữ'));
      expect(result.userMessage, contains('Vui lòng cập nhật hồ sơ'));
    });

    test('only compares IELTS and TOEIC scores on the same scale', () {
      final ieltsRequirement = [
        {
          'type': 'languages',
          'language': 'Tiếng Anh',
          'levelType': 'IELTS',
          'minimum': '6.5',
        },
      ];

      final passing = CandidateEligibilityService.evaluate(
        candidateData: {
          'languages': [
            {'language': 'Tiếng Anh', 'level': 'IELTS 7.0'},
          ],
        },
        requirements: ieltsRequirement,
      );
      final differentScale = CandidateEligibilityService.evaluate(
        candidateData: {
          'languages': [
            {'language': 'Tiếng Anh', 'level': 'C1'},
          ],
        },
        requirements: ieltsRequirement,
      );

      expect(passing.isEligible, isTrue);
      expect(differentScale.isEligible, isFalse);
    });

    test('does not double count overlapping work experience', () {
      final candidateData = {
        'workExperiences': [
          {
            'startDate': '01/2020',
            'endDate': '01/2022',
            'currentlyWorking': false,
          },
          {
            'startDate': '01/2021',
            'endDate': '01/2024',
            'currentlyWorking': false,
          },
        ],
      };

      final threeYears = CandidateEligibilityService.evaluate(
        candidateData: candidateData,
        requirements: const [
          {'type': 'experience', 'minimum': '3_to_5'},
        ],
        now: DateTime(2026, 6, 22),
      );
      final overFiveYears = CandidateEligibilityService.evaluate(
        candidateData: candidateData,
        requirements: const [
          {'type': 'experience', 'minimum': 'over_5'},
        ],
        now: DateTime(2026, 6, 22),
      );

      expect(threeYears.isEligible, isTrue);
      expect(overFiveYears.isEligible, isFalse);
      expect(overFiveYears.userMessage, contains('4 năm'));
    });

    test('ignores free-text other requirement for automatic eligibility', () {
      final result = CandidateEligibilityService.evaluate(
        candidateData: const {},
        requirements: const [
          {
            'type': 'other',
            'label': 'Yêu cầu khác',
            'text': 'Có phương tiện đi lại',
          },
        ],
      );

      expect(result.isEligible, isTrue);
    });

    test('builds eligibility requirements for legacy job posts', () {
      final job = JobPostModel(
        jobId: 'job-1',
        employerId: 'employer-1',
        title: 'Nhân viên',
        description: 'Mô tả',
        category: 'other',
        jobType: 'full_time',
        location: const {},
        salary: 10000000,
        salaryType: 'per_month',
        slots: 1,
        startDate: DateTime(2026, 12, 1),
        status: 'active',
        totalBudget: 10000000,
        requiredLanguage: 'Tiếng Anh',
        requiredLanguageLevel: 'B1',
        requiredExperience: '1_to_3',
        fullTimeDetails: const FullTimeJobDetails(
          payDayOfMonth: 5,
          minEducation: 'college',
        ),
      );

      expect(
        job.effectiveCandidateRequirements
            .map((requirement) => requirement['type'])
            .toSet(),
        {'languages', 'education', 'experience'},
      );
    });
  });
}
