import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/constants/full_time_policy.dart';
import '../../controller/job_detail_controller.dart';
import '../../controller/login_controller.dart';
import '../../data/models/application_model.dart';
import '../../data/models/full_time_job_details.dart';
import '../../data/models/job_post_model.dart';
import '../../data/services/candidates_service.dart';
import '../../data/services/messaging_service.dart';
import '../messaging/chat_room_screen.dart';
import 'job_directions_map_screen.dart';

class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  late final JobDetailController _controller;
  final MessagingService _messagingService = MessagingService();
  final CandidatesService _candidatesService = CandidatesService();
  late JobPostModel job;
  bool _hasJob = false;
  bool _historyMode = false;
  bool _dialogShowing = false;
  bool _isLoadingHiredUsers = false;
  String? _hiredUsersError;
  List<ApplicationEntry> _hiredEntries = [];

  @override
  void initState() {
    super.initState();
    // Xóa controller cũ (nếu có) và tạo controller mới hoàn toàn
    if (Get.isRegistered<JobDetailController>()) {
      Get.delete<JobDetailController>(force: true);
    }
    _controller = Get.put(JobDetailController());

    final dynamic args = Get.arguments;
    final parsedJob = _jobFromArguments(args);
    if (parsedJob != null) {
      job = parsedJob;
      _hasJob = true;
      _historyMode = args is Map && args['fromPostHistory'] == true;
      _controller.fetchEmployerInfo(job.employerId);
      if (_historyMode) {
        _loadHiredUsers();
      } else {
        _controller.checkApplicationStatus(job.jobId);
      }
    }
  }

  JobPostModel? _jobFromArguments(dynamic args) {
    if (args is JobPostModel) return args;
    if (args is Map && args['job'] is JobPostModel) {
      return args['job'] as JobPostModel;
    }
    return null;
  }

  Future<void> _loadHiredUsers() async {
    setState(() {
      _isLoadingHiredUsers = true;
      _hiredUsersError = null;
    });

    try {
      final entries = await _candidatesService.fetchAcceptedByJob(job);
      if (!mounted) return;
      setState(() {
        _hiredEntries = entries;
        _isLoadingHiredUsers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hiredUsersError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingHiredUsers = false;
      });
    }
  }

  @override
  void dispose() {
    Get.delete<JobDetailController>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasJob) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('Lỗi: Không tìm thấy thông tin công việc.')),
      );
    }

    final Color primaryColor = const Color(0xFF2E7D32);

    final title = job.title;
    final salary = job.salaryDisplay;
    final location = job.locationDisplay;
    final type = job.jobType == 'part_time' ? 'Part-time' : 'Full-time';
    final description = job.description;
    final requirements = job.requirements;

    // Format dates
    final dateFormat = DateFormat('dd/MM/yyyy');
    final startDateStr = dateFormat.format(job.startDate);
    final endDateStr = job.endDate != null
        ? dateFormat.format(job.endDate!)
        : 'Không giới hạn';
    final startTimeStr = job.startTime ?? 'Không rõ';
    final workHoursStr = job.workHoursPerDay != null
        ? '${job.workHoursPerDay} tiếng'
        : 'Không rõ';

    final slotsStr = '${job.filledSlots} / ${job.slots} người';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.black87),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_border, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(bottom: _historyMode ? 24 : 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Ảnh Cover
                SizedBox(
                  width: double.infinity,
                  height: 250,
                  child: Image.asset(
                    'assets/images/banners/default_image.png',
                    fit: BoxFit.cover,
                  ),
                ),
                // 2. Header thông tin cơ bản
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.monetization_on,
                            color: primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            salary,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: location.isEmpty
                              ? null
                              : () => _openDirectionsMap(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  color: location.isEmpty
                                      ? Colors.grey.shade600
                                      : primaryColor,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    location.isEmpty
                                        ? 'Chưa có địa điểm'
                                        : location,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: location.isEmpty
                                          ? Colors.grey.shade700
                                          : primaryColor,
                                      decoration: location.isEmpty
                                          ? null
                                          : TextDecoration.underline,
                                      decorationColor: primaryColor,
                                    ),
                                  ),
                                ),
                                if (location.isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.map_outlined,
                                    size: 18,
                                    color: primaryColor,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.work_outline,
                            color: Colors.grey.shade600,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            type,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(color: Colors.grey.shade200, thickness: 8),

                if (job.isFullTimeReferral) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              kFullTimeCandidateNotice,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.45,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 3. Thông tin thời gian và số lượng
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chi tiết tuyển dụng',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.calendar_today,
                        'Ngày làm:',
                        '$startDateStr - $endDateStr',
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        Icons.access_time,
                        'Thời gian:',
                        '$startTimeStr ($workHoursStr/ngày)',
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        Icons.people_outline,
                        'Số lượng tuyển:',
                        slotsStr,
                      ),
                      if (job.jobType == 'full_time' &&
                          job.fullTimeDetails != null) ...[
                        const SizedBox(height: 8),
                        ..._buildFullTimeDetailRows(job.fullTimeDetails!),
                      ],
                    ],
                  ),
                ),
                Divider(color: Colors.grey.shade200, thickness: 8),

                // 4. Mô tả công việc
                if (description.isNotEmpty) ...[
                  _buildSection(title: 'Mô tả công việc', content: description),
                  Divider(color: Colors.grey.shade200, thickness: 8),
                ],

                // 5. Yêu cầu công việc
                if (requirements != null && requirements.isNotEmpty) ...[
                  _buildSection(
                    title: 'Yêu cầu ứng viên',
                    content: requirements,
                  ),
                  Divider(color: Colors.grey.shade200, thickness: 8),
                ],

                // 6. Thông tin nhà tuyển dụng
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Thông tin nhà tuyển dụng',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Obx(() {
                        if (_controller.isLoadingEmployer.value) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final employer = _controller.employer.value;
                        if (employer == null) {
                          return const Text(
                            'Không tải được thông tin nhà tuyển dụng.',
                          );
                        }

                        final compName =
                            employer.companyName ?? employer.fullName;
                        final compSize = employer.companySize ?? 'Không rõ';
                        final compLogo =
                            employer.companyLogoUrl ?? employer.avatarUrl;

                        return Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              clipBehavior: Clip.hardEdge,
                              child: compLogo != null
                                  ? Image.network(
                                      compLogo,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.business,
                                                color: Colors.grey,
                                              ),
                                    )
                                  : const Icon(
                                      Icons.business,
                                      color: Colors.grey,
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    compName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Quy mô: $compSize nhân viên',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                if (_historyMode) ...[
                  Divider(color: Colors.grey.shade200, thickness: 8),
                  _buildHiredUsersSection(),
                ],
              ],
            ),
          ),
          // 7. Nút ứng tuyển cố định phía dưới
          if (!_historyMode)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      offset: const Offset(0, -4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Obx(() {
                    final status = _controller.applicationStatus.value;
                    final isPending = status == 'pending';
                    final isAccepted = status == 'accepted';
                    final isWithdrawn = [
                      'withdrawn',
                      'cancelled',
                      'rejected',
                    ].contains(status);
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final startDay = DateTime(
                      job.startDate.year,
                      job.startDate.month,
                      job.startDate.day,
                    );
                    final jobStarted =
                        (isPending || isAccepted) && !today.isBefore(startDay);

                    Color btnColor;
                    if (!_controller.canApply.value ||
                        isWithdrawn ||
                        jobStarted) {
                      btnColor = Colors.grey.shade500;
                    } else if (isAccepted) {
                      btnColor = Colors.red;
                    } else if (isPending) {
                      btnColor = Colors.amber.shade700;
                    } else {
                      btnColor = const Color(0xFF2E7D32); // Green
                    }

                    String btnText;
                    if (jobStarted) {
                      btnText = 'Công việc đã bắt đầu';
                    } else if (isAccepted) {
                      btnText = 'Hủy tham gia';
                    } else if (isPending) {
                      btnText = 'Hủy ứng tuyển';
                    } else if (isWithdrawn) {
                      btnText = 'Không thể ứng tuyển';
                    } else {
                      btnText = 'Ứng tuyển ngay';
                    }

                    return Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _controller.canApply.value
                                  ? primaryColor
                                  : Colors.grey.shade500,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.chat_bubble_outline,
                              color: _controller.canApply.value
                                  ? primaryColor
                                  : Colors.grey.shade500,
                            ),
                            onPressed: _controller.canApply.value
                                ? () => _openMessages(context)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed:
                                  (!_controller.canApply.value ||
                                      isWithdrawn ||
                                      jobStarted)
                                  ? null
                                  : () {
                                      if (isAccepted || isPending) {
                                        if (_dialogShowing) return;
                                        _dialogShowing = true;
                                        Get.defaultDialog(
                                          title: 'Xác nhận hủy ứng tuyển',
                                          middleText: isAccepted
                                              ? 'Bạn đã được nhận vào công việc này. Bạn có chắc chắn muốn hủy không?'
                                              : 'Bạn có chắc chắn muốn hủy đơn ứng tuyển đang chờ duyệt không?',
                                          textConfirm: 'Có',
                                          textCancel: 'Không',
                                          confirmTextColor: Colors.white,
                                          onConfirm: () {
                                            _dialogShowing = false;
                                            Get.back();
                                            _controller.cancelApplication(job);
                                          },
                                          onCancel: () {
                                            _dialogShowing = false;
                                          },
                                        );
                                        return;
                                      }
                                      _controller.applyJob(job);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: btnColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _controller.isApplying.value
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      btnText,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          if (!_historyMode && !_controller.canApply.value)
            Positioned(
              bottom: 78,
              left: 16,
              right: 16,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    'Chỉ tài khoản Ứng viên mới có thể ứng tuyển.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHiredUsersSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.groups_outlined,
                size: 20,
                color: Color(0xFF1565C0),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'User đã thuê',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_hiredEntries.length}',
                  style: const TextStyle(
                    color: Color(0xFF1565C0),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingHiredUsers)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF1565C0)),
              ),
            )
          else if (_hiredUsersError != null)
            _buildHiredUsersNotice(
              Icons.error_outline,
              'Không tải được danh sách user: $_hiredUsersError',
            )
          else if (_hiredEntries.isEmpty)
            _buildHiredUsersNotice(
              Icons.people_outline,
              'Chưa có user đã thuê trong bài đăng này.',
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _hiredEntries.length; i++) ...[
                    _buildHiredUserTile(_hiredEntries[i]),
                    if (i != _hiredEntries.length - 1)
                      Divider(height: 1, color: Colors.grey.shade100),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHiredUsersNotice(IconData icon, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade500, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHiredUserTile(ApplicationEntry entry) {
    final app = entry.application;
    final candidate = entry.candidate;
    final appliedLabel = app.appliedAt != null
        ? 'Nộp ${DateFormat('dd/MM/yyyy').format(app.appliedAt!)}'
        : 'Vừa nộp';

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCandidateAvatar(candidate),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.fullName.isNotEmpty
                          ? candidate.fullName
                          : 'Ứng viên',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildStarRating(candidate.averageRating),
                            const SizedBox(width: 5),
                            Text(
                              candidate.averageRating > 0
                                  ? candidate.averageRating.toStringAsFixed(1)
                                  : 'Chưa có',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.work_outline,
                              size: 13,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${candidate.totalJobsDone} việc',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 13,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              appliedLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildAcceptedBadge(),
            ],
          ),
          if (app.coverLetter?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                app.coverLetter!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          ],
          if (app.cvUrl?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () => _openExternalUrl(app.cvUrl!),
              icon: Icon(
                Icons.picture_as_pdf,
                size: 15,
                color: Colors.red.shade500,
              ),
              label: const Text('Xem CV'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1565C0),
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCandidateAvatar(CandidateSnapshot candidate) {
    return CircleAvatar(
      radius: 23,
      backgroundColor: const Color(0xFF1565C0).withValues(alpha: 0.12),
      backgroundImage: candidate.avatarUrl?.isNotEmpty == true
          ? NetworkImage(candidate.avatarUrl!)
          : null,
      child: candidate.avatarUrl?.isNotEmpty != true
          ? Text(
              candidate.fullName.isNotEmpty
                  ? candidate.fullName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Color(0xFF1565C0),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            )
          : null,
    );
  }

  Widget _buildStarRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final icon = i < rating.floor()
            ? Icons.star_rounded
            : (i < rating && rating - i >= 0.5
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded);
        return Icon(
          icon,
          size: 13,
          color: icon == Icons.star_outline_rounded
              ? Colors.grey.shade300
              : Colors.amber.shade500,
        );
      }),
    );
  }

  Widget _buildAcceptedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Đã duyệt',
        style: TextStyle(
          color: Colors.green.shade800,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openDirectionsMap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JobDirectionsMapScreen(job: job)),
    );
  }

  Future<void> _openMessages(BuildContext context) async {
    final auth = Get.find<AuthController>();
    if (auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để nhắn tin')),
      );
      return;
    }
    if (auth.currentUser?.role != 'candidate') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chỉ tài khoản Ứng viên mới nhắn tin từ màn này'),
        ),
      );
      return;
    }
    try {
      final groupId = await _messagingService.getOrCreateDirectChat(
        jobId: job.jobId,
        jobTitle: job.title,
        employerId: job.employerId,
        candidateId: auth.currentUser!.id,
      );
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(groupId: groupId, isEmployer: false),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể mở trò chuyện: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  List<Widget> _buildFullTimeDetailRows(FullTimeJobDetails ft) {
    final weekdays = ft.workingDays
        .map(FullTimeJobDetails.weekdayLabel)
        .join(', ');
    final rows = <Widget>[
      _buildDetailRow(Icons.date_range, 'Ngày làm/tuần:', weekdays),
      const SizedBox(height: 8),
      _buildDetailRow(
        Icons.schedule,
        'Ca làm:',
        FullTimeJobDetails.shiftLabel(ft.workShift),
      ),
      const SizedBox(height: 8),
      _buildDetailRow(
        Icons.payments_outlined,
        'Trả lương:',
        'Ngày ${ft.payDayOfMonth} hàng tháng (NTD tự thỏa thuận)',
      ),
      const SizedBox(height: 8),
      _buildDetailRow(
        Icons.school_outlined,
        'Học vấn:',
        FullTimeJobDetails.educationLabel(ft.minEducation),
      ),
      const SizedBox(height: 8),
      _buildDetailRow(
        Icons.timeline,
        'Kinh nghiệm:',
        FullTimeJobDetails.experienceLabel(ft.minExperience),
      ),
    ];
    if (ft.probationDays != null && ft.probationDays! > 0) {
      rows.addAll([
        const SizedBox(height: 8),
        _buildDetailRow(
          Icons.hourglass_bottom,
          'Thử việc:',
          '${ft.probationDays} ngày',
        ),
      ]);
    }
    if (ft.benefits?.isNotEmpty == true) {
      rows.addAll([
        const SizedBox(height: 8),
        _buildDetailRow(Icons.card_giftcard, 'Quyền lợi:', ft.benefits!),
      ]);
    }
    rows.addAll([
      const SizedBox(height: 8),
      _buildDetailRow(
        Icons.description_outlined,
        'Nộp CV:',
        ft.requiresCv ? 'Bắt buộc' : 'Không bắt buộc',
      ),
      const SizedBox(height: 8),
      _buildDetailRow(
        Icons.record_voice_over_outlined,
        'Phỏng vấn:',
        ft.interviewRequired ? 'Có' : 'Không',
      ),
    ]);
    return rows;
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: Text(
            title,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
