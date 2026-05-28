import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../common/styles/app_colors.dart';
import '../../controller/login_controller.dart';
import '../../data/models/group_chat_model.dart';
import '../../data/services/group_chat_service.dart';
import '../../data/services/notification_service.dart';
import '../../routes/app_routes.dart';

/// Khiếu nại sau khi nhóm đã giải tán — oan ức / thắc mắc về công việc đã làm.
class PostDissolutionComplaintScreen extends StatefulWidget {
  const PostDissolutionComplaintScreen({super.key});

  @override
  State<PostDissolutionComplaintScreen> createState() =>
      _PostDissolutionComplaintScreenState();
}

class _PostDissolutionComplaintScreenState
    extends State<PostDissolutionComplaintScreen> {
  final _auth = Get.find<AuthController>();
  final _groupSvc = GroupChatService();
  final _descCtrl = TextEditingController();
  final _images = <String>[];

  List<GroupChatModel> _closedGroups = [];
  GroupChatModel? _selected;
  bool _loading = true;
  bool _submitting = false;

  bool get _isEmployer => _auth.currentUser?.role == 'employer';

  Color get _accent => _isEmployer
      ? AppColors.employerPrimary
      : AppColors.candidatePrimary;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is GroupChatModel && args.isDissolved) {
      _selected = args;
      _loading = false;
    } else {
      _loadClosedGroups();
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadClosedGroups() async {
    final uid = _auth.currentUser?.id;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      _closedGroups = await _groupSvc.listDissolvedGroupsForUser(uid);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    if (_images.length >= 4) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 55,
      maxWidth: 800,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.length > 800 * 1024) {
      Get.snackbar('Ảnh quá lớn', 'Chọn ảnh nhỏ hơn 800KB');
      return;
    }
    setState(() => _images.add(base64Encode(bytes)));
  }

  Future<void> _submit() async {
    final group = _selected;
    if (group == null) {
      Get.snackbar('Chọn công việc', 'Chọn nhóm đã giải tán để khiếu nại');
      return;
    }
    if (!group.isDissolved) {
      Get.snackbar(
        'Chưa giải tán',
        'Chỉ khiếu nại được sau khi nhóm công việc đã giải tán.',
      );
      return;
    }
    if (_descCtrl.text.trim().length < 10) {
      Get.snackbar('Thiếu nội dung', 'Mô tả ít nhất 10 ký tự');
      return;
    }

    setState(() => _submitting = true);
    try {
      final uid = _auth.currentUser?.id ?? '';
      final common = {
        'jobId': group.jobId,
        'groupId': group.groupId,
        'jobTitle': group.jobTitle,
        'description': _descCtrl.text.trim(),
        'imageBase64s': _images,
        'status': 'pending',
        'postDissolution': true,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_isEmployer) {
        await FirebaseFirestore.instance.collection('jobComplaints').add({
          ...common,
          'employerId': uid,
          'candidateId': '',
          'complaintKind': 'employer_post_dissolution',
        });
      } else {
        await FirebaseFirestore.instance.collection('jobComplaints').add({
          ...common,
          'employerId': group.employerId,
          'candidateId': uid,
          'complaintKind': 'candidate_post_dissolution',
        });
        if (group.employerId.isNotEmpty) {
          await NotificationService().create(
            recipientId: group.employerId,
            type: 'complaint_received',
            title: 'Khiếu nại sau giải tán',
            body:
                'UV gửi thắc mắc/oan ức về ca "${group.jobTitle}" (nhóm đã đóng).',
            data: {'groupId': group.groupId, 'jobId': group.jobId},
          );
        }
      }

      final admins = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .limit(10)
          .get();
      for (final a in admins.docs) {
        await NotificationService().create(
          recipientId: a.id,
          type: 'complaint_post_dissolution',
          title: 'Khiếu nại sau giải tán',
          body: 'Có khiếu nại mới về "${group.jobTitle}".',
          data: {'groupId': group.groupId, 'jobId': group.jobId},
        );
      }

      Get.back();
      Get.snackbar(
        'Đã gửi',
        'Khiếu nại sau giải tán đã lưu. Admin sẽ xem xét.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      Get.toNamed(AppRoutes.complaintsCatalog);
    } catch (e) {
      Get.snackbar('Lỗi', e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        title: const Text('Khiếu nại sau giải tán'),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: _accent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _infoBanner(),
                if (_selected == null) ...[
                  const Text(
                    'Chọn công việc đã giải tán',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  if (_closedGroups.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Chưa có nhóm nào giải tán.\n'
                          'Sau khi Admin/NTD kết thúc và giải ngân xong, '
                          'bạn có thể gửi khiếu nại tại đây.',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    )
                  else
                    ..._closedGroups.map(
                      (g) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.work_off_outlined),
                          title: Text(g.jobTitle,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: const Text('Nhóm đã giải tán'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => setState(() => _selected = g),
                        ),
                      ),
                    ),
                ] else ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_selected!.jobTitle,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 17)),
                    subtitle: const Text('Nhóm đã giải tán'),
                    trailing: IconButton(
                      icon: const Icon(Icons.swap_horiz),
                      onPressed: () => setState(() => _selected = null),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Oan ức / thắc mắc của bạn *',
                      hintText:
                          'Mô tả điều bạn còn bức xúc hoặc chưa rõ sau khi nhóm đã giải tán...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ..._images.map(
                        (b) => ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(b),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('Thêm ảnh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(
                      _submitting ? 'Đang gửi...' : 'Gửi khiếu nại tới Admin',
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _infoBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: _accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Dùng khi nhóm làm việc đã giải tán mà bạn vẫn còn oan ức '
              'hoặc thắc mắc về công việc đó. Không dùng khi nhóm còn đang hoạt động.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }
}
