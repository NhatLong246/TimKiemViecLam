import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../utils/theme_colors.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:viecnow/controller/update_account_controller.dart';
import 'package:viecnow/data/models/candidate_profile_models.dart';
import 'package:viecnow/data/models/work_experience_model.dart';
import 'package:viecnow/data/models/cv_completion_model.dart';
import 'certificate_screen.dart';
import 'education_screen.dart';
import 'foreign_language_screen.dart';
import 'project_screen.dart';
import 'self_introduction_screen.dart';
import 'skills_screen.dart';
import 'work_experience_screen.dart';
import 'settings/settings_account_screen.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  static const Color _primary = Color(0xFF2E7D32);
  static const Color _iconBg = Color(0xFFE8F5E9);
  static const Color _border = Color(0xFFE2E2E2);

  late final Stream<DocumentSnapshot> _userDataStream;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _userDataStream = FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
    } else {
      _userDataStream = const Stream.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(UpdateAccountController());

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, color: context.textSecondary),
        ),
        title: Text(
          'Hồ sơ của tôi',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      body: SafeArea(
        child: StreamBuilder(
          stream: _userDataStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.hasData && snapshot.data!.exists
                ? snapshot.data!.data() as Map<String, dynamic>
                : <String, dynamic>{};
            final workExperiences = WorkExperienceModel.listFromUserData(data);
            final selfIntro = selfIntroductionFromUserData(data);
            final skills = skillsFromUserData(data);
            final educations = EducationModel.listFromUserData(data);
            final projects = ProjectModel.listFromUserData(data);
            final certificates = CertificateModel.listFromUserData(data);
            final languages = LanguageModel.listFromUserData(data);
            final completion = CvCompletionModel.fromUserData(data);

            return RefreshIndicator(
              color: _primary,
              onRefresh: () => controller.refreshProfile(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Column(
                children: [
                  _buildCompletionProgressBar(completion),
                  _buildProfileInfoCard(context, data),
                  const SizedBox(height: 22),
                  _buildSelfIntroSection(context, selfIntro),
                  const SizedBox(height: 22),
                  _buildExperienceSection(context, workExperiences, data),
                  const SizedBox(height: 22),
                  _buildEducationSection(context, educations),
                  const SizedBox(height: 22),
                  _buildSkillsSection(context, skills),
                  const SizedBox(height: 22),
                  _buildProjectsSection(context, projects),
                  const SizedBox(height: 22),
                  _buildCertificatesSection(context, certificates),
                  const SizedBox(height: 22),
                  _buildLanguagesSection(context, languages),
                ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompletionProgressBar(CvCompletionModel completion) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F2937), Color(0xFF111827)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111827).withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              Text(
                '${completion.percent}%',
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: completion.percent / 100,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            ),
          ),
          if (completion.percent < 100) ...[
            const SizedBox(height: 12),
            Text(
              'Cập nhật thêm thông tin để thu hút nhà tuyển dụng hơn.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildProfileInfoCard(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final fullName = _joinValues([data['firstName'], data['lastName']]);
    final phone = _stringValue(data['phone']);
    final email = _stringValue(data['email']);
    final rawGender = _stringValue(data['gender']);
    String gender = '';
    if (rawGender == 'male') {
      gender = 'Nam';
    } else if (rawGender == 'female') {
      gender = 'Nữ';
    } else if (rawGender == 'other') {
      gender = 'Khác';
    } else if (rawGender.isNotEmpty) {
      gender = rawGender;
    }
    final dateOfBirth = _dateValue(data['dateOfBirth']);
    final address = _joinValues([data['companyAddress'], data['address']]);
    final items = <Widget>[
      if (fullName.isNotEmpty)
        _buildInfoLine(context, Icons.people_outline, fullName),
      if (phone.isNotEmpty)
        _buildVerifiedInfoLine(context, Icons.phone_outlined, phone),
      if (email.isNotEmpty)
        _buildVerifiedInfoLine(context, Icons.email_outlined, email),
      if (address.isNotEmpty)
        _buildInfoLine(context, Icons.location_on_outlined, address),
      if (gender.isNotEmpty)
        _buildInfoLine(context, Icons.wc_outlined, gender),
      if (dateOfBirth.isNotEmpty)
        _buildInfoLine(context, Icons.cake_outlined, dateOfBirth),
    ];

    return _ProfileFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildIconBox(Icons.person_outline),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Thông tin cá nhân',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsAccountScreen(),
                  ),
                ),
                icon: Icon(
                  Icons.edit_outlined,
                  color: context.textSecondary,
                  size: 28,
                ),
              ),
            ],
          ),
          if (items.isNotEmpty) ...[const SizedBox(height: 12), ...items],
        ],
      ),
    );
  }

  String _stringValue(dynamic value) {
    if (value == null) return '';
    final text = value.toString().trim();
    if (text == 'Not set' || text == 'Chưa cập nhật') return '';
    return text;
  }

  String _joinValues(List<dynamic> values) {
    return values
        .map(_stringValue)
        .where((value) => value.isNotEmpty)
        .join(' ');
  }

  String _dateValue(dynamic value) {
    if (value == null) return '';
    if (value is Timestamp) {
      return DateFormat('dd/MM/yyyy').format(value.toDate());
    }
    return _stringValue(value);
  }

  Widget _buildInfoLine(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 16, color: context.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedInfoLine(
      BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 16, color: context.textPrimary),
            ),
          ),
          const Icon(
            Icons.check_circle_outline,
            size: 20,
            color: Color(0xFF37B96B),
          ),
        ],
      ),
    );
  }

  Future<void> _pushScreen(BuildContext context, Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onAction,
    required IconData actionIcon,
  }) {
    return Row(
      children: [
        _buildIconBox(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          onPressed: onAction,
          icon: Icon(actionIcon, color: context.textSecondary, size: 28),
        ),
      ],
    );
  }

  Widget _buildListItemCard(
    BuildContext context, {
    required String title,
    String? subtitle,
    String? meta,
    String? body,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.elevatedSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 15,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                    if (meta != null && meta.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        meta,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onEdit != null)
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 22),
                  color: context.textSecondary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              if (onDelete != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 22),
                  color: const Color(0xFFE64A4A),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
          if (body != null && body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              body,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: context.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context, {
    required String title,
    required String message,
    required Future<void> Function() onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Color(0xFFE64A4A))),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await onConfirm();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể xóa. Vui lòng thử lại.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildSelfIntroSection(BuildContext context, String intro) {
    return _ProfileFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            icon: Icons.favorite_border,
            title: 'Giới thiệu bản thân',
            actionIcon: intro.isEmpty ? Icons.add_circle_outline : Icons.edit_outlined,
            onAction: () => _pushScreen(context, const SelfIntroductionScreen()),
          ),
          if (intro.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              intro,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: context.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEducationSection(
    BuildContext context,
    List<EducationModel> items,
  ) {
    return _ProfileFormCard(
      child: Column(
        children: [
          _buildSectionHeader(
            context,
            icon: Icons.school_outlined,
            title: 'Học vấn',
            actionIcon: Icons.add_circle_outline,
            onAction: () => _pushScreen(context, const EducationScreen()),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...items.map(
              (e) => _buildListItemCard(
                context,
                title: e.school,
                subtitle: [
                  if (e.major.isNotEmpty) e.major,
                  if (e.degree.isNotEmpty) e.degree,
                ].join(' · '),
                meta: e.yearRange,
                body: e.description,
                onEdit: () => _pushScreen(
                  context,
                  EducationScreen(education: e),
                ),
                onDelete: () => _confirmDelete(
                  context,
                  title: 'Xóa học vấn',
                  message: 'Bạn có chắc muốn xóa "${e.school}"?',
                  onConfirm: () =>
                      Get.find<UpdateAccountController>().removeEducation(e.id),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSkillsSection(BuildContext context, List<String> skills) {
    return _ProfileFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            icon: Icons.bolt_outlined,
            title: 'Kỹ năng',
            actionIcon: Icons.edit_outlined,
            onAction: () => _pushScreen(context, const SkillsScreen()),
          ),
          if (skills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: skills
                  .map(
                    (s) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _iconBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        s,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProjectsSection(
    BuildContext context,
    List<ProjectModel> items,
  ) {
    return _ProfileFormCard(
      child: Column(
        children: [
          _buildSectionHeader(
            context,
            icon: Icons.theater_comedy_outlined,
            title: 'Dự án/ Thành tựu',
            actionIcon: Icons.add_circle_outline,
            onAction: () => _pushScreen(context, const ProjectScreen()),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...items.map(
              (p) => _buildListItemCard(
                context,
                title: p.name,
                meta: p.dateRange,
                body: p.description,
                onEdit: () => _pushScreen(context, ProjectScreen(project: p)),
                onDelete: () => _confirmDelete(
                  context,
                  title: 'Xóa dự án',
                  message: 'Bạn có chắc muốn xóa "${p.name}"?',
                  onConfirm: () =>
                      Get.find<UpdateAccountController>().removeProject(p.id),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCertificatesSection(
    BuildContext context,
    List<CertificateModel> items,
  ) {
    return _ProfileFormCard(
      child: Column(
        children: [
          _buildSectionHeader(
            context,
            icon: Icons.card_membership_outlined,
            title: 'Chứng chỉ/ Bằng cấp',
            actionIcon: Icons.add_circle_outline,
            onAction: () => _pushScreen(context, const CertificateScreen()),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...items.map(
              (c) => _buildListItemCard(
                context,
                title: c.name,
                onEdit: () =>
                    _pushScreen(context, CertificateScreen(certificate: c)),
                onDelete: () => _confirmDelete(
                  context,
                  title: 'Xóa chứng chỉ',
                  message: 'Bạn có chắc muốn xóa "${c.name}"?',
                  onConfirm: () => Get.find<UpdateAccountController>()
                      .removeCertificate(c.id),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLanguagesSection(
    BuildContext context,
    List<LanguageModel> items,
  ) {
    return _ProfileFormCard(
      child: Column(
        children: [
          _buildSectionHeader(
            context,
            icon: Icons.translate_outlined,
            title: 'Ngoại ngữ',
            actionIcon: Icons.add_circle_outline,
            onAction: () => _pushScreen(context, const ForeignLanguageScreen()),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...items.map(
              (l) => _buildListItemCard(
                context,
                title: l.language,
                subtitle: l.level,
                onEdit: () => _pushScreen(
                  context,
                  ForeignLanguageScreen(language: l),
                ),
                onDelete: () => _confirmDelete(
                  context,
                  title: 'Xóa ngoại ngữ',
                  message: 'Bạn có chắc muốn xóa "${l.language}"?',
                  onConfirm: () =>
                      Get.find<UpdateAccountController>().removeLanguage(l.id),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openWorkExperienceScreen(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WorkExperienceScreen()),
    );
  }

  Future<void> _openEditWorkExperienceScreen(
    BuildContext context,
    WorkExperienceModel experience,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkExperienceScreen(experience: experience),
      ),
    );
  }

  Future<void> _declareNoWorkExperience(BuildContext context) async {
    try {
      final controller = Get.find<UpdateAccountController>();
      await controller.declareNoWorkExperience();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật: Bạn chưa có kinh nghiệm làm việc'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể lưu. Vui lòng thử lại.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildExperienceSection(
    BuildContext context,
    List<WorkExperienceModel> experiences,
    Map<String, dynamic> data,
  ) {
    final declaredNo = WorkExperienceModel.hasDeclaredNoExperience(data);
    final showPrompt = experiences.isEmpty && !declaredNo;

    return _ProfileFormCard(
      child: Column(
        children: [
          Row(
            children: [
              _buildIconBox(Icons.business_center_outlined),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Kinh nghiệm làm việc',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              if (showPrompt)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8FFF1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Đề xuất',
                    style: TextStyle(
                      color: Color(0xFF37B96B),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (!declaredNo)
                IconButton(
                  onPressed: () => _openWorkExperienceScreen(context),
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: context.textSecondary,
                    size: 28,
                  ),
                ),
            ],
          ),
          if (declaredNo) ...[
            const SizedBox(height: 14),
            _buildNoExperienceInfo(context),
          ] else if (showPrompt) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.palette.elevatedSurface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bạn đã có kinh nghiệm làm việc chưa?',
                    style: TextStyle(fontSize: 16, color: context.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _declareNoWorkExperience(context),
                          child: _buildExperienceChoice('Chưa có'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _openWorkExperienceScreen(context),
                          child: _buildExperienceChoice('Đã có'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            ...experiences.map(
              (e) => _buildExperienceItem(context, e),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExperienceItem(
    BuildContext context,
    WorkExperienceModel experience,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.elevatedSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      experience.position,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      experience.company,
                      style: TextStyle(
                        fontSize: 15,
                        color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      experience.dateRange,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () =>
                    _openEditWorkExperienceScreen(context, experience),
                icon: Icon(
                  Icons.edit_outlined,
                  color: context.textSecondary,
                  size: 22,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => _confirmDeleteExperience(context, experience),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFE64A4A),
                  size: 22,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          if (experience.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              experience.description,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: context.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDeleteExperience(
    BuildContext context,
    WorkExperienceModel experience,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa kinh nghiệm'),
        content: Text(
          'Bạn có chắc muốn xóa kinh nghiệm tại "${experience.company}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Xóa',
              style: TextStyle(color: Color(0xFFE64A4A)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final controller = Get.find<UpdateAccountController>();
      await controller.removeWorkExperience(experience.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa kinh nghiệm làm việc'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể xóa. Vui lòng thử lại.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildNoExperienceInfo(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.elevatedSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: _primary.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bạn chưa có kinh nghiệm làm việc',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Thông tin này đã được lưu vào hồ sơ của bạn.',
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _openWorkExperienceScreen(context),
            child: const Text(
              'Tôi đã có kinh nghiệm — Thêm ngay',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E7D32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceChoice(String title, {bool selected = false}) {
    return Container(
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE8F5E9) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? _primary : _border,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          color: selected ? _primary : const Color(0xFF333333),
        ),
      ),
    );
  }

  Widget _buildIconBox(IconData icon) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: _iconBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: _primary, size: 24),
    );
  }
}

class _ProfileFormCard extends StatelessWidget {
  final Widget child;

  const _ProfileFormCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E1E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}
