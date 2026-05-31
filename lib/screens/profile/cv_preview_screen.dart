import 'package:flutter/material.dart';
import 'package:viecnow/data/models/candidate_profile_models.dart';
import 'package:viecnow/data/models/work_experience_model.dart';

/// Xem trước CV (read-only) từ dữ liệu Firestore `users/{uid}`.
class CvPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const CvPreviewScreen({super.key, required this.userData});

  static const _primary = Color(0xFF2E7D32);
  static const _sidebarBg = Color(0xFFF2F4F6);
  static const _sidebarDivider = Color(0xFFDFE3E7);
  static const _heading = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.6,
    color: Colors.black87,
  );
  static const _muted = TextStyle(color: Color(0xFF6B7280), fontSize: 12);
  static const _body = TextStyle(fontSize: 13.5, height: 1.55);

  @override
  Widget build(BuildContext context) {
    final fullName =
        '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
    final headline = (userData['headline'] ?? '').toString().trim();
    final email = (userData['email'] ?? '').toString().trim();
    final phone = (userData['phone'] ?? '').toString().trim();
    final address = (userData['address'] ?? userData['companyAddress'] ?? '')
        .toString()
        .trim();
    final gender = (userData['gender'] ?? '').toString().trim();
    final website = (userData['website'] ?? userData['linkedinUrl'] ?? '')
        .toString()
        .trim();

    final dob = _formatDob(userData['dateOfBirth']);

    final intro = selfIntroductionFromUserData(userData);
    final skills = skillsFromUserData(userData);
    final experiences = WorkExperienceModel.listFromUserData(userData);
    final educations = EducationModel.listFromUserData(userData);
    final projects = ProjectModel.listFromUserData(userData);
    final certificates = CertificateModel.listFromUserData(userData);
    final languages = LanguageModel.listFromUserData(userData);
    final activities = (userData['activities'] ?? '').toString().trim();
    final avatar = (userData['avatarUrl'] ?? '').toString().trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Xem trước CV'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: _CvPaper(
              child: LayoutBuilder(
                builder: (context, c) {
                  final isNarrow = c.maxWidth < 720;
                  return isNarrow
                      ? Column(
                          children: [
                            _sidebar(
                              fullName: fullName,
                              headline: headline,
                              avatarUrl: avatar,
                              dob: dob,
                              gender: gender,
                              phone: phone,
                              email: email,
                              website: website,
                              address: address,
                              skills: skills,
                            ),
                            const SizedBox(height: 12),
                            _main(
                              intro: intro,
                              educations: educations,
                              experiences: experiences,
                              projects: projects,
                              certificates: certificates,
                              languages: languages,
                              activities: activities,
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 280,
                              child: _sidebar(
                                fullName: fullName,
                                headline: headline,
                                avatarUrl: avatar,
                                dob: dob,
                                gender: gender,
                                phone: phone,
                                email: email,
                                website: website,
                                address: address,
                                skills: skills,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: _main(
                                intro: intro,
                                educations: educations,
                                experiences: experiences,
                                projects: projects,
                                certificates: certificates,
                                languages: languages,
                                activities: activities,
                              ),
                            ),
                          ],
                        );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sidebar({
    required String fullName,
    required String headline,
    required String avatarUrl,
    required String dob,
    required String gender,
    required String phone,
    required String email,
    required String website,
    required String address,
    required List<String> skills,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: _sidebarBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _sidebarDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white,
                backgroundImage:
                    avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? const Icon(Icons.person, size: 34, color: _primary)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isEmpty ? 'Ứng viên' : fullName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    if (headline.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        headline,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _subHeading('THÔNG TIN LIÊN HỆ'),
          const SizedBox(height: 8),
          if (dob.isNotEmpty) _kv('Ngày sinh', dob),
          if (gender.isNotEmpty) _kv('Giới tính', gender),
          if (phone.isNotEmpty) _kv('Số điện thoại', phone),
          if (email.isNotEmpty) _kv('Email', email),
          if (website.isNotEmpty) _kv('Website', website),
          if (address.isNotEmpty) _kv('Địa chỉ', address),
          if (skills.isNotEmpty) ...[
            const SizedBox(height: 14),
            _subHeading('KỸ NĂNG'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: skills
                  .map(
                    (s) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _sidebarDivider),
                      ),
                      child: Text(
                        s,
                        style: const TextStyle(
                          fontSize: 12,
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

  Widget _main({
    required String intro,
    required List<EducationModel> educations,
    required List<WorkExperienceModel> experiences,
    required List<ProjectModel> projects,
    required List<CertificateModel> certificates,
    required List<LanguageModel> languages,
    required String activities,
  }) {
    final nothing =
        intro.isEmpty &&
        educations.isEmpty &&
        experiences.isEmpty &&
        projects.isEmpty &&
        certificates.isEmpty &&
        languages.isEmpty &&
        activities.isEmpty;
    if (nothing) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: Text(
            'Chưa có nội dung CV.\nQuay lại và bổ sung các mục.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (intro.isNotEmpty) ...[
            _section('MỤC TIÊU NGHỀ NGHIỆP'),
            Text(intro, style: _body),
            const SizedBox(height: 18),
          ],
          if (educations.isNotEmpty) ...[
            _section('HỌC VẤN'),
            const SizedBox(height: 6),
            ...educations.map(_educationRow),
            const SizedBox(height: 18),
          ],
          if (experiences.isNotEmpty) ...[
            _section('KINH NGHIỆM LÀM VIỆC'),
            const SizedBox(height: 6),
            ...experiences.map(_experienceRow),
            const SizedBox(height: 18),
          ],
          if (projects.isNotEmpty) ...[
            _section('DỰ ÁN'),
            const SizedBox(height: 6),
            ...projects.map(_projectRow),
            const SizedBox(height: 18),
          ],
          if (certificates.isNotEmpty) ...[
            _section('CHỨNG CHỈ - BẰNG CẤP'),
            const SizedBox(height: 6),
            ...certificates.map(_certificateRow),
            const SizedBox(height: 18),
          ],
          if (languages.isNotEmpty) ...[
            _section('NGOẠI NGỮ'),
            const SizedBox(height: 6),
            ...languages.map(_languageRow),
            const SizedBox(height: 18),
          ],
          if (activities.isNotEmpty) ...[
            _section('HOẠT ĐỘNG NGOẠI KHÓA'),
            Text(activities, style: _body),
          ],
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _heading),
          const SizedBox(height: 6),
          Container(height: 1, color: const Color(0xFF111827)),
        ],
      ),
    );
  }

  Widget _educationRow(EducationModel e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(e.yearRange, style: _muted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.school,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _joinNonEmpty([e.major, e.degree]),
                  style: const TextStyle(fontSize: 13),
                ),
                if (e.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(e.description.trim(), style: _body),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _experienceRow(WorkExperienceModel e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(e.dateRange, style: _muted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.company,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  e.position,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (e.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(e.description.trim(), style: _body),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _projectRow(ProjectModel p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(p.dateRange, style: _muted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                if (p.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(p.description.trim(), style: _body),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _certificateRow(CertificateModel c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 92),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              c.name.trim(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _languageRow(LanguageModel lang) {
    final label = lang.level.trim().isNotEmpty
        ? '${lang.language.trim()} · ${lang.level.trim()}'
        : lang.language.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 92),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subHeading(String t) {
    return Text(
      t,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.7,
        color: Color(0xFF374151),
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 98,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: _muted.copyWith(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  static String _joinNonEmpty(List<String> parts) {
    return parts.map((e) => e.trim()).where((e) => e.isNotEmpty).join(' · ');
  }

  static String _formatDob(dynamic value) {
    // value có thể là Timestamp hoặc DateTime theo schema.
    try {
      if (value == null) return '';
      DateTime? dt;
      if (value is DateTime) dt = value;
      // Tránh import Timestamp trực tiếp trong UI để không phụ thuộc cloud_firestore.
      final type = value.runtimeType.toString();
      if (dt == null && type.contains('Timestamp')) {
        final dyn = value as dynamic;
        dt = dyn.toDate() as DateTime?;
      }
      if (dt == null) return '';
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final y = dt.year.toString();
      return '$d/$m/$y';
    } catch (_) {
      return '';
    }
  }
}

class _CvPaper extends StatelessWidget {
  final Widget child;
  const _CvPaper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}
