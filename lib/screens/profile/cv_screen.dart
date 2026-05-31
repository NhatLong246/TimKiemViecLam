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

/// Hub CV cá nhân — tạo/sửa hồ sơ, upload file, xem trước.
class CvScreen extends StatelessWidget {
  const CvScreen({super.key});

  static const _primary = Color(0xFF2E7D32);
  static const _iconBg = Color(0xFFE8F5E9);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CvController());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF666666)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'CV cá nhân',
          style: TextStyle(
            color: Color(0xFF222222),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Chỉnh sửa đầy đủ',
            icon: const Icon(Icons.edit_note, color: _primary),
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
            return const Center(child: CircularProgressIndicator(color: _primary));
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

          return RefreshIndicator(
            color: _primary,
            onRefresh: () async {
              await snap.data?.reference.get();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _buildHeaderCard(fullName, data, completion),
                const SizedBox(height: 16),
                _buildCvFileCard(context, controller, cvUrl, cvFileName),
                const SizedBox(height: 16),
                _buildSectionTitle('Hoàn thiện hồ sơ'),
                const SizedBox(height: 8),
                _buildSectionTile(
                  context,
                  icon: Icons.person_outline,
                  title: 'Thông tin & giới thiệu',
                  subtitle: completion.hasSelfIntro
                      ? 'Đã có giới thiệu bản thân'
                      : 'Viết vài dòng về bạn',
                  done: completion.hasSelfIntro,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SelfIntroductionScreen(),
                    ),
                  ),
                ),
                _buildSectionTile(
                  context,
                  icon: Icons.work_outline,
                  title: 'Kinh nghiệm làm việc',
                  subtitle: completion.hasExperience
                      ? 'Đã khai báo'
                      : 'Thêm công ty, vị trí',
                  done: completion.hasExperience,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WorkExperienceScreen(),
                    ),
                  ),
                ),
                _buildSectionTile(
                  context,
                  icon: Icons.school_outlined,
                  title: 'Học vấn',
                  subtitle: completion.hasEducation
                      ? 'Đã có bằng cấp / trường'
                      : 'Thêm trường, chuyên ngành',
                  done: completion.hasEducation,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EducationScreen()),
                  ),
                ),
                _buildSectionTile(
                  context,
                  icon: Icons.star_outline,
                  title: 'Kỹ năng',
                  subtitle: completion.hasSkills
                      ? 'Đã thêm kỹ năng'
                      : 'VD: giao tiếp, pha chế…',
                  done: completion.hasSkills,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SkillsScreen()),
                  ),
                ),
                _buildSectionTile(
                  context,
                  icon: Icons.folder_outlined,
                  title: 'Dự án',
                  subtitle: hasProjects ? 'Đã thêm dự án' : 'Thêm dự án đã làm',
                  done: hasProjects,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProjectScreen()),
                  ),
                ),
                _buildSectionTile(
                  context,
                  icon: Icons.card_membership_outlined,
                  title: 'Chứng chỉ / bằng cấp',
                  subtitle: hasCertificates
                      ? 'Đã thêm chứng chỉ'
                      : 'Chỉ hiện khi bạn thêm ở đây',
                  done: hasCertificates,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CertificateScreen(),
                    ),
                  ),
                ),
                _buildSectionTile(
                  context,
                  icon: Icons.translate,
                  title: 'Ngoại ngữ',
                  subtitle: hasLanguages
                      ? 'Đã thêm ngoại ngữ'
                      : 'VD: Tiếng Anh · B2',
                  done: hasLanguages,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ForeignLanguageScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildSectionTile(
                  context,
                  icon: Icons.folder_shared_outlined,
                  title: 'Hồ sơ chi tiết',
                  subtitle: 'Xem & sửa toàn bộ hồ sơ',
                  done: false,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyProfileScreen()),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CvPreviewScreen(userData: data),
                      ),
                    ),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Xem trước CV'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(
    String fullName,
    Map<String, dynamic> data,
    CvCompletionModel completion,
  ) {
    final email = (data['email'] ?? '').toString();
    final phone = (data['phone'] ?? '').toString();
    final avatar = data['avatarUrl'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: _iconBg,
            backgroundImage:
                avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar == null || avatar.isEmpty
                ? const Icon(Icons.person, size: 36, color: _primary)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.isEmpty ? 'Ứng viên' : fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(phone, style: TextStyle(color: Colors.grey.shade600)),
                ],
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Column(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: completion.percent / 100,
                      strokeWidth: 5,
                      color: _primary,
                      backgroundColor: Colors.grey.shade200,
                    ),
                    Text(
                      '${completion.percent}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text('Hoàn thiện', style: TextStyle(fontSize: 10)),
            ],
          ),
        ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.description_outlined, color: _primary),
              SizedBox(width: 8),
              Text(
                'File CV (PDF/DOC)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasFile
                ? 'Dùng khi ứng tuyển việc full-time'
                : 'Tải CV có sẵn hoặc hoàn thiện các mục bên dưới',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          if (hasFile) ...[
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.picture_as_pdf, color: _primary),
              ),
              title: Text(
                cvFileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.open_in_new, color: _primary),
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
          ],
          const SizedBox(height: 12),
          Obx(() {
            final uploading = controller.isUploading.value;
            final removing = controller.isRemoving.value;
            return Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: uploading || removing
                        ? null
                        : controller.pickAndUploadCv,
                    icon: uploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.upload_file),
                    label: Text(hasFile ? 'Đổi file CV' : 'Tải CV lên'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                if (hasFile) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: removing ? null : controller.removeCv,
                    icon: removing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );
  }

  Widget _buildSectionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool done,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        trailing: Icon(
          done ? Icons.check_circle : Icons.chevron_right,
          color: done ? _primary : Colors.grey,
        ),
      ),
    );
  }
}
