import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controller/login_controller.dart';
import '../../data/services/applications_service.dart';
import '../messaging/conversation_list_screen.dart';

class JobDetailScreen extends StatelessWidget {
  const JobDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Nhận dữ liệu truyền sang từ màn trước
    final Map<String, dynamic> job = Get.arguments ?? {
      'title': 'Chi tiết công việc',
      'salary': 'Thỏa thuận',
      'location': 'Không rõ',
      'type': 'Full-time',
      'image': 'assets/images/banners/default_image.png',
    };

    final Color primaryColor = const Color(0xFF2E7D32);

    return Scaffold(
      backgroundColor: Colors.white,
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
            padding: const EdgeInsets.only(bottom: 100), // padding cho button Ứng tuyển
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Ảnh Cover
                SizedBox(
                  width: double.infinity,
                  height: 250,
                  child: Image.asset(
                    job['image'] ?? 'assets/images/banners/default_image.png',
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
                        job['title'] ?? '',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.monetization_on, color: primaryColor, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            job['salary'] ?? '',
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
                          Icon(Icons.location_on_outlined, color: Colors.grey.shade600, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              job['location'] ?? '',
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.work_outline, color: Colors.grey.shade600, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            job['type'] ?? '',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(color: Colors.grey.shade200, thickness: 8),
                // 3. Mô tả công việc
                _buildSection(
                  title: 'Mô tả công việc',
                  content: '- Thực hiện các công việc theo sự phân công của quản lý.\n- Đảm bảo chất lượng dịch vụ và làm hài lòng khách hàng.\n- Giữ gìn vệ sinh khu vực làm việc luôn sạch sẽ.\n- Hỗ trợ đồng nghiệp khi cần thiết.',
                ),
                Divider(color: Colors.grey.shade200, thickness: 8),
                // 4. Yêu cầu công việc
                _buildSection(
                  title: 'Yêu cầu ứng viên',
                  content: '- Nam/Nữ từ 18-25 tuổi.\n- Nhanh nhẹn, trung thực, có trách nhiệm trong công việc.\n- Có thể làm việc theo ca xoay linh hoạt.\n- Không yêu cầu kinh nghiệm, sẽ được đào tạo bài bản.',
                ),
                Divider(color: Colors.grey.shade200, thickness: 8),
                // 5. Quyền lợi
                _buildSection(
                  title: 'Quyền lợi được hưởng',
                  content: '- Lương cơ bản + thưởng chuyên cần + tip.\n- Hỗ trợ bữa ăn theo ca làm việc.\n- Môi trường làm việc năng động, thân thiện.\n- Cơ hội thăng tiến lên các vị trí cao hơn.',
                ),
                Divider(color: Colors.grey.shade200, thickness: 8),
                // 6. Thông tin nhà tuyển dụng
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Thông tin nhà tuyển dụng',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: const Icon(Icons.business, color: Colors.grey),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Công ty TNHH Dịch Vụ Ẩm Thực',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Quy mô: 50-100 nhân viên',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
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
                  )
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        border: Border.all(color: primaryColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.chat_bubble_outline, color: primaryColor),
                        onPressed: () => _openMessages(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => _apply(context, job),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Ứng tuyển ngay',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _openMessages(BuildContext context) {
    final auth = Get.find<AuthController>();
    if (auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để nhắn tin')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConversationListScreen()),
    );
  }

  static Future<void> _apply(
    BuildContext context,
    Map<String, dynamic> job,
  ) async {
    final auth = Get.find<AuthController>();
    if (auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để ứng tuyển')),
      );
      return;
    }

    final jobId = job['jobId']?.toString() ?? job['id']?.toString();
    final employerId = job['employerId']?.toString();
    if (jobId == null || jobId.isEmpty || employerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thiếu mã tin tuyển dụng. Mở tin từ danh sách việc làm.'),
        ),
      );
      return;
    }

    try {
      await ApplicationsService().applyToJob(
        jobId: jobId,
        employerId: employerId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi đơn ứng tuyển')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
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
            style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
