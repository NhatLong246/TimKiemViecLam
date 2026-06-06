import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/constants/full_time_policy.dart';
import '../../common/styles/app_colors.dart';
import '../../controller/candidates_controller.dart';
import '../../data/models/application_model.dart';
import '../../data/models/candidate_profile_models.dart';
import '../../data/models/job_post_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/work_experience_model.dart';
import '../../data/services/candidate_discovery_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'employer_reviews_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EmployerCandidatesScreen
// Hiển thị danh sách ứng viên ứng tuyển vào bài đăng, chia theo Full-time / Part-time
// ─────────────────────────────────────────────────────────────────────────────
class EmployerCandidatesScreen extends StatefulWidget {
  const EmployerCandidatesScreen({super.key});

  @override
  State<EmployerCandidatesScreen> createState() =>
      _EmployerCandidatesScreenState();
}

class _EmployerCandidatesScreenState extends State<EmployerCandidatesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final CandidatesController _ctrl;
  String? _forcedJobType;
  bool _acceptedOnly = false;

  String? get _filterJobId => _ctrl.filterJobId;
  bool get _isSingleTypeView =>
      _forcedJobType == 'full_time' || _forcedJobType == 'part_time';
  bool get _singleIsFullTime => _forcedJobType == 'full_time';

  @override
  void initState() {
    super.initState();
    final reusedController = Get.isRegistered<CandidatesController>();
    _ctrl = reusedController
        ? Get.find<CandidatesController>()
        : Get.put(CandidatesController());
    final args = Get.arguments;
    final routeJobId = args is Map ? args['jobId']?.toString() : null;
    final routeJobType = args is Map ? args['jobType']?.toString() : null;
    _acceptedOnly = args is Map && args['acceptedOnly'] == true;
    _forcedJobType =
        (routeJobType == 'full_time' || routeJobType == 'part_time')
        ? routeJobType
        : null;
    _tabs = TabController(length: _isSingleTypeView ? 1 : 2, vsync: this);
    _ctrl.setFilterJobId(routeJobId);
    if (reusedController) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ctrl.loadAll();
      });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [_buildAppBar()],
        body: TabBarView(
          controller: _tabs,
          children: _isSingleTypeView
              ? [
                  _CandidatesTab(
                    ctrl: _ctrl,
                    isFullTime: _singleIsFullTime,
                    acceptedOnly: _acceptedOnly,
                  ),
                ]
              : [
                  _CandidatesTab(
                    ctrl: _ctrl,
                    isFullTime: true,
                    acceptedOnly: _acceptedOnly,
                  ),
                  _CandidatesTab(
                    ctrl: _ctrl,
                    isFullTime: false,
                    acceptedOnly: _acceptedOnly,
                  ),
                ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 0,
      backgroundColor: AppColors.employerPrimary,
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: AppColors.employerGradient),
      ),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 20,
        ),
        onPressed: Get.back,
      ),
      title: Text(
        _acceptedOnly
            ? 'User đã thuê'
            : (_filterJobId != null ? 'Ứng viên bài đăng' : 'Ứng viên'),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        Obx(() {
          final loading =
              _ctrl.isLoadingFullTime.value || _ctrl.isLoadingPartTime.value;
          return loading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _ctrl.loadAll,
                  tooltip: 'Tải lại',
                );
        }),
      ],
      bottom: _isSingleTypeView
          ? PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: Container(
                height: 44,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _acceptedOnly
                      ? 'Chỉ hiển thị user đã thuê'
                      : (_singleIsFullTime ? 'Full-time' : 'Part-time'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          : TabBar(
              controller: _tabs,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 14,
              ),
              tabs: [
                _TabLabel(
                  label: 'Full-time',
                  badge: _ctrl.pendingFullTimeCount,
                ),
                _TabLabel(
                  label: 'Part-time',
                  badge: _ctrl.pendingPartTimeCount,
                ),
              ],
            ),
    );
  }
}

// ─── Tab widget ───────────────────────────────────────────────────────────────
class _CandidatesTab extends StatelessWidget {
  final CandidatesController ctrl;
  final bool isFullTime;
  final bool acceptedOnly;

