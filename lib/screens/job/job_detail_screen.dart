import 'dart:convert';

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
import '../../utils/job_time_helper.dart';
import '../messaging/chat_room_screen.dart';
import '../candidate/candidate_employer_reviews_screen.dart';

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
  bool _readOnlyNoBottom = false;
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
      _readOnlyNoBottom = args is Map && args['readOnlyNoBottom'] == true;
      _controller.fetchEmployerInfo(job.employerId);
      if (_historyMode) {
        _loadHiredUsers();
      } else if (!_readOnlyNoBottom) {
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
  @override
  Widget build(BuildContext context) {
    if (!_hasJob) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('Lỗi: Không tìm thấy thông tin công việc.')),
      );
    }

    final Color primaryColor = const Color(0xFF2E7D32);
    final Color secondaryColor = const Color(0xFF1B5E20);

    final title = job.title;
    final salary = job.salaryDisplay;
    final location = job.fullLocationDisplay;
    final type = job.jobType == 'part_time' ? 'Part-time' : 'Full-time';
    final description = job.description;
    final requirements = job.requirements;
    final hideBottomActions = _historyMode || _readOnlyNoBottom;
    final isFullTimeReferral = job.isFullTimeReferral;

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
    final dateLabel = isFullTimeReferral ? 'Ngày hẹn PV' : 'Ngày làm';
    final dateValue = isFullTimeReferral
        ? startDateStr
        : '$startDateStr - $endDateStr';
    final timeLabel = isFullTimeReferral ? 'Giờ hẹn' : 'Thời gian';
    final timeValue = isFullTimeReferral
        ? startTimeStr
        : '$startTimeStr ($workHoursStr/ngày)';

    final slotsStr = '${job.filledSlots} / ${job.slots} người';

    // Xử lý Hạn ứng tuyển
    String deadlineStr = 'Không xác định';
    int? daysLeft;
    bool isExpired = false;
    if (job.applicationDeadline != null) {
      deadlineStr = dateFormat.format(job.applicationDeadline!);
      final now = DateTime.now();
      final difference = job.applicationDeadline!.difference(now);
      daysLeft = difference.inDays;
      if (difference.isNegative) {
        isExpired = true;
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.black87,
                size: 20,
              ),
              onPressed: () => Get.back(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(bottom: hideBottomActions ? 24 : 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. VIP Cover Header
                SizedBox(
                  width: double.infinity,
                  height: 320,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background Image
                      Builder(
                        builder: (context) {
                          if (job.imageUrls.isEmpty) {
                            return Image.asset(
                              'assets/images/banners/default_image.png',
                              fit: BoxFit.cover,
                            );
                          }
                          final img = job.imageUrls.first;
                          if (img.startsWith('http')) {
                            return Image.network(
                              img,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => Image.asset(
                                'assets/images/banners/default_image.png',
                                fit: BoxFit.cover,
                              ),
                            );
                          }
                          try {
                            var b64 = img;
                            if (b64.contains(',')) {
                              b64 = b64.split(',').last;
                            }
                            final sanitized = b64.replaceAll(
                              RegExp(r'\s+'),
                              '',
                            );
                            final padded = sanitized.padRight(
                              sanitized.length + (4 - sanitized.length % 4) % 4,
                              '=',
                            );
                            return Image.memory(
                              base64Decode(padded),
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => Image.asset(
                                'assets/images/banners/default_image.png',
                                fit: BoxFit.cover,
                              ),
                            );
                          } catch (_) {
                            return Image.asset(
                              'assets/images/banners/default_image.png',
                              fit: BoxFit.cover,
                            );
                          }
                        },
                      ),
                      // Gradient Overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.1),
                              Colors.black.withValues(alpha: 0.5),
                              Colors.black.withValues(alpha: 0.9),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                      // Title & Salary Overlay
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                type,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [primaryColor, secondaryColor],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.monetization_on,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        salary,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Deadline VIP Banner
                if (job.applicationDeadline != null)
                  Transform.translate(
                    offset: const Offset(0, -15),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isExpired
                            ? Colors.red.shade50
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isExpired
                              ? Colors.red.shade200
                              : Colors.blue.shade200,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isExpired ? Icons.timer_off : Icons.timer,
                            color: isExpired
                                ? Colors.red.shade600
                                : Colors.blue.shade700,
                            size: 26,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hạn ứng tuyển: $deadlineStr',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isExpired
                                        ? Colors.red.shade800
                                        : Colors.blue.shade900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isExpired
                                      ? 'Đã hết hạn ứng tuyển'
                                      : (daysLeft != null && daysLeft == 0
                                            ? 'Hết hạn trong hôm nay'
                                            : 'Còn $daysLeft ngày để ứng tuyển'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isExpired
                                        ? Colors.red.shade700
                                        : Colors.blue.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Location info
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: location.isEmpty
                          ? null
                          : () => _openDirectionsMap(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.location_on,
                              color: primaryColor,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Địa điểm làm việc',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    location.isEmpty
                                        ? 'Chưa có địa điểm'
                                        : location,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (location.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.map_outlined,
                                size: 20,
                                color: primaryColor,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                if (job.isFullTimeReferral) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 20,
                            color: Colors.amber.shade800,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              kFullTimeCandidateNotice,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Chi tiết tuyển dụng (Grid View)
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
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 2.2,
                        children: [
                          _buildGridCard(
                            Icons.calendar_today,
                            dateLabel,
                            dateValue,
                            Colors.blue,
                          ),
                          _buildGridCard(
                            Icons.access_time,
                            timeLabel,
                            timeValue,
                            Colors.orange,
                          ),
                          _buildGridCard(
                            Icons.people_alt_outlined,
                            'Số lượng tuyển',
                            slotsStr,
                            Colors.purple,
                          ),
                          if (job.applicationDeadline != null)
                            _buildGridCard(
                              Icons.event_busy,
                              'Hạn nộp',
                              deadlineStr,
                              Colors.red,
                            ),
                        ],
                      ),
                      if (job.jobType == 'full_time' &&
                          job.fullTimeDetails != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: _buildFullTimeDetailRows(
                              job.fullTimeDetails!,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                Container(height: 6, color: Colors.grey.shade200),

                // 4. Mô tả công việc
                if (description.isNotEmpty) ...[
                  _buildSection(
                    title: 'Mô tả công việc',
                    content: description,
                    icon: Icons.description_outlined,
                  ),
                  Container(height: 6, color: Colors.grey.shade200),
                ],

                // 5. Yêu cầu công việc
                if (job.candidateRequirements.isNotEmpty ||
                    (requirements != null && requirements.isNotEmpty)) ...[
                  _buildCandidateRequirementsSection(
                    job.candidateRequirements,
                    legacyRequirements: requirements,
                  ),
                  Container(height: 6, color: Colors.grey.shade200),
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

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
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
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                compName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 17,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                            if (employer.isVerified)
                                              const Icon(
                                                Icons.verified,
                                                color: Colors.blue,
                                                size: 18,
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          employer.businessType == 'company'
                                              ? 'Doanh nghiệp'
                                              : employer.businessType ==
                                                    'cooperative'
                                              ? 'Hợp tác xã'
                                              : 'Cá nhân',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Divider(color: Colors.grey.shade100, height: 1),
                              const SizedBox(height: 16),
                              if (employer.companyAddress != null &&
                                  employer.companyAddress!.isNotEmpty) ...[
                                _buildCompanyDetailRow(
                                  Icons.location_on_outlined,
                                  employer.companyAddress!,
                                ),
                                const SizedBox(height: 10),
                              ],
                              if (employer.companyPhone != null &&
                                  employer.companyPhone!.isNotEmpty) ...[
                                _buildCompanyDetailRow(
                                  Icons.phone_outlined,
                                  employer.companyPhone!,
                                ),
                                const SizedBox(height: 10),
                              ],
                              if (employer.companyWebsite != null &&
                                  employer.companyWebsite!.isNotEmpty) ...[
                                _buildCompanyDetailRow(
                                  Icons.language_outlined,
                                  employer.companyWebsite!,
                                  isLink: true,
                                ),
                                const SizedBox(height: 10),
                              ],
                              _buildCompanyDetailRow(
                                Icons.people_outline,
                                'Quy mô: $compSize nhân viên',
                              ),
                              if (employer.companyDescription != null &&
                                  employer.companyDescription!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    employer.companyDescription!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                      height: 1.4,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Get.to(
                                      () => CandidateEmployerReviewsScreen(
                                        employerId: employer.id,
                                        employerName: compName,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.star, size: 18),
                                  label: const Text(
                                    'Xem đánh giá về nhà tuyển dụng',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: primaryColor,
                                    side: BorderSide(
                                      color: primaryColor.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                    backgroundColor: primaryColor.withValues(
                                      alpha: 0.05,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                if (_historyMode) ...[
                  Container(height: 6, color: Colors.grey.shade200),
                  _buildHiredUsersSection(),
                ],
              ],
            ),
          ),

          // 7. Nút ứng tuyển VIP
          if (!hideBottomActions)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      offset: const Offset(0, -5),
                      blurRadius: 15,
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
                    final jobStarted =
                        (isPending || isAccepted) &&
                        JobTimeHelper.hasStarted(job);
                    final isFullForOtherUsers =
                        job.isFull && !isPending && !isAccepted;

                    List<Color> btnGradient;
                    if (!_controller.canApply.value ||
                        isWithdrawn ||
                        jobStarted ||
                        isFullForOtherUsers ||
                        isExpired) {
                      btnGradient = [
                        Colors.grey.shade400,
                        Colors.grey.shade500,
                      ];
                    } else if (isAccepted) {
                      btnGradient = [Colors.red.shade400, Colors.red.shade600];
                    } else if (isPending) {
                      btnGradient = [
                        Colors.amber.shade500,
                        Colors.amber.shade700,
                      ];
                    } else {
                      btnGradient = [
                        const Color(0xFF4CAF50),
                        const Color(0xFF2E7D32),
                      ];
                    }

                    String btnText;
                    if (isExpired && !isPending && !isAccepted) {
                      btnText = 'Đã hết hạn ứng tuyển';
                    } else if (jobStarted) {
                      btnText = job.isFullTimeReferral
                          ? 'Đã qua giờ hẹn PV'
                          : 'Công việc đã bắt đầu';
                    } else if (isAccepted) {
                      btnText = job.isFullTimeReferral
                          ? 'Hủy lịch phỏng vấn'
                          : 'Hủy tham gia';
                    } else if (isPending) {
                      btnText = 'Hủy ứng tuyển';
                    } else if (isWithdrawn) {
                      btnText = job.isFullTimeReferral
                          ? 'Hồ sơ không còn hiệu lực'
                          : 'Không thể ứng tuyển';
                    } else if (isFullForOtherUsers) {
                      btnText = 'Đã đủ người';
                    } else {
                      btnText = job.isFullTimeReferral
                          ? 'Nộp CV Ứng Tuyển'
                          : 'Ứng Tuyển Ngay';
                    }

                    final bool disabled =
                        !_controller.canApply.value ||
                        isWithdrawn ||
                        jobStarted ||
                        isFullForOtherUsers ||
                        (isExpired && !isPending && !isAccepted);

                    return Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: _controller.canApply.value
                                  ? primaryColor
                                  : Colors.grey.shade300,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _controller.canApply.value
                                ? [
                                    BoxShadow(
                                      color: primaryColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.chat_bubble_outline,
                              color: _controller.canApply.value
                                  ? primaryColor
                                  : Colors.grey.shade400,
                            ),
                            onPressed: _controller.canApply.value
                                ? () => _openMessages(context)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(colors: btnGradient),
                              boxShadow: disabled
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: btnGradient.last.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                            ),
                            child: ElevatedButton(
                              onPressed: disabled
                                  ? null
                                  : () {
                                      if (isAccepted || isPending) {
                                        if (_dialogShowing) return;
                                        _dialogShowing = true;
                                        Get.defaultDialog(
                                          title:
                                              job.isFullTimeReferral &&
                                                  isAccepted
                                              ? 'Xác nhận hủy lịch'
                                              : 'Xác nhận hủy ứng tuyển',
                                          middleText:
                                              job.isFullTimeReferral &&
                                                  isAccepted
                                              ? 'CV của bạn đã được duyệt. Bạn có chắc chắn muốn hủy lịch phỏng vấn?'
                                              : (isAccepted
                                                    ? 'Bạn đã được nhận vào công việc này. Bạn có chắc muốn hủy?'
                                                    : 'Bạn có chắc chắn muốn hủy đơn ứng tuyển đang chờ duyệt không?'),
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
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
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
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
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
          if (!hideBottomActions && !_controller.canApply.value)
            Positioned(
              bottom: 96,
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

  Future<void> _openDirectionsMap(BuildContext context) async {
    // Thử mở bằng geo intent (mở app bản đồ native)
    final label = Uri.encodeComponent(job.mapsDestinationQuery);
    String geoUrl = 'geo:0,0?q=$label';

    if (job.hasMapCoordinates) {
      geoUrl = 'geo:${job.locationLat},${job.locationLng}?q=$label';
    }

    final geoUri = Uri.parse(geoUrl);

    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không tìm thấy ứng dụng bản đồ trên máy. Vui lòng cài đặt Google Maps!',
            ),
          ),
        );
      }
    }
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
        'Ngày ${ft.payDayOfMonth} hàng tháng',
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

  Widget _buildCandidateRequirementsSection(
    List<Map<String, dynamic>> requirements, {
    String? legacyRequirements,
  }) {
    final displayItems = requirements
        .map((requirement) {
          final value = _candidateRequirementValue(requirement);
          if (value.isEmpty) return null;
          final type = requirement['type']?.toString() ?? 'other';
          return <String, dynamic>{
            'type': type,
            'label': _candidateRequirementLabel(requirement),
            'value': value,
            'icon': _candidateRequirementIcon(type),
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    if (displayItems.isEmpty) {
      return _buildSection(
        title: 'Yêu cầu ứng viên',
        content: legacyRequirements ?? '',
        icon: Icons.checklist_rtl_outlined,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.fact_check_outlined,
                color: Color(0xFF2E7D32),
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'Yêu cầu ứng viên',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Các tiêu chí nhà tuyển dụng sẽ đối chiếu với hồ sơ của bạn.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: displayItems.asMap().entries.map((entry) {
                final item = entry.value;
                final isLast = entry.key == displayItems.length - 1;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF2E7D32,
                          ).withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          item['icon'] as IconData,
                          color: const Color(0xFF2E7D32),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['label'] as String,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item['value'] as String,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _candidateRequirementLabel(Map<String, dynamic> requirement) {
    final savedLabel = requirement['label']?.toString().trim() ?? '';
    if (savedLabel.isNotEmpty) return savedLabel;
    return switch (requirement['type']?.toString()) {
      'skills' => 'Kỹ năng',
      'certificates' => 'Chứng chỉ',
      'languages' => 'Ngoại ngữ',
      'gender' => 'Giới tính',
      'education' => 'Học vấn',
      'experience' => 'Kinh nghiệm',
      _ => 'Yêu cầu khác',
    };
  }

  String _candidateRequirementValue(Map<String, dynamic> requirement) {
    final type = requirement['type']?.toString();
    switch (type) {
      case 'skills':
      case 'certificates':
        return _requirementStringList(requirement['values']).join(', ');
      case 'languages':
        final language = requirement['language']?.toString().trim() ?? '';
        final levelType = requirement['levelType']?.toString().trim() ?? '';
        final minimum = requirement['minimum']?.toString().trim() ?? '';
        if (language.isEmpty) return '';
        if (minimum.isEmpty) return language;
        final level = levelType == 'TOEIC' || levelType == 'IELTS'
            ? '$levelType từ $minimum'
            : '$minimum trở lên';
        return '$language · $level';
      case 'gender':
        return switch (requirement['value']?.toString()) {
          'male' => 'Nam',
          'female' => 'Nữ',
          'other' => 'Khác',
          _ => 'Không yêu cầu',
        };
      case 'education':
        return FullTimeJobDetails.educationLabel(
          requirement['minimum']?.toString(),
        );
      case 'experience':
        return switch (requirement['minimum']?.toString()) {
          'no_exp' => 'Không yêu cầu, chấp nhận người mới',
          'under_1' => 'Dưới 1 năm',
          '1_to_3' => '1 - 3 năm',
          '3_to_5' => '3 - 5 năm',
          'over_5' => 'Trên 5 năm',
          _ => 'Không yêu cầu',
        };
      case 'other':
        return requirement['text']?.toString().trim() ?? '';
      default:
        return (requirement['text'] ?? requirement['value'] ?? '')
            .toString()
            .trim();
    }
  }

  List<String> _requirementStringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  IconData _candidateRequirementIcon(String type) => switch (type) {
    'skills' => Icons.psychology_outlined,
    'certificates' => Icons.workspace_premium_outlined,
    'languages' => Icons.translate_rounded,
    'gender' => Icons.wc_outlined,
    'education' => Icons.school_outlined,
    'experience' => Icons.work_history_outlined,
    _ => Icons.notes_rounded,
  };

  Widget _buildSection({
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF2E7D32), size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridCard(
    IconData icon,
    String title,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyDetailRow(
    IconData icon,
    String text, {
    bool isLink = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isLink ? Colors.blue.shade700 : Colors.grey.shade800,
            ),
          ),
        ),
      ],
    );
  }
}
