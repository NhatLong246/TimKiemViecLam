import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:viecnow/data/models/schedule_model.dart';
import 'package:viecnow/data/services/job_post_service.dart';
import 'package:viecnow/data/services/schedule_service.dart';
import 'package:viecnow/routes/app_routes.dart';

class CandidateScheduleScreen extends StatefulWidget {
  const CandidateScheduleScreen({super.key});

  @override
  State<CandidateScheduleScreen> createState() =>
      _CandidateScheduleScreenState();
}

class _CandidateScheduleScreenState extends State<CandidateScheduleScreen> {
  final Color _primary = const Color(0xFF2E7D32);
  final _scheduleService = ScheduleService();
  final _jobPostService = JobPostService();

  late DateTime _selectedDate;
  late List<DateTime> _weekDates;
  int _weekOffset = 0;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _selectedDate = DateTime(today.year, today.month, today.day);
    _generateWeekDates();
  }

  void _generateWeekDates() {
    final today = DateTime.now();
    final monday = today
        .subtract(Duration(days: today.weekday - 1))
        .add(Duration(days: _weekOffset * 7));
    _weekDates = List.generate(7, (index) {
      final d = monday.add(Duration(days: index));
      return DateTime(d.year, d.month, d.day);
    });
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _getWeekdayName(int weekday) {
    return switch (weekday) {
      1 => 'T2',
      2 => 'T3',
      3 => 'T4',
      4 => 'T5',
      5 => 'T6',
      6 => 'T7',
      7 => 'CN',
      _ => '',
    };
  }

  Color _colorForKind(ScheduleDisplayKind kind) {
    return switch (kind) {
      ScheduleDisplayKind.upcoming => Colors.blue,
      ScheduleDisplayKind.ongoing => Colors.orange,
      ScheduleDisplayKind.pending => Colors.amber,
      ScheduleDisplayKind.completed => Colors.grey,
      ScheduleDisplayKind.cancelled => Colors.red.shade300,
    };
  }

  Future<void> _openJobDetail(ScheduleModel schedule) async {
    if (schedule.jobId.isEmpty) {
      _showMessage('Không tìm thấy mã công việc.');
      return;
    }

    try {
      final job = await _jobPostService.getJobPostById(schedule.jobId);
      if (!mounted) return;

      if (job == null) {
        _showMessage('Bài đăng này không còn tồn tại.');
        return;
      }

      Get.toNamed(
        AppRoutes.jobDetail,
        arguments: {'job': job, 'readOnlyNoBottom': true},
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage('Không tải được chi tiết công việc.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty) {
      return Scaffold(
        appBar: _appBar(),
        body: const Center(child: Text('Vui lòng đăng nhập để xem lịch làm')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _appBar(),
      body: StreamBuilder<List<ScheduleModel>>(
        stream: _scheduleService.watchByCandidate(_uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Column(
              children: [
                _buildDateSelector(const {}),
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          }
          if (snap.hasError) {
            return Column(
              children: [
                _buildDateSelector(const {}),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Không tải được lịch: ${snap.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          final all = snap.data ?? [];
          final weekStart = _weekDates.first;
          final weekEnd = _weekDates.last;
          final weekSchedules = ScheduleService.filterByDateRange(
            all,
            weekStart,
            weekEnd,
          );
          final daysWithShifts = {for (final s in weekSchedules) s.date: true};
          final dayShifts = ScheduleService.forDay(all, _selectedDate);

          return Column(
            children: [
              _buildDateSelector(daysWithShifts),
              Expanded(child: _buildShiftsList(dayShifts)),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      title: const Text(
        'Lịch làm việc',
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.black87),
      centerTitle: true,
    );
  }

  Widget _buildDateSelector(Map<String, bool> daysWithShifts) {
    String fullWeekdayName = 'Chủ nhật';
    if (_selectedDate.weekday != 7) {
      fullWeekdayName = 'Thứ ${_selectedDate.weekday + 1}';
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '$fullWeekdayName, ${_selectedDate.day} tháng ${_selectedDate.month}, ${_selectedDate.year}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Container(
          color: Colors.white,
          height: 80,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.black54),
                onPressed: () {
                  setState(() {
                    _weekOffset--;
                    _generateWeekDates();
                  });
                },
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _weekDates.map((date) {
                    final isSelected = date.isAtSameMomentAs(_selectedDate);
                    final now = DateTime.now();
                    final isToday = date.isAtSameMomentAs(
                      DateTime(now.year, now.month, now.day),
                    );
                    final hasShift =
                        daysWithShifts[_formatDateKey(date)] == true;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedDate = date);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? _primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? _primary
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _getWeekdayName(date.weekday),
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${date.day}',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isToday || hasShift)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: hasShift && !isSelected
                                        ? _primary
                                        : (isSelected
                                              ? Colors.white
                                              : _primary),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.black54),
                onPressed: () {
                  setState(() {
                    _weekOffset++;
                    _generateWeekDates();
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShiftsList(List<ScheduleModel> shifts) {
    if (shifts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Không có ca làm việc nào',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Lịch làm việc tự động hiển thị dựa trên các công việc bạn đã ứng tuyển hoặc được phân công.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: shifts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final s = shifts[index];
        final kind = ScheduleService.displayKind(s);
        final statusColor = _colorForKind(kind);
        final statusLabel = kind.label;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openJobDetail(s),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                s.timeRange,
                                style: TextStyle(
                                  color: _primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            s.jobTitle ?? 'Công việc',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.storefront_outlined,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  s.employerName ?? 'Nhà tuyển dụng',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (s.jobLocation != null &&
                              s.jobLocation!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    s.jobLocation!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
