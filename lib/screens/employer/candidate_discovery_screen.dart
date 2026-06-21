import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/job_criteria_model.dart';
import '../../data/models/job_post_model.dart';
import '../../data/models/user_model.dart';
import '../../data/services/candidate_discovery_service.dart';
import 'candidate_profile_screen.dart';
import 'hire_request_sheet.dart';

class CandidateDiscoveryScreen extends StatefulWidget {
  const CandidateDiscoveryScreen({super.key, this.fullTimeOnly = false});

  final bool fullTimeOnly;

  @override
  State<CandidateDiscoveryScreen> createState() =>
      _CandidateDiscoveryScreenState();
}

class _CandidateDiscoveryScreenState extends State<CandidateDiscoveryScreen> {
  final CandidateDiscoveryService _service = CandidateDiscoveryService();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String _query = '';
  List<DiscoverableCandidate>? _candidates;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCandidates() async {
    setState(() => _isLoading = true);
    try {
      final list = widget.fullTimeOnly
          ? await _service.fetchFullTimeCandidates(keyword: _query)
          : await _service.fetchPotentialCandidates(keyword: _query);
      setState(() => _candidates = list);
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể tải danh sách ứng viên');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String val) {
    _query = val.trim();
    // Debounce nhẹ
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (_query == val.trim()) {
        _loadCandidates();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF7B1FA2), Color(0xFF1565C0)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: Get.back,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.fullTimeOnly
                          ? 'Khám phá ứng viên Full-time'
                          : 'Danh sách người làm tiềm năng',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Search input
              Container(
                height: 46,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(
                      Icons.search_rounded,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        focusNode: _focusNode,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1A1A2E),
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'Tìm theo tên, chuyên môn...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    final list = _candidates ?? [];
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search_rounded,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _query.isNotEmpty
                  ? 'Không tìm thấy ứng viên phù hợp'
                  : 'Chưa có ứng viên nào công khai hồ sơ',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: list.length,
      itemBuilder: (_, i) => _CandidateCard(
        item: list[i],
        jobTypeFilter: widget.fullTimeOnly ? 'full_time' : null,
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.item, this.jobTypeFilter});

  final DiscoverableCandidate item;
  final String? jobTypeFilter;

  @override
  Widget build(BuildContext context) {
    final user = item.user;
    final crit = item.criteria ?? const JobCriteriaModel();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryText = Theme.of(context).colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: () => Get.to(() => CandidateProfileScreen(candidate: user)),
      child: Container(
        margin: const EdgeInsets.fromLTRB(2, 2, 2, 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF30203B), Color(0xFF202A42)]
                : const [Color(0xFFFAF1FF), Color(0xFFF0F4FF)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(
              0xFF8E24AA,
            ).withValues(alpha: isDark ? 0.55 : 0.32),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7B1FA2).withValues(alpha: 0.16),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar & Name
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF8E24AA), Color(0xFF1565C0)],
                      ),
                    ),
                    child: ClipOval(
                      child: ColoredBox(
                        color: isDark
                            ? const Color(0xFF33253E)
                            : const Color(0xFFF3E5F5),
                        child:
                            user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                            ? Image.network(
                                user.avatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _avatarFallback(user.fullName),
                              )
                            : _avatarFallback(user.fullName),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName.isNotEmpty
                              ? user.fullName
                              : 'Chưa cập nhật tên',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Colors.orange.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              user.averageRating > 0
                                  ? user.averageRating.toStringAsFixed(1)
                                  : 'Chưa có',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: secondaryText,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 14,
                              color: Colors.green.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${user.totalJobsDone} việc',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Criteria
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.66),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF8E24AA).withValues(alpha: 0.16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (crit.position.isNotEmpty) ...[
                      Text(
                        'Vị trí mong muốn: ${crit.position}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (crit.careers.isNotEmpty) ...[
                      Text(
                        'Ngành nghề: ${crit.careers.join(", ")}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (crit.locations.isNotEmpty) ...[
                      Text(
                        'Khu vực: ${crit.locations.join(", ")}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (crit.salaryDisplay != null) ...[
                      Text(
                        'Mức lương: ${crit.salaryDisplay}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7B1FA2),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Nút "Gửi quan tâm"
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text(
                    'Gửi yêu cầu thuê',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B1FA2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                    shadowColor: const Color(
                      0xFF7B1FA2,
                    ).withValues(alpha: 0.35),
                  ),
                  onPressed: () async {
                    final employerId = FirebaseAuth.instance.currentUser?.uid;
                    if (employerId != null && employerId.isNotEmpty) {
                      await CandidateDiscoveryService().recordProfileView(
                        candidateId: user.id,
                        employerId: employerId,
                      );
                    }
                    if (!context.mounted) return;
                    showHireRequestSheet(
                      context: context,
                      candidateId: user.id,
                      candidateName: user.fullName.isEmpty
                          ? 'Người làm'
                          : user.fullName,
                      jobTypeFilter: jobTypeFilter,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      color: const Color(0xFF1565C0),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class SendInterestSheet extends StatefulWidget {
  final UserModel candidate;
  final String? jobTypeFilter;
  const SendInterestSheet({
    super.key,
    required this.candidate,
    this.jobTypeFilter = 'full_time',
  });

  @override
  State<SendInterestSheet> createState() => _SendInterestSheetState();
}

class _SendInterestSheetState extends State<SendInterestSheet> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _service = CandidateDiscoveryService();

  List<JobPostModel>? _jobs;
  bool _isLoading = true;
  String? _sendingJobId;
  Set<String> _sentJobIds = {};

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      var query = _db
          .collection('jobPosts')
          .where('employerId', isEqualTo: uid)
          .where('status', whereIn: ['active', 'approved']);

      if (widget.jobTypeFilter != null) {
        query = query.where('jobType', isEqualTo: widget.jobTypeFilter);
      }

      final snap = await query.get();

      final appsSnap = await _db
          .collection('applications')
          .where('candidateId', isEqualTo: widget.candidate.id)
          .where('employerId', isEqualTo: uid)
          .get();
      final doneJobIds = appsSnap.docs
          .map((d) => d.data()['jobId'] as String?)
          .where((id) => id != null)
          .toSet();

      final interestsSnap = await _db
          .collection('employerInterests')
          .where('candidateId', isEqualTo: widget.candidate.id)
          .where('employerId', isEqualTo: uid)
          .get();
      final sentJobIds = interestsSnap.docs
          .map((d) => (d.data())['jobId'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toSet();

      final now = DateTime.now();
      final list = snap.docs
          .map((d) {
            final data = d.data();
            data['jobId'] = d.id;
            return JobPostModel.fromMap(data);
          })
          .where((job) {
            if (doneJobIds.contains(job.jobId)) return false;
            // Bỏ qua việc đã quá hạn ứng tuyển
            if (job.applicationDeadline != null &&
                job.applicationDeadline!.isBefore(now))
              return false;
            // Bỏ qua việc đã qua ngày kết thúc
            if (job.endDate != null && job.endDate!.isBefore(now)) return false;
            // Bỏ qua việc làm 1 ngày nhưng ngày bắt đầu đã qua (hôm qua trở về trước)
            if (job.endDate == null &&
                job.startDate.add(const Duration(days: 1)).isBefore(now))
              return false;
            return true;
          })
          .toList();

      if (mounted) {
        setState(() {
          _jobs = list;
          _sentJobIds = sentJobIds;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendInterest(JobPostModel job) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() => _sendingJobId = job.jobId);

    try {
      // Lấy tên NTD
      final employerDoc = await _db.collection('users').doc(uid).get();
      final employerName =
          employerDoc.data()?['companyName'] ??
          employerDoc.data()?['firstName'] ??
          'Nhà tuyển dụng';

      final success = await _service.sendInterestNotification(
        candidateId: widget.candidate.id,
        employerId: uid,
        employerName: employerName.toString(),
        jobId: job.jobId,
        jobTitle: job.title,
      );

      Get.back(); // Đóng sheet

      if (success) {
        if (mounted) {
          setState(() {
            _sentJobIds.add(job.jobId);
          });
        }
        Get.snackbar(
          'Thành công',
          'Đã gửi thông báo quan tâm đến ứng viên',
          backgroundColor: Colors.green.shade600,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          'Thông báo',
          'Bạn đã gửi lời mời cho ứng viên này với công việc này rồi.',
          backgroundColor: Colors.orange.shade600,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.back();
      Get.snackbar('Lỗi', 'Có lỗi xảy ra, vui lòng thử lại sau.');
    } finally {
      if (mounted) {
        setState(() => _sendingJobId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.jobTypeFilter == 'full_time'
                  ? 'Chọn công việc Full-time'
                  : 'Chọn công việc',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Gửi lời mời đến ${widget.candidate.fullName}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    )
                  : (_jobs == null || _jobs!.isEmpty)
                  ? Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.work_off_rounded,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.jobTypeFilter == 'full_time'
                                ? 'Bạn chưa có công việc Full-time nào đang tuyển.'
                                : 'Bạn chưa có công việc nào đang tuyển.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: _jobs!.length,
                      itemBuilder: (context, index) {
                        final job = _jobs![index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.work_rounded,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                          title: Text(
                            job.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Text(
                            job.salaryDisplay,
                            style: const TextStyle(
                              color: Color(0xFF7B1FA2),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          trailing: _sendingJobId == job.jobId
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : _sentJobIds.contains(job.jobId)
                              ? const Text(
                                  'Đã gửi',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : TextButton(
                                  onPressed: _sendingJobId != null
                                      ? null
                                      : () => _sendInterest(job),
                                  child: const Text('Gửi'),
                                ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
