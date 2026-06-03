import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../common/styles/app_colors.dart';
import '../../controller/login_controller.dart';
import '../../data/models/group_chat_model.dart';
import '../../data/models/work_schedule_model.dart';
import '../../data/models/job_post_model.dart';
import '../../data/services/work_schedule_service.dart';
import '../../data/services/job_post_service.dart';

/// Nhân viên xem phân công công việc (từ thông báo hoặc Quản lý nhóm).
class CandidateWorkAssignmentScreen extends StatefulWidget {
  const CandidateWorkAssignmentScreen({
    super.key,
    this.group,
    this.initialDate,
  });

  final GroupChatModel? group;
  final String? initialDate;

  @override
  State<CandidateWorkAssignmentScreen> createState() =>
      _CandidateWorkAssignmentScreenState();
}

class _CandidateWorkAssignmentScreenState
    extends State<CandidateWorkAssignmentScreen> {
  static const _primary = AppColors.candidatePrimary;

  final _scheduleSvc = WorkScheduleService();
  final _auth = Get.find<AuthController>();
  final _jobSvc = JobPostService();

  GroupChatModel? _group;
  JobPostModel? _jobPost;
  DateTime _selectedDate = DateTime.now();

  bool _loading = true;
  String? _error;
  WorkScheduleModel? _schedule;

  String get _uid => _auth.currentUser?.id ?? '';
  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _selectedDate = _parseInitialDate(null);
    _bootstrap();
  }

  DateTime _parseInitialDate(String? fromArgs) {
    if (widget.initialDate != null && widget.initialDate!.isNotEmpty) {
      return DateTime.parse(widget.initialDate!);
    }
    if (fromArgs != null && fromArgs.isNotEmpty) {
      return DateTime.parse(fromArgs);
    }
    return DateTime.now();
  }

  Future<void> _bootstrap() async {
    try {
      if (widget.group != null) {
        _group = widget.group;
      } else {
        final args = Get.arguments;
        String? groupId;
        String? dateStr;
        if (args is GroupChatModel) {
          _group = args;
        } else if (args is Map) {
          if (args['group'] is GroupChatModel) {
            _group = args['group'] as GroupChatModel;
          } else {
            groupId = (args['groupId'] ?? '').toString();
          }
          dateStr = (args['date'] ?? '').toString();
        }
        if (_group == null && groupId != null && groupId.isNotEmpty) {
          final snap = await FirebaseFirestore.instance
              .collection('groupChats')
              .doc(groupId)
              .get();
          if (!snap.exists) {
            throw Exception('Không tìm thấy nhóm');
          }
          _group = GroupChatModel.fromMap(snap.data()!, snap.id);
        }
        if (dateStr != null && dateStr.isNotEmpty) {
          _selectedDate = _parseInitialDate(dateStr);
        }
      }
      if (_group == null) {
        throw Exception('Thiếu thông tin nhóm');
      }

      _jobPost = await _jobSvc.getJobPostById(_group!.jobId);
      if (_jobPost != null) {
        final start = _startOfDay(_jobPost!.startDate);
        final end = _jobPost!.endDate != null 
            ? _startOfDay(_jobPost!.endDate!) 
            : start.add(const Duration(days: 365));
        final current = _startOfDay(_selectedDate);
        
        if (current.isBefore(start)) {
          _selectedDate = start;
        } else if (current.isAfter(end)) {
          _selectedDate = end;
        }
      }

      await _loadSchedule();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _scheduleSvc.getByDate(_group!.groupId, _dateStr);
      if (!mounted) return;
      setState(() {
        _schedule = s;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<WorkTask> get _myTasks {
    final s = _schedule;
    if (s == null) return [];
    return s.tasks.where((t) => t.userId == _uid).toList();
  }

  Future<void> _pickDate() async {
    final start = _jobPost != null ? _startOfDay(_jobPost!.startDate) : DateTime.now().subtract(const Duration(days: 30));
    final end = _jobPost?.endDate != null ? _startOfDay(_jobPost!.endDate!) : start.add(const Duration(days: 365));
    
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: start,
      lastDate: end,
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      await _loadSchedule();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: Get.back,
        ),
        title: const Text(
          'Phân công công việc',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _bootstrap,
              style: FilledButton.styleFrom(backgroundColor: _primary),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final s = _schedule;
    final myTasks = _myTasks;
    final dateLabel =
        DateFormat('EEEE, dd/MM/yyyy', 'vi').format(_selectedDate);

    return RefreshIndicator(
      color: _primary,
      onRefresh: _loadSchedule,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.candidateGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _group!.jobTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickDate,
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dateLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Icon(Icons.edit, color: Colors.white70, size: 18),
                    ],
                  ),
                ),
                if (s != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Ca làm: ${s.shiftStart} – ${s.shiftEnd}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (s == null)
            _emptyCard(
              'Chưa có phân công',
              'NTD chưa gửi phân công cho ngày này. Thử chọn ngày khác.',
            )
          else ...[
            if (s.generalContent.trim().isNotEmpty) ...[
              _sectionCard(
                icon: Icons.description_rounded,
                title: 'Yêu cầu chung',
                child: Text(
                  s.generalContent.trim(),
                  style: const TextStyle(fontSize: 14, height: 1.45),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _sectionCard(
              icon: Icons.assignment_ind_rounded,
              title: 'Việc được giao cho bạn',
              child: myTasks.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: myTasks.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          t.content.trim(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                          ),
                        ),
                      )).toList(),
                    )
                  : Text(
                      'Chưa có nội dung riêng. Xem yêu cầu chung phía trên.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyCard(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.assignment_outlined,
              size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _primary, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
