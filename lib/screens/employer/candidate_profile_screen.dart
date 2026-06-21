import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/candidate_profile_models.dart';
import '../../data/models/employer_review_model.dart';
import '../../data/models/job_criteria_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/work_experience_model.dart';
import '../../data/services/candidate_discovery_service.dart';
import '../../data/services/employer_review_service.dart';
import '../../data/services/messaging_service.dart';
import '../../utils/messaging_bootstrap.dart';
import '../messaging/chat_room_screen.dart';
import 'candidate_public_reviews_screen.dart';
import 'hire_request_sheet.dart';

class CandidateProfileScreen extends StatefulWidget {
  const CandidateProfileScreen({super.key, required this.candidate});

  final UserModel candidate;

  @override
  State<CandidateProfileScreen> createState() => _CandidateProfileScreenState();
}

class _CandidateProfileScreenState extends State<CandidateProfileScreen> {
  Map<String, dynamic>? _data;
  UserModel? _candidate;
  List<EmployerReviewItem> _reviews = const [];
  bool _loading = true;
  bool _openingChat = false;

  UserModel get candidate => _candidate ?? widget.candidate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final employerId = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('users')
            .doc(widget.candidate.id)
            .get(),
        EmployerReviewService().fetchReviews(targetUid: widget.candidate.id),
      ]);
      final userDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final reviews = results[1] as List<EmployerReviewItem>;
      final data = Map<String, dynamic>.from(
        userDoc.data() ?? widget.candidate.toMap(),
      );
      data['uid'] = userDoc.id.isEmpty ? widget.candidate.id : userDoc.id;
      if (!mounted) return;
      setState(() {
        _data = data;
        _candidate = UserModel.fromMap(data);
        _reviews = reviews;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }

    if (employerId.isNotEmpty) {
      await CandidateDiscoveryService().recordProfileView(
        candidateId: widget.candidate.id,
        employerId: employerId,
      );
    }
  }

  Future<void> _confirmMessage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bắt đầu trò chuyện?'),
        content: Text(
          'Bạn có muốn nhắn tin với ${_displayName(candidate)} không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Nhắn tin'),
          ),
        ],
      ),
    );
    if (confirmed != true || _openingChat) return;

    final employerId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (employerId.isEmpty) {
      Get.snackbar('Lỗi', 'Phiên đăng nhập đã hết hạn.');
      return;
    }
    setState(() => _openingChat = true);
    try {
      final groupId = await MessagingService().getOrCreateDirectChat(
        jobId: 'candidate_discovery',
        jobTitle: 'Trao đổi tuyển dụng',
        employerId: employerId,
        candidateId: candidate.id,
      );
      await MessagingBootstrap.ensureController().loadInbox();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(groupId: groupId, isEmployer: true),
        ),
      );
    } catch (_) {
      Get.snackbar('Lỗi', 'Không thể mở cuộc trò chuyện. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  void _openHireRequest() {
    showHireRequestSheet(
      context: context,
      candidateId: candidate.id,
      candidateName: _displayName(candidate),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Chi tiết người làm'),
        foregroundColor: Colors.white,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF7B1FA2), Color(0xFF1565C0)],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 14),
                  _buildPersonalInfo(),
                  ..._buildCvSections(),
                  const SizedBox(height: 14),
                  _buildReviews(),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openingChat ? null : _confirmMessage,
                  icon: _openingChat
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('Nhắn tin'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    foregroundColor: const Color(0xFF1565C0),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _openHireRequest,
                  icon: const Icon(Icons.handshake_outlined),
                  label: const Text('Thuê người làm'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    backgroundColor: const Color(0xFF7B1FA2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final name = _displayName(candidate);
    return _card(
      child: Column(
        children: [
          _avatar(candidate, 96),
          const SizedBox(height: 12),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 4),
              Text(
                candidate.averageRating > 0
                    ? candidate.averageRating.toStringAsFixed(1)
                    : 'Chưa có đánh giá',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 14),
              const Icon(
                Icons.work_history_outlined,
                color: Color(0xFF1565C0),
                size: 18,
              ),
              const SizedBox(width: 4),
              Text('${candidate.totalJobsDone} việc đã làm'),
            ],
          ),
          if (JobCriteriaModel.fromUserData(
                _data ?? const {},
              )?.position.isNotEmpty ==
              true) ...[
            const SizedBox(height: 10),
            Text(
              JobCriteriaModel.fromUserData(_data!)!.position,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPersonalInfo() {
    final criteria = JobCriteriaModel.fromUserData(_data ?? const {});
    return _card(
      title: 'Thông tin cá nhân và nhu cầu tìm việc',
      child: Column(
        children: [
          _info(Icons.email_outlined, 'Email', candidate.email),
          _info(Icons.phone_outlined, 'Số điện thoại', candidate.phone),
          _info(Icons.person_outline, 'Giới tính', candidate.gender ?? ''),
          _info(
            Icons.cake_outlined,
            'Ngày sinh',
            candidate.dateOfBirth == null
                ? ''
                : DateFormat('dd/MM/yyyy').format(candidate.dateOfBirth!),
          ),
          if (criteria != null) ...[
            _info(
              Icons.category_outlined,
              'Ngành nghề',
              criteria.careers.join(', '),
            ),
            _info(
              Icons.location_on_outlined,
              'Khu vực',
              criteria.locations.join(', '),
            ),
            _info(
              Icons.payments_outlined,
              'Mức lương mong muốn',
              criteria.salaryDisplay ?? '',
            ),
            _info(
              Icons.schedule_outlined,
              'Hình thức làm việc',
              criteria.workTypes.join(', '),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildCvSections() {
    final data = _data ?? const <String, dynamic>{};
    final widgets = <Widget>[];
    final introduction = selfIntroductionFromUserData(data);
    final skills = skillsFromUserData(data);
    final experiences = WorkExperienceModel.listFromUserData(data);
    final educations = EducationModel.listFromUserData(data);
    final projects = ProjectModel.listFromUserData(data);
    final certificates = CertificateModel.listFromUserData(data);
    final languages = LanguageModel.listFromUserData(data);
    final cvUrl = (data['cvUrl'] ?? '').toString().trim();
    final cvName = (data['cvFileName'] ?? 'CV của ứng viên').toString();

    void add(Widget widget) {
      widgets.add(const SizedBox(height: 14));
      widgets.add(widget);
    }

    if (introduction.isNotEmpty) {
      add(_textSection('Giới thiệu', introduction));
    }
    if (skills.isNotEmpty) {
      add(
        _card(
          title: 'Kỹ năng',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: skills
                .map(
                  (skill) => Chip(
                    label: Text(skill),
                    backgroundColor: const Color(0xFFE3F2FD),
                    side: BorderSide.none,
                  ),
                )
                .toList(),
          ),
        ),
      );
    }
    if (experiences.isNotEmpty) {
      add(
        _listSection(
          'Kinh nghiệm làm việc',
          experiences.map((item) {
            final title = [
              item.position,
              item.company,
            ].where((value) => value.trim().isNotEmpty).join(' tại ');
            return _Line(
              title,
              '${item.dateRange}\n${item.description}'.trim(),
            );
          }).toList(),
        ),
      );
    }
    if (educations.isNotEmpty) {
      add(
        _listSection(
          'Học vấn',
          educations
              .map(
                (item) => _Line(
                  [
                    item.school,
                    item.major,
                  ].where((value) => value.trim().isNotEmpty).join(' - '),
                  [
                    item.degree,
                    item.yearRange,
                    item.description,
                  ].where((value) => value.trim().isNotEmpty).join('\n'),
                ),
              )
              .toList(),
        ),
      );
    }
    if (projects.isNotEmpty) {
      add(
        _listSection(
          'Dự án',
          projects
              .map(
                (item) => _Line(
                  item.name,
                  '${item.dateRange}\n${item.description}'.trim(),
                ),
              )
              .toList(),
        ),
      );
    }
    if (certificates.isNotEmpty) {
      add(
        _listSection(
          'Chứng chỉ',
          certificates.map((item) => _Line(item.name, '')).toList(),
        ),
      );
    }
    if (languages.isNotEmpty) {
      add(
        _listSection(
          'Ngoại ngữ',
          languages.map((item) => _Line(item.language, item.level)).toList(),
        ),
      );
    }
    add(
      _card(
        title: 'File CV',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFFFEBEE),
            child: Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
          ),
          title: Text(cvUrl.isEmpty ? 'Chưa tải lên CV' : cvName),
          trailing: cvUrl.isEmpty
              ? null
              : const Icon(Icons.open_in_new_rounded),
          onTap: cvUrl.isEmpty ? null : () => _openCv(cvUrl),
        ),
      ),
    );
    return widgets;
  }

  Widget _buildReviews() {
    return _card(
      title: 'Đánh giá của người dùng (${_reviews.length})',
      child: _reviews.isEmpty
          ? Text(
              'Người làm này chưa có đánh giá.',
              style: TextStyle(color: Colors.grey.shade600),
            )
          : Column(
              children: [
                ..._reviews.take(3).map(_reviewTile),
                if (_reviews.length > 3)
                  TextButton.icon(
                    onPressed: () => Get.to(
                      () => CandidatePublicReviewsScreen(candidate: candidate),
                    ),
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('Xem tất cả đánh giá'),
                  ),
              ],
            ),
    );
  }

  Widget _reviewTile(EmployerReviewItem review) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFF3E5F5),
            backgroundImage: review.reviewerAvatarUrl?.isNotEmpty == true
                ? NetworkImage(review.reviewerAvatarUrl!)
                : null,
            child: review.reviewerAvatarUrl?.isNotEmpty == true
                ? null
                : Text(
                    review.reviewerName.isEmpty
                        ? '?'
                        : review.reviewerName[0].toUpperCase(),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        review.reviewerName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 17,
                    ),
                    Text(review.rating.toStringAsFixed(1)),
                  ],
                ),
                if (review.comment?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(review.comment!.trim()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _textSection(String title, String text) => _card(
    title: title,
    child: Text(text, style: const TextStyle(height: 1.45)),
  );

  Widget _listSection(String title, List<_Line> lines) => _card(
    title: title,
    child: Column(
      children: lines
          .map(
            (line) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(
                Icons.check_circle_outline_rounded,
                color: Color(0xFF1565C0),
              ),
              title: Text(
                line.title.isEmpty ? 'Chưa cập nhật' : line.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: line.subtitle.isEmpty
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(line.subtitle),
                    ),
            ),
          )
          .toList(),
    ),
  );

  Widget _info(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: const Color(0xFF7B1FA2)),
          const SizedBox(width: 10),
          SizedBox(
            width: 125,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? 'Chưa cập nhật' : value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({String? title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }

  Future<void> _openCv(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      Get.snackbar('Lỗi', 'Không thể mở file CV.');
    }
  }
}

String _displayName(UserModel user) =>
    user.fullName.isEmpty ? 'Người làm' : user.fullName;

Widget _avatar(UserModel user, double size) {
  ImageProvider? image;
  if (user.avatarUrl?.isNotEmpty == true) {
    image = NetworkImage(user.avatarUrl!);
  } else if (user.avatarBase64?.isNotEmpty == true) {
    try {
      image = MemoryImage(base64Decode(user.avatarBase64!));
    } catch (_) {}
  }
  return CircleAvatar(
    radius: size / 2,
    backgroundColor: const Color(0xFFE3F2FD),
    backgroundImage: image,
    child: image == null
        ? Text(
            _displayName(user)[0].toUpperCase(),
            style: TextStyle(
              fontSize: size * 0.35,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1565C0),
            ),
          )
        : null,
  );
}

class _Line {
  const _Line(this.title, this.subtitle);
  final String title;
  final String subtitle;
}
