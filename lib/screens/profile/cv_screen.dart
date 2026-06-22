import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:viecnow/controller/cv_controller.dart';
import 'package:viecnow/data/models/candidate_profile_models.dart';
import 'package:viecnow/data/models/cv_completion_model.dart';
import 'package:viecnow/screens/profile/cv_preview_screen.dart';
import 'package:viecnow/screens/profile/my_profile_screen.dart';
import 'package:viecnow/screens/profile/self_introduction_screen.dart';
import 'package:viecnow/screens/profile/skills_screen.dart';
import 'package:viecnow/screens/profile/work_experience_screen.dart';
import 'package:viecnow/screens/profile/education_screen.dart';
import 'package:viecnow/screens/profile/project_screen.dart';
import 'package:viecnow/screens/profile/certificate_screen.dart';
import 'package:viecnow/screens/profile/foreign_language_screen.dart';

/// Hub CV cá nhân — tạo/sửa hồ sơ, upload file, xem trước (Premium UI).
class CvScreen extends StatelessWidget {
  const CvScreen({super.key});

  static const _primary = Color(0xFF2E7D32);
  static const _primaryLight = Color(0xFFE8F5E9);
  static const _background = Color(0xFFF3F4F6); // Nền xám nhạt hiện đại

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CvController());

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1F2937)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Hồ sơ & CV',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Chỉnh sửa toàn bộ',
            icon: const Icon(Icons.settings_outlined, color: _primary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyProfileScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: controller.userStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: _primary));
          }
          if (snap.hasError) {
            return Center(child: Text('Lỗi: ${snap.error}'));
          }

          final data = snap.hasData && snap.data!.exists
              ? snap.data!.data() as Map<String, dynamic>
              : <String, dynamic>{};
          final completion = CvCompletionModel.fromUserData(data);
          final hasProjects = ProjectModel.listFromUserData(data).isNotEmpty;
          final hasCertificates =
              CertificateModel.listFromUserData(data).isNotEmpty;
          final hasLanguages = LanguageModel.listFromUserData(data).isNotEmpty;
          final fullName =
              '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
          final cvUrl = (data['cvUrl'] ?? '').toString();
          final cvFileName = (data['cvFileName'] ?? 'CV.pdf').toString();

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  color: _primary,
                  onRefresh: () async {
                    await snap.data?.reference.get();
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _buildHeaderDashboard(fullName, data, completion),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Quản lý CV Đính kèm',
                          icon: Icons.upload_file),
                      const SizedBox(height: 12),
                      _buildCvFileCard(context, controller, cvUrl, cvFileName),
                      const SizedBox(height: 28),
                      _buildSectionTitle('Hoàn thiện hồ sơ trực tuyến',
                          icon: Icons.edit_document),
                      const SizedBox(height: 4),
                      Text(
                        'Các thông tin dưới đây sẽ được dùng để tạo CV tự động.',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 16),
                      // Các mục hồ sơ
                      _buildProfileItem(
                        context,
                        icon: Icons.person_pin_outlined,
                        title: 'Thông tin cá nhân & Giới thiệu',
                        subtitle: completion.hasSelfIntro
                            ? 'Đã cập nhật mục tiêu nghề nghiệp'
                            : 'Nên bổ sung để gây ấn tượng',
                        isDone: completion.hasSelfIntro,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SelfIntroductionScreen()),
                        ),
                      ),
                      _buildProfileItem(
                        context,
                        icon: Icons.work_history_outlined,
                        title: 'Kinh nghiệm làm việc',
                        subtitle: completion.hasExperience
                            ? 'Đã khai báo lịch sử làm việc'
                            : 'Trình bày các công ty bạn đã làm',
                        isDone: completion.hasExperience,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const WorkExperienceScreen()),
                        ),
                      ),
                      _buildProfileItem(
                        context,
                        icon: Icons.school_outlined,
                        title: 'Học vấn',
                        subtitle: completion.hasEducation
                            ? 'Đã cập nhật trường/chuyên ngành'
                            : 'Thêm bằng cấp hoặc nơi học tập',
                        isDone: completion.hasEducation,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EducationScreen()),
                        ),
                      ),
                      _buildProfileItem(
                        context,
                        icon: Icons.auto_awesome_mosaic_outlined,
                        title: 'Kỹ năng chuyên môn',
                        subtitle: completion.hasSkills
                            ? 'Đã thêm các kỹ năng nổi bật'
                            : 'Thêm kỹ năng để CV thu hút hơn',
                        isDone: completion.hasSkills,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SkillsScreen()),
                        ),
                      ),
                      _buildProfileItem(
                        context,
                        icon: Icons.folder_special_outlined,
                        title: 'Dự án nổi bật',
                        subtitle: hasProjects
                            ? 'Đã cập nhật dự án'
                            : 'Các dự án thực tế đã tham gia',
                        isDone: hasProjects,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProjectScreen()),
                        ),
                      ),
                      _buildProfileItem(
                        context,
                        icon: Icons.verified_outlined,
                        title: 'Chứng chỉ & Giải thưởng',
                        subtitle: hasCertificates
                            ? 'Đã thêm chứng chỉ'
                            : 'Các chứng chỉ bạn đạt được',
                        isDone: hasCertificates,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CertificateScreen()),
                        ),
                      ),
                      _buildProfileItem(
                        context,
                        icon: Icons.language,
                        title: 'Ngoại ngữ',
                        subtitle: hasLanguages
                            ? 'Đã thêm ngôn ngữ'
                            : 'Ví dụ: Tiếng Anh (IELTS 6.5)',
                        isDone: hasLanguages,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ForeignLanguageScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Sticky Bottom Bar cho nút "Xem trước CV"
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CvPreviewScreen(userData: data),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.remove_red_eye_rounded, size: 22),
                          SizedBox(width: 10),
                          Text(
                            'XEM TRƯỚC CV VIP',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Widget Header dạng Dashboard VIP
  Widget _buildHeaderDashboard(
    String fullName,
    Map<String, dynamic> data,
    CvCompletionModel completion,
  ) {
    final email = (data['email'] ?? '').toString();
    final phone = (data['phone'] ?? '').toString();
    final avatar = data['avatarUrl'] as String?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F2937), Color(0xFF111827)], // Xanh đen sang trọng
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111827).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                ),
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white,
                  backgroundImage: avatar != null && avatar.isNotEmpty
                      ? NetworkImage(avatar)
                      : null,
                  child: avatar == null || avatar.isEmpty
                      ? const Icon(Icons.person,
                          size: 38, color: Color(0xFF9CA3AF))
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isEmpty ? 'Ứng viên' : fullName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (phone.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.phone_android,
                              size: 14, color: Colors.white.withValues(alpha: 0.7)),
                          const SizedBox(width: 6),
                          Text(phone,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
                        ],
                      ),
                    const SizedBox(height: 4),
                    if (email.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.email_outlined,
                              size: 14, color: Colors.white.withValues(alpha: 0.7)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              email,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Progress Bar (thanh ngang VIP hơn vòng tròn tròn)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Độ hoàn thiện hồ sơ',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${completion.percent}%',
                      style: const TextStyle(
                        color: Color(0xFF10B981), // Xanh ngọc bích nổi bật
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: completion.percent / 100,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF10B981)),
                  ),
                ),
                if (completion.percent < 100) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Cập nhật thêm thông tin để thu hút NTD hơn.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text, {required IconData icon}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF374151)),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDone,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon Background
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDone ? _primaryLight : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isDone ? _primary : const Color(0xFF6B7280),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDone ? _primary : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                // Status Icon
                Icon(
                  isDone ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                  color: isDone ? _primary : const Color(0xFF9CA3AF),
                  size: isDone ? 24 : 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCvFileCard(
    BuildContext context,
    CvController controller,
    String cvUrl,
    String cvFileName,
  ) {
    final hasFile = cvUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasFile
                ? 'Sử dụng CV đính kèm để ứng tuyển nhanh các công việc yêu cầu file PDF.'
                : 'Bạn chưa tải CV lên. Có thể tải PDF hoặc dùng CV tự động.',
            style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700, height: 1.5),
          ),
          if (hasFile) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2), // Đỏ nhạt cho icon PDF
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEF4444)),
                ),
                title: Text(
                  cvFileName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.open_in_new_rounded, color: _primary),
                  onPressed: () async {
                    final uri = Uri.parse(cvUrl);
                    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Không mở được file')),
                        );
                      }
                    }
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Obx(() {
            final uploading = controller.isUploading.value;
            final removing = controller.isRemoving.value;
            return Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: uploading || removing
                        ? null
                        : controller.pickAndUploadCv,
                    icon: uploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _primary,
                            ),
                          )
                        : const Icon(Icons.upload_file_rounded),
                    label: Text(hasFile ? 'Đổi CV khác' : 'Tải CV lên ngay'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primary,
                      side: const BorderSide(color: _primary, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
                if (hasFile) ...[
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: removing ? null : controller.removeCv,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: removing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                            )
                          : const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                    ),
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}
