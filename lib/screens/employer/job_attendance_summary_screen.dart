import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../common/styles/app_colors.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/group_chat_model.dart';
import '../../data/models/job_post_model.dart';
import '../../data/services/attendance_service.dart';
import '../../data/services/job_post_service.dart';
import '../../data/services/work_schedule_service.dart';
import '../../utils/work_day_helper.dart';

/// Bảng điểm danh tổng hợp cho NTD sau khi đủ ngày làm bắt buộc.
class JobAttendanceSummaryScreen extends StatefulWidget {
  const JobAttendanceSummaryScreen({super.key});

  @override
  State<JobAttendanceSummaryScreen> createState() =>
      _JobAttendanceSummaryScreenState();
}

class _JobAttendanceSummaryScreenState extends State<JobAttendanceSummaryScreen> {
  final _attendanceSvc = AttendanceService();
  final _scheduleSvc = WorkScheduleService();
  final _jobSvc = JobPostService();
  final _db = FirebaseFirestore.instance;

  late GroupChatModel _group;
  JobPostModel? _job;
  List<String> _mandatoryDates = [];
  List<AttendanceModel> _sessions = [];
  Map<String, String> _candidateNames = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _group = Get.arguments as GroupChatModel;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _job = await _jobSvc.getJobPostById(_group.jobId);
      _candidateNames = await _loadCandidateNames();
      final scheduled = await _scheduleSvc.listScheduledDates(_group.groupId);
      _mandatoryDates = WorkDayHelper.mandatoryDates(
        _job ?? _fallbackJob(),
        scheduledDates: scheduled,
      );
      _sessions = await _attendanceSvc.streamByJob(_group.jobId).first;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, String>> _loadCandidateNames() async {
    final ids = _group.memberIds
        .where((id) => id.isNotEmpty && id != _group.employerId)
        .toList(growable: false);
    if (ids.isEmpty) return {};

    final result = <String, String>{};
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final d = doc.data();
        final first = (d['firstName'] ?? '').toString().trim();
        final last = (d['lastName'] ?? '').toString().trim();
        final fullName = '$first $last'.trim();
        final company = (d['companyName'] ?? '').toString().trim();
        final display = fullName.isNotEmpty
            ? fullName
            : (company.isNotEmpty ? company : 'Nhân viên');
        result[doc.id] = display;
      }
    }
    return result;
  }

  JobPostModel _fallbackJob() => JobPostModel(
        jobId: _group.jobId,
        employerId: _group.employerId,
        title: _group.jobTitle,
        description: '',
        category: 'other',
        jobType: 'part_time',
        location: const {},
        salary: 0,
        salaryType: 'per_day',
        slots: 1,
        startDate: DateTime.now(),
        status: 'active',
        totalBudget: 0,
      );

  Map<String, Map<String, _DayScore>> _buildScores() {
    final candidates = _group.memberIds
        .where((id) => id != _group.employerId)
        .toList();
    final byCandidate = <String, Map<String, _DayScore>>{};
    for (final cid in candidates) {
      byCandidate[cid] = {};
      for (final d in _mandatoryDates) {
        byCandidate[cid]![d] = const _DayScore.missing();
      }
    }
    for (final session in _sessions) {
      if (!_mandatoryDates.contains(session.date)) continue;
      for (final r in session.records) {
        if (!byCandidate.containsKey(r.candidateId)) continue;
        final hasIn = (r.checkInTime ?? '').isNotEmpty;
        final hasOut = (r.checkOutTime ?? '').isNotEmpty;
        byCandidate[r.candidateId]![session.date] = _DayScore(
          hasCheckIn: hasIn,
          hasCheckOut: hasOut,
          status: r.status,
        );
      }
    }
    return byCandidate;
  }

  int _completedDays(Map<String, _DayScore> days) =>
      days.values.where((s) => s.hasCheckIn && s.hasCheckOut).length;

  Color _progressColor(int pct) {
    if (pct >= 100) return const Color(0xFF2E7D32);
    if (pct >= 50) return const Color(0xFFFB8C00);
    return const Color(0xFFC62828);
  }

  @override
  Widget build(BuildContext context) {
    final scores = _buildScores();
    final required = _mandatoryDates.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.employerGradient),
        ),
        foregroundColor: Colors.white,
        title: const Text('Bảng điểm danh'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _group.jobTitle,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Bắt buộc điểm danh: $required ngày',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...scores.entries.map((e) {
                    final done = _completedDays(e.value);
                    final pct =
                        required > 0 ? (done / required * 100).round() : 0;
                    final color = _progressColor(pct);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: color.withValues(alpha: 0.22),
                        ),
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        collapsedShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        title: Text(
                          _candidateNames[e.key] ?? 'Nhân viên',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      minHeight: 7,
                                      value: required > 0 ? done / required : 0,
                                      valueColor: AlwaysStoppedAnimation<Color>(color),
                                      backgroundColor:
                                          color.withValues(alpha: 0.16),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '$pct%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$done/$required ngày hoàn thành',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                        children: e.value.entries.map((day) {
                          final s = day.value;
                          final ok = s.hasCheckIn && s.hasCheckOut;
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            title: Text(DateFormat('dd/MM/yyyy').format(
                                DateTime.parse(day.key))),
                            trailing: Icon(
                              ok
                                  ? Icons.check_circle
                                  : Icons.cancel_outlined,
                              color: ok
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            subtitle: Text(
                              '${s.hasCheckIn ? "✓" : "✗"} đầu ca · '
                              '${s.hasCheckOut ? "✓" : "✗"} cuối ca',
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }),
                  if (scores.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Chưa có dữ liệu điểm danh hoặc chưa thiết lập ngày làm.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _DayScore {
  final bool hasCheckIn;
  final bool hasCheckOut;
  final String status;

  const _DayScore({
    required this.hasCheckIn,
    required this.hasCheckOut,
    required this.status,
  });

  const _DayScore.missing()
      : hasCheckIn = false,
        hasCheckOut = false,
        status = 'absent';
}