  const _CandidatesTab({
    required this.ctrl,
    required this.isFullTime,
    this.acceptedOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = isFullTime
          ? ctrl.isLoadingFullTime.value
          : ctrl.isLoadingPartTime.value;
      final rawJobs = isFullTime
          ? ctrl.filteredFullTimeJobs()
          : ctrl.filteredPartTimeJobs();
      final jobs = acceptedOnly
          ? rawJobs
                .map(
                  (job) => job.copyWithEntries(
                    job.entries
                        .where((e) => e.application.status == 'accepted')
                        .toList(),
                  ),
                )
                .where((job) => job.entries.isNotEmpty)
                .toList()
          : rawJobs;
      final onRefresh = isFullTime ? ctrl.loadFullTime : ctrl.loadPartTime;

      if (loading && jobs.isEmpty) {
        return RefreshIndicator(
          color: AppColors.employerPrimary,
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(
                height: 280,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.employerPrimary,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      if (jobs.isEmpty) {
        return RefreshIndicator(
          color: AppColors.employerPrimary,
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.65,
                child: _EmptyState(
                  isFullTime: isFullTime,
                  isFilteredByJob: ctrl.filterJobId != null,
                  acceptedOnly: acceptedOnly,
                ),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        color: AppColors.employerPrimary,
        onRefresh: onRefresh,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: jobs.length + (isFullTime && !acceptedOnly ? 1 : 0),
          itemBuilder: (_, i) {
            if (isFullTime && !acceptedOnly && i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Color(0xFF1565C0),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          kFullTimeEmployerNotice,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            final jobIndex = isFullTime && !acceptedOnly ? i - 1 : i;
            return _JobCard(
              jwA: jobs[jobIndex],
              ctrl: ctrl,
              readOnly: acceptedOnly,
            );
          },
        ),
      );
    });
  }
}

// ─── Job card (expandable) ────────────────────────────────────────────────────
class _JobCard extends StatefulWidget {
  final JobWithApplications jwA;
  final CandidatesController ctrl;
  final bool readOnly;

  const _JobCard({
    required this.jwA,
    required this.ctrl,
    this.readOnly = false,
  });

  @override
  State<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<_JobCard> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    final filterId = widget.ctrl.filterJobId;
    _expanded =
        widget.jwA.pendingCount > 0 ||
        (filterId != null && filterId == widget.jwA.job.jobId);
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.jwA.job;
    final entries = widget.jwA.entries;
    final pending = widget.jwA.pendingCount;
    final overflowPendingIds = widget.jwA.overflowPendingApplicationIds;
    final canQuickReject = !widget.readOnly && overflowPendingIds.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header tap để mở rộng ─────────────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(14),
              bottom: _expanded ? Radius.zero : const Radius.circular(14),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Trạng thái job chip
                      _JobStatusChip(status: job.status),
                      const Spacer(),
                      // Slot progress
                      _SlotBadge(filled: job.filledSlots, total: job.slots),
                      const SizedBox(width: 8),
                      // Pending badge
                      if (pending > 0) _PendingBadge(count: pending),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey.shade500,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    job.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          job.locationDisplay,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.attach_money_rounded,
                        size: 13,
                        color: Colors.grey.shade500,
                      ),
                      Text(
                        job.salaryDisplay,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.employerPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 13,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        widget.readOnly
                            ? '${entries.length} user đã thuê'
                            : '${entries.length} ứng viên',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        DateFormat('dd/MM/yyyy').format(job.startDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Danh sách ứng viên (khi mở rộng) ─────────────────────────────
          if (_expanded) ...[
            Divider(height: 1, color: Colors.grey.shade100),
            if (canQuickReject)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmRejectRemaining(
                      context,
                      job.jobId,
                      overflowPendingIds.length,
                    ),
                    icon: const Icon(Icons.block_rounded, size: 16),
                    label: Text(
                      'Từ chối nhanh ${overflowPendingIds.length} ứng viên còn lại',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            if (entries.isEmpty)
              _NoApplicants()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entries.length,
                separatorBuilder: (context, index) =>
                    Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (_, i) => _ApplicantTile(
                  entry: entries[i],
                  job: widget.jwA.job,
                  ctrl: widget.ctrl,
                  readOnly: widget.readOnly,
                  isOverflowRejected: overflowPendingIds.contains(
                    entries[i].application.appId,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmRejectRemaining(
    BuildContext ctx,
    String jobId,
    int count,
  ) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => _ConfirmDialog(
        title: 'Từ chối nhanh',
        content: 'Từ chối $count ứng viên còn lại và gửi thông báo cho họ?',
        confirmLabel: 'Từ chối',
        confirmColor: Colors.red,
      ),
    );
    if (confirmed == true) widget.ctrl.rejectRemaining(jobId);
  }
}

// ─── Applicant tile ───────────────────────────────────────────────────────────
class _ApplicantTile extends StatelessWidget {
  final ApplicationEntry entry;
  final JobPostModel job;
  final CandidatesController ctrl;
  final bool readOnly;
  final bool isOverflowRejected;

  const _ApplicantTile({
    required this.entry,
    required this.job,
    required this.ctrl,
    this.readOnly = false,
    this.isOverflowRejected = false,
  });

  @override
  Widget build(BuildContext context) {
    final app = entry.application;
    final candidate = entry.candidate;
    final displayStatus = isOverflowRejected ? 'rejected' : app.status;
    final isPending = app.status == 'pending' && !isOverflowRejected;
    final isAccepted = app.status == 'accepted';

    return InkWell(
      onTap: () {
        Get.bottomSheet(
          _CandidateProfileSheet(candidateSnap: candidate, app: app),
          isScrollControlled: true,
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar + tên + rating ────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CandidateAvatar(candidate: candidate),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate.fullName.isNotEmpty
                            ? candidate.fullName
                            : 'Ứng viên',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          _StarRating(rating: candidate.averageRating),
                          const SizedBox(width: 6),
                          Text(
                            candidate.averageRating > 0
                                ? candidate.averageRating.toStringAsFixed(1)
                                : 'Chưa có',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.work_outline,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${candidate.totalJobsDone} việc',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            app.appliedAt != null
                                ? 'Nộp ${DateFormat('dd/MM/yyyy').format(app.appliedAt!)}'
                                : 'Vừa nộp',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status chip
                _AppStatusChip(status: displayStatus),
              ],
            ),

            if (isOverflowRejected) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.block_rounded,
                    size: 13,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Tự động từ chối do vượt số lượng tuyển',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // ── Cover letter (nếu có, rút gọn 2 dòng) ───────────────────────
            if (app.coverLetter?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  app.coverLetter!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            // ── CV link (chỉ full-time) ──────────────────────────────────────
            if (app.cvUrl?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.tryParse(app.cvUrl!);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.picture_as_pdf,
                      size: 14,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Xem CV',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.employerSecondary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Action buttons (chỉ pending) ─────────────────────────────────
            if (!readOnly && isPending) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _confirmReject(context, app.appId),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Từ chối',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: job.isFull
                          ? null
                          : () => _confirmAccept(context, app.appId, job.jobId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.employerPrimary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        job.isFull
                            ? 'Đã đủ slot'
                            : (job.isFullTimeReferral
                                  ? 'Ghi nhận & liên hệ'
                                  : 'Duyệt'),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // ── Huỷ duyệt button (nếu accepted) ─────────────────────────────
            if (!readOnly && isAccepted) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () =>
                      _confirmRevoke(context, app.appId, job.jobId),
                  icon: Icon(
                    Icons.undo_rounded,
                    size: 14,
                    color: Colors.orange.shade700,
                  ),
                  label: Text(
                    'Huỷ duyệt',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAccept(
    BuildContext ctx,
    String appId,
    String jobId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => _ConfirmDialog(
        title: job.isFullTimeReferral
            ? 'Ghi nhận ứng viên Full-time'
            : 'Duyệt ứng viên',
        content: job.isFullTimeReferral
            ? 'Bạn ghi nhận ứng viên quan tâm. Vui lòng liên hệ trực tiếp để phỏng vấn — ViecNow không quản lý việc Full-time.'
            : 'Bạn chắc chắn muốn duyệt ứng viên này?',
        confirmLabel: job.isFullTimeReferral ? 'Ghi nhận' : 'Duyệt',
        confirmColor: AppColors.employerPrimary,
      ),
    );
    if (confirmed == true) ctrl.accept(appId, jobId);
  }

  Future<void> _confirmReject(BuildContext ctx, String appId) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => const _ConfirmDialog(
        title: 'Từ chối ứng viên',
        content: 'Bạn chắc chắn muốn từ chối ứng viên này?',
        confirmLabel: 'Từ chối',
        confirmColor: Colors.red,
      ),
    );
    if (confirmed == true) ctrl.reject(appId);
  }

  Future<void> _confirmRevoke(
    BuildContext ctx,
    String appId,
    String jobId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => _ConfirmDialog(
        title: 'Huỷ duyệt',
        content: 'Ứng viên sẽ trở về trạng thái chờ duyệt?',
        confirmLabel: 'Huỷ duyệt',
        confirmColor: Colors.orange.shade700,
      ),
    );
    if (confirmed == true) ctrl.revokeAcceptance(appId, jobId);
  }
}

// ─── Small reusable widgets ───────────────────────────────────────────────────

class _TabLabel extends StatelessWidget {
  final String label;
  final int badge;

  const _TabLabel({required this.label, required this.badge});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (badge > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade400,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge > 99 ? '99+' : '$badge',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _JobStatusChip extends StatelessWidget {
  final String status;

  const _JobStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'active' => ('Đang tuyển', Colors.green),
      'approved' => ('Đã duyệt', Colors.blue),
      'closed' => ('Đã đóng', Colors.grey),
      'pending' => ('Chờ duyệt', Colors.orange),
      'rejected' => ('Bị từ chối', Colors.red),
      _ => (status, Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _SlotBadge extends StatelessWidget {
  final int filled;
  final int total;

  const _SlotBadge({required this.filled, required this.total});

  @override
  Widget build(BuildContext context) {
    final isFull = filled >= total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isFull
            ? Colors.red.withValues(alpha: 0.1)
            : AppColors.employerPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$filled/$total tuyển',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isFull ? Colors.red.shade700 : AppColors.employerPrimary,
        ),
      ),
    );
  }
}

class _PendingBadge extends StatelessWidget {
  final int count;

  const _PendingBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Text(
        '$count chờ',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.orange.shade800,
        ),
      ),
    );
  }
}

class _AppStatusChip extends StatelessWidget {
  final String status;

  const _AppStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'pending' => ('Chờ duyệt', Colors.orange.shade50, Colors.orange.shade800),
      'accepted' => ('Đã duyệt', Colors.green.shade50, Colors.green.shade800),
      'rejected' => ('Từ chối', Colors.red.shade50, Colors.red.shade800),
      'withdrawn' => ('Đã hủy', Colors.grey.shade100, Colors.grey.shade700),
      _ => (status, Colors.grey.shade100, Colors.grey.shade700),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _CandidateProfileSheet extends StatefulWidget {
  final CandidateSnapshot candidateSnap;
  final ApplicationModel app;

  const _CandidateProfileSheet({
    required this.candidateSnap,
    required this.app,
  });

  @override
  State<_CandidateProfileSheet> createState() => _CandidateProfileSheetState();
}

class _CandidateProfileSheetState extends State<_CandidateProfileSheet> {
  UserModel? _fullUser;
  Map<String, dynamic>? _fullUserData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _recordProfileView();
    _fetchFullUser();
  }

  Future<void> _recordProfileView() async {
    await CandidateDiscoveryService().recordProfileView(
      candidateId: widget.candidateSnap.uid,
      employerId: widget.app.employerId,
    );
  }

  Future<void> _fetchFullUser() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.candidateSnap.uid)
          .get();
      if (doc.exists) {
        if (mounted) {
          setState(() {
            final data = Map<String, dynamic>.from(doc.data()!);
            data['uid'] = doc.id;
            _fullUserData = data;
            _fullUser = UserModel.fromMap(data);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _CandidateAvatar(candidate: widget.candidateSnap),
              const SizedBox(height: 16),
              Text(
                widget.candidateSnap.fullName.isNotEmpty
                    ? widget.candidateSnap.fullName
                    : 'Ứng viên',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StarRating(rating: widget.candidateSnap.averageRating),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.candidateSnap.averageRating.toStringAsFixed(1)} sao • ${widget.candidateSnap.totalJobsDone} việc',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                )
              else if (_fullUser != null) ...[
                _buildInfoRow(
                  Icons.email_outlined,
                  'Email',
                  _fullUser!.email.isNotEmpty
                      ? _fullUser!.email
                      : 'Chưa cập nhật',
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  Icons.phone_outlined,
                  'Số điện thoại',
                  _fullUser!.phone.isNotEmpty
                      ? _fullUser!.phone
                      : 'Chưa cập nhật',
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  Icons.person_outline,
                  'Giới tính',
                  _fullUser!.gender ?? 'Chưa cập nhật',
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  Icons.cake_outlined,
                  'Ngày sinh',
                  _fullUser!.dateOfBirth != null
                      ? DateFormat('dd/MM/yyyy').format(_fullUser!.dateOfBirth!)
                      : 'Chưa cập nhật',
                ),
                ..._buildProfileExtras(
                  _fullUserData ?? const <String, dynamic>{},
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Đóng bottom sheet
                      Get.to(
                        () => const EmployerReviewsScreen(),
                        arguments: {
                          'uid': widget.candidateSnap.uid,
                          'title':
                              'Đánh giá về ${widget.candidateSnap.fullName.isNotEmpty ? widget.candidateSnap.fullName : 'ứng viên'}',
                        },
                      );
                    },
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text(
                      'Xem đánh giá về ứng viên',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.employerPrimary,
                      side: const BorderSide(color: AppColors.employerPrimary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ] else
                Text(
                  'Không thể lấy thông tin chi tiết.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.employerPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Đóng',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _effectiveCvUrl {
    final appCv = widget.app.cvUrl?.trim() ?? '';
    if (appCv.isNotEmpty) return appCv;
    return (_fullUserData?['cvUrl'] ?? '').toString().trim();
  }

  List<Widget> _buildProfileExtras(Map<String, dynamic> data) {
    final widgets = <Widget>[];
    final cvUrl = _effectiveCvUrl;
    if (cvUrl.isNotEmpty) {
      widgets.addAll([const SizedBox(height: 16), _buildCvAction(cvUrl)]);
    }

    final introduction = selfIntroductionFromUserData(data);
    if (introduction.isNotEmpty) {
      widgets.addAll([
        const SizedBox(height: 18),
        _buildProfileTextBlock('Giới thiệu', introduction),
      ]);
    }

    final skills = skillsFromUserData(data);
    if (skills.isNotEmpty) {
      widgets.addAll([
        const SizedBox(height: 18),
        _buildProfileChips('Kỹ năng', skills),
      ]);
    }

    final experiences = WorkExperienceModel.listFromUserData(data);
    if (experiences.isNotEmpty) {
      widgets.addAll([
        const SizedBox(height: 18),
        _buildProfileLineList(
          'Kinh nghiệm',
          experiences
              .map(
                (item) => _ProfileLine(
                  title: [
                    item.position,
                    item.company,
                  ].where((v) => v.trim().isNotEmpty).join(' - '),
                  subtitle: [
                    item.dateRange,
                    item.description,
                  ].where((v) => v.trim().isNotEmpty).join('\n'),
                ),
              )
              .toList(),
        ),
      ]);
    } else if (WorkExperienceModel.hasDeclaredNoExperience(data)) {
      widgets.addAll([
        const SizedBox(height: 18),
        _buildProfileTextBlock(
          'Kinh nghiệm',
          'Ứng viên khai báo chưa có kinh nghiệm.',
        ),
      ]);
    }

    final educations = EducationModel.listFromUserData(data);
    if (educations.isNotEmpty) {
      widgets.addAll([
        const SizedBox(height: 18),
        _buildProfileLineList(
          'Học vấn',
          educations
              .map(
                (item) => _ProfileLine(
                  title: [
                    item.school,
                    item.major,
                  ].where((v) => v.trim().isNotEmpty).join(' - '),
                  subtitle: [
                    item.degree,
                    item.yearRange,
                    item.description,
                  ].where((v) => v.trim().isNotEmpty).join('\n'),
                ),
              )
              .toList(),
        ),
      ]);
    }

    final projects = ProjectModel.listFromUserData(data);
    if (projects.isNotEmpty) {
      widgets.addAll([
        const SizedBox(height: 18),
        _buildProfileLineList(
          'Dự án',
          projects
              .map(
                (item) => _ProfileLine(
                  title: item.name,
                  subtitle: [
                    item.dateRange,
                    item.description,
                  ].where((v) => v.trim().isNotEmpty).join('\n'),
                ),
              )
              .toList(),
        ),
      ]);
    }

    final certificates = CertificateModel.listFromUserData(data);
    if (certificates.isNotEmpty) {
      widgets.addAll([
        const SizedBox(height: 18),
        _buildProfileLineList(
          'Chứng chỉ',
          certificates
              .map((item) => _ProfileLine(title: item.name, subtitle: ''))
              .toList(),
        ),
      ]);
    }

    final languages = LanguageModel.listFromUserData(data);
    if (languages.isNotEmpty) {
      widgets.addAll([
        const SizedBox(height: 18),
        _buildProfileLineList(
          'Ngoại ngữ',
          languages
              .map(
                (item) =>
                    _ProfileLine(title: item.language, subtitle: item.level),
              )
              .toList(),
        ),
      ]);
    }

    return widgets;
  }

  Widget _buildCvAction(String url) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final uri = Uri.tryParse(url);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        icon: const Icon(Icons.description_outlined),
        label: const Text(
          'Xem CV ứng viên',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.employerPrimary,
          side: const BorderSide(color: AppColors.employerPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildProfileTextBlock(String title, String value) {
    return _buildProfileSection(
      title,
      Text(
        value,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade700,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildProfileChips(String title, List<String> values) {
    return _buildProfileSection(
      title,
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: values
            .map(
              (item) => Chip(
                label: Text(item),
                backgroundColor: Colors.blue.shade50,
                labelStyle: const TextStyle(
                  color: AppColors.employerPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(color: Colors.blue.shade100),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildProfileLineList(String title, List<_ProfileLine> lines) {
    return _buildProfileSection(
      title,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((line) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.title.isNotEmpty ? line.title : 'Chưa cập nhật',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (line.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    line.subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade600,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProfileSection(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.employerPrimary, size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileLine {
  final String title;
  final String subtitle;

  const _ProfileLine({required this.title, required this.subtitle});
}

class _CandidateAvatar extends StatelessWidget {
  final CandidateSnapshot candidate;

  const _CandidateAvatar({required this.candidate});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.employerPrimary.withValues(alpha: 0.12),
      backgroundImage: candidate.avatarUrl?.isNotEmpty == true
          ? NetworkImage(candidate.avatarUrl!)
          : null,
      child: candidate.avatarUrl?.isNotEmpty != true
          ? Text(
              candidate.fullName.isNotEmpty
                  ? candidate.fullName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: AppColors.employerPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            )
          : null,
    );
  }
}

class _StarRating extends StatelessWidget {
  final double rating;

  const _StarRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < rating.floor()) {
          return Icon(
            Icons.star_rounded,
            size: 13,
            color: Colors.amber.shade500,
          );
        } else if (i < rating && rating - i >= 0.5) {
          return Icon(
            Icons.star_half_rounded,
            size: 13,
            color: Colors.amber.shade500,
          );
        }
        return Icon(
          Icons.star_outline_rounded,
          size: 13,
          color: Colors.grey.shade300,
        );
      }),
    );
  }
}

class _NoApplicants extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 36, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              'Chưa có ứng viên nào',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isFullTime;
  final bool isFilteredByJob;
  final bool acceptedOnly;

  const _EmptyState({
    required this.isFullTime,
    this.isFilteredByJob = false,
    this.acceptedOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.employerPrimary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_alt_outlined,
                size: 40,
                color: AppColors.employerPrimary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              acceptedOnly
                  ? 'Chưa có user đã thuê'
                  : isFilteredByJob
                  ? 'Chưa có ứng viên ứng tuyển'
                  : (isFullTime
                        ? 'Chưa có bài đăng Full-time'
                        : 'Chưa có bài đăng Part-time'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              acceptedOnly
                  ? 'Bài đăng này chưa có ứng viên nào ở trạng thái đã duyệt.'
                  : isFilteredByJob
                  ? 'Bài đăng này chưa có đơn ứng tuyển nào.'
                  : 'Tạo bài đăng tuyển dụng để bắt đầu\nnhận đơn ứng tuyển từ ứng viên.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmLabel;
  final Color confirmColor;

  const _ConfirmDialog({
    required this.title,
    required this.content,
    required this.confirmLabel,
    required this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      content: Text(
        content,
        style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Huỷ', style: TextStyle(color: Colors.grey.shade600)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
