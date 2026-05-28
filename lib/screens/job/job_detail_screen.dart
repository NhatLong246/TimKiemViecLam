import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controller/job_detail_controller.dart';
import '../../controller/login_controller.dart';
import '../../data/models/job_post_model.dart';
import '../../data/services/messaging_service.dart';
import '../messaging/chat_room_screen.dart';

class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final JobDetailController _controller = Get.put(JobDetailController());
  final MessagingService _messagingService = MessagingService();
  late JobPostModel job;

  @override
  void initState() {
    super.initState();
    final dynamic args = Get.arguments;
    if (args is JobPostModel) {
      job = args;
      _controller.fetchEmployerInfo(job.employerId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Get.arguments is! JobPostModel) {
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
            padding: const EdgeInsets.only(
              bottom: 100,
            ), // padding cho button Ứng tuyển
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
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            color: Colors.grey.shade600,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
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
              ],
            ),
          ),
          // 7. Nút ứng tuyển cố định phía dưới
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Obx(
                  () => Row(
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
                            onPressed: _controller.isApplying.value ||
                                    !_controller.canApply.value
                                ? null
                                : () => _controller.applyJob(job),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _controller.canApply.value
                                  ? primaryColor
                                  : Colors.grey.shade500,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _controller.isApplying.value
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _controller.canApply.value
                                        ? 'Ứng tuyển ngay'
                                        : 'Không khả dụng',
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
                  ),
                ),
              ),
            ),
          ),
          if (!_controller.canApply.value)
            Positioned(
              bottom: 78,
              left: 16,
              right: 16,
              child: IgnorePointer(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        const SnackBar(content: Text('Chỉ tài khoản Ứng viên mới nhắn tin từ màn này')),
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
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            groupId: groupId,
            isEmployer: false,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể mở trò chuyện: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
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
