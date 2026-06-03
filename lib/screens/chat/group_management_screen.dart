import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../common/styles/app_colors.dart';
import '../../controller/login_controller.dart';
import '../../data/models/group_chat_model.dart';
import '../../data/models/user_model.dart';
import '../../data/services/group_chat_service.dart';
import '../../data/services/messaging_service.dart';
import '../../data/services/notification_service.dart';
import '../../utils/messaging_bootstrap.dart';
import '../../routes/app_routes.dart';
import '../messaging/chat_room_screen.dart';
import '../attendance/candidate_attendance_screen.dart';
import '../../data/services/attendance_auto_notify_service.dart';
import '../attendance/candidate_work_assignment_screen.dart';
import '../../widgets/chat_wallpaper_picker_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GroupManagementScreen
// Argument: GroupChatModel
// ─────────────────────────────────────────────────────────────────────────────
class GroupManagementScreen extends StatefulWidget {
  const GroupManagementScreen({super.key});

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  late final GroupChatModel _initGroup;
  late final bool _isCandidateTheme;
  final _service = GroupChatService();
  final _auth = Get.find<AuthController>();
  bool _isUploadingAvatar = false;
  bool _togglingMute = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is Map) {
      _initGroup = args['group'] as GroupChatModel;
      _isCandidateTheme = args['isCandidate'] == true;
    } else {
      _initGroup = args as GroupChatModel;
      final uid = _auth.currentUser?.id ?? '';
      _isCandidateTheme = uid.isNotEmpty && _initGroup.employerId != uid;
    }
  }

  String get _currentUserId => _auth.currentUser?.id ?? '';

  bool get _showLeaveGroup =>
      _isCandidateTheme || _initGroup.employerId != _currentUserId;

  Color get _accent => _isCandidateTheme
      ? AppColors.candidatePrimary
      : AppColors.employerPrimary;

  LinearGradient get _headerGradient => _isCandidateTheme
      ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B5E20),
            Color(0xFF2E7D32),
            Color(0xFF43A047),
            Color(0xFF66BB6A),
          ],
          stops: [0.0, 0.35, 0.70, 1.0],
        )
      : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6A0DAD),
            Color(0xFF7B1FA2),
            Color(0xFF1565C0),
            Color(0xFF0D47A1),
          ],
          stops: [0.0, 0.35, 0.70, 1.0],
        );

  // ── Thay ảnh đại diện nhóm ────────────────────────────────────────────────
  Future<void> _changeAvatar(GroupChatModel group) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_rounded, color: _accent),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: Color(0xFF1565C0),
              ),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 60,
      maxWidth: 400,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (bytes.length > 500 * 1024) {
      Get.snackbar(
        'Ảnh quá lớn',
        'Vui lòng chọn ảnh nhỏ hơn 500KB',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _isUploadingAvatar = true);
    try {
      final b64 = base64Encode(bytes);
      await _service.updateGroupAvatar(group.groupId, b64);
      Get.snackbar(
        'Thành công',
        'Đã cập nhật ảnh nhóm',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Không thể cập nhật ảnh nhóm',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  // ── Mở trang thành viên ──────────────────────────────────────────────────
  void _openMembers(GroupChatModel group) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) =>
            _MembersScreen(group: group, isCandidateTheme: _isCandidateTheme),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
    );
  }

  Future<void> _openWallpaperPicker(GroupChatModel group) async {
    await showChatWallpaperPicker(
      context: context,
      groupId: group.groupId,
      isCandidateTheme: _isCandidateTheme,
    );
  }

  // ── Mở biệt danh ────────────────────────────────────────────────────────
  void _openNicknames(GroupChatModel group) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) =>
            _NicknamesScreen(group: group, isCandidateTheme: _isCandidateTheme),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
    );
  }

  // ── Tìm kiếm tin nhắn ────────────────────────────────────────────────────
  void _openSearch(GroupChatModel group) {
    Get.toNamed(AppRoutes.searchMessages, arguments: group);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GroupChatModel?>(
      stream: _service.streamGroup(_initGroup.groupId),
      initialData: _initGroup,
      builder: (context, snapshot) {
        final group = snapshot.data ?? _initGroup;
        return Scaffold(
          backgroundColor: const Color(0xFFF0F2F8),
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildHeader(group),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _SectionLabel(label: 'CÔNG CỤ QUẢN LÝ'),
                    const SizedBox(height: 12),
                    _buildToolsGrid(group),
                    const SizedBox(height: 24),
                    _SectionLabel(label: 'KHÁC'),
                    const SizedBox(height: 12),
                    _buildOtherList(group),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(GroupChatModel group) {
    Uint8List? avatarBytes;
    if (group.groupAvatarBase64 != null &&
        group.groupAvatarBase64!.isNotEmpty) {
      try {
        avatarBytes = base64Decode(group.groupAvatarBase64!);
      } catch (_) {}
    }

    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      stretch: true,
      backgroundColor: _accent,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: Container(
          decoration: BoxDecoration(gradient: _headerGradient),
          child: Stack(
            children: [
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 36),
                      // Avatar
                      Stack(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: avatarBytes == null
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: _isCandidateTheme
                                          ? const [
                                              Color(0xFFA5D6A7),
                                              Color(0xFF2E7D32),
                                            ]
                                          : const [
                                              Color(0xFFCE93D8),
                                              Color(0xFF7B1FA2),
                                            ],
                                    )
                                  : null,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                              image: avatarBytes != null
                                  ? DecorationImage(
                                      image: MemoryImage(avatarBytes),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: avatarBytes == null
                                ? const Icon(
                                    Icons.group,
                                    color: Colors.white,
                                    size: 40,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _changeAvatar(group),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.18),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: _isUploadingAvatar
                                    ? Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _accent,
                                        ),
                                      )
                                    : Icon(
                                        Icons.camera_alt_rounded,
                                        size: 16,
                                        color: _accent,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        group.jobTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.people_alt_outlined,
                            color: Colors.white70,
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${group.memberIds.length} thành viên',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Get.back(),
      ),
      title: const Text(
        'Quản lý nhóm',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 17,
        ),
      ),
    );
  }

  // ── Grid công cụ ─────────────────────────────────────────────────────────
  Widget _buildToolsGrid(GroupChatModel group) {
    final tools = [
      _Tool(
        icon: Icons.people_alt_rounded,
        label: 'Thành viên',
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => _openMembers(group),
      ),
      _Tool(
        icon: Icons.badge_rounded,
        label: 'Biệt danh',
        gradient: const LinearGradient(
          colors: [Color(0xFF7B1FA2), Color(0xFFCE93D8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => _openNicknames(group),
      ),
      _Tool(
        icon: Icons.wallpaper_rounded,
        label: 'Hình nền',
        gradient: LinearGradient(
          colors: _isCandidateTheme
              ? const [Color(0xFF2E7D32), Color(0xFF81C784)]
              : const [Color(0xFF5E35B1), Color(0xFF9575CD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => _openWallpaperPicker(group),
      ),
      _Tool(
        icon: Icons.fact_check_rounded,
        label: 'Điểm danh',
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () async {
          if (_isCandidateTheme) {
            Get.to(
              () => CandidateAttendanceScreen(group: group),
              transition: Transition.rightToLeft,
            );
          } else {
            await AttendanceAutoNotifyService.instance
                .onEmployerOpensAttendance(group);
            Get.toNamed(
              AppRoutes.attendance,
              arguments: {
                'groupId': group.groupId,
                'jobId': group.jobId,
                'jobTitle': group.jobTitle,
                'memberIds': group.memberIds,
                'employerId': group.employerId,
              },
            );
          }
        },
      ),
      _Tool(
        icon: Icons.assignment_rounded,
        label: 'Phân công công việc',
        gradient: const LinearGradient(
          colors: [Color(0xFFE65100), Color(0xFFFFB74D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () {
          if (_isCandidateTheme) {
            Get.to(() => CandidateWorkAssignmentScreen(group: group));
          } else {
            Get.toNamed(AppRoutes.workSchedule, arguments: group);
          }
        },
      ),
      _Tool(
        icon: Icons.report_problem_rounded,
        label: 'Khiếu nại',
        gradient: const LinearGradient(
          colors: [Color(0xFFC62828), Color(0xFFEF9A9A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () {
          if (group.isDissolved) {
            Get.toNamed(AppRoutes.postDissolutionComplaint, arguments: group);
          } else {
            if (_isCandidateTheme) {
              Get.toNamed(AppRoutes.candidateJobComplaint, arguments: group);
            } else {
              Get.toNamed(AppRoutes.complaint, arguments: group);
            }
          }
        },
      ),
      if (!_isCandidateTheme)
        _Tool(
          icon: Icons.table_chart_rounded,
          label: 'Bảng điểm danh',
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF64B5F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onTap: () =>
              Get.toNamed(AppRoutes.jobAttendanceSummary, arguments: group),
        ),
      _Tool(
        icon: Icons.search_rounded,
        label: 'Tìm tin nhắn',
        gradient: const LinearGradient(
          colors: [Color(0xFF00695C), Color(0xFF4DB6AC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => _openSearch(group),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
        children: tools.map((t) => _ToolCell(tool: t)).toList(),
      ),
    );
  }

  // ── Bật / tắt thông báo nhóm ─────────────────────────────────────────────
  Future<void> _toggleMute(GroupChatModel group) async {
    if (_togglingMute) return;
    setState(() => _togglingMute = true);
    final isMuted = group.mutedBy.contains(_currentUserId);
    final willMute = !isMuted;
    try {
      await _service.toggleMute(group.groupId, _currentUserId, isMuted);
      if (willMute) {
        final mc = MessagingBootstrap.ensureController();
        await mc.dismissNotificationsForMutedGroup(group.groupId);
      }
    } finally {
      if (mounted) setState(() => _togglingMute = false);
    }
  }

  // ── Khác ──────────────────────────────────────────────────────────────────
  Widget _buildOtherList(GroupChatModel group) {
    final isMuted = group.mutedBy.contains(_currentUserId);
    return _FeatureCard(
      items: [
        _FeatureItem(
          icon: Icons.wallpaper_rounded,
          iconBg: _isCandidateTheme
              ? const Color(0xFF2E7D32)
              : const Color(0xFF5E35B1),
          title: 'Hình nền chat',
          subtitle: 'Đổi nền khung hội thoại (chỉ bạn thấy)',
          onTap: () => _openWallpaperPicker(group),
        ),
        _FeatureItem(
          icon: isMuted
              ? Icons.notifications_off_outlined
              : Icons.notifications_outlined,
          iconBg: const Color(0xFF00695C),
          title: 'Thông báo nhóm',
          subtitle: isMuted ? 'Đã tắt thông báo' : 'Đang bật thông báo',
          trailing: _togglingMute
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Switch(
                  value: !isMuted,
                  onChanged: (_) => _toggleMute(group),
                  activeColor: _accent,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
          onTap: () => _toggleMute(group),
        ),
        if (!_isCandidateTheme)
          _FeatureItem(
            icon: Icons.edit_outlined,
            iconBg: const Color(0xFF6A1B9A),
            title: 'Đổi tên nhóm',
            subtitle: group.jobTitle,
            onTap: () => _renameGroup(group),
          ),
        _FeatureItem(
          icon: _showLeaveGroup
              ? Icons.logout_rounded
              : Icons.delete_forever_outlined,
          iconBg: const Color(0xFFC62828),
          title: _showLeaveGroup ? 'Rời khỏi nhóm' : 'Giải tán nhóm',
          subtitle: _showLeaveGroup
              ? 'Thoát nhóm chat này'
              : 'Xóa nhóm và toàn bộ dữ liệu',
          titleColor: const Color(0xFFC62828),
          onTap: () =>
              _showLeaveGroup ? _confirmLeave(group) : _confirmDisband(group),
          isLast: true,
        ),
      ],
    );
  }

  void _renameGroup(GroupChatModel group) {
    final ctrl = TextEditingController(text: group.jobTitle);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.edit_rounded, color: _accent, size: 22),
            const SizedBox(width: 8),
            const Text(
              'Đổi tên nhóm',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 60,
          decoration: InputDecoration(
            hintText: 'Nhập tên nhóm mới',
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 18,
            ),
            label: const Text('Lưu', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty || name == group.jobTitle) {
                Get.back();
                return;
              }
              await FirebaseFirestore.instance
                  .collection('groupChats')
                  .doc(group.groupId)
                  .update({'jobTitle': name});
              Get.back();
              Get.snackbar(
                'Đổi tên thành công',
                'Tên nhóm: $name',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.green,
                colorText: Colors.white,
                duration: const Duration(seconds: 2),
              );
            },
          ),
        ],
      ),
    );
  }

  void _confirmLeave(GroupChatModel group) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFC62828), size: 26),
            SizedBox(width: 8),
            Text(
              'Rời khỏi nhóm',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFFC62828),
                fontSize: 17,
              ),
            ),
          ],
        ),
        content: const Text(
          'Bạn sẽ không còn trong nhóm chat này và không nhận tin nhắn mới. '
          'Lịch sử tin nhắn của nhóm vẫn được giữ cho các thành viên khác.',
          style: TextStyle(fontSize: 14, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Get.back();
              try {
                // Hủy ứng tuyển nếu user là candidate
                final db = FirebaseFirestore.instance;
                final snap = await db
                    .collection('applications')
                    .where('jobId', isEqualTo: group.jobId)
                    .where('candidateId', isEqualTo: _currentUserId)
                    .where('status', whereIn: ['pending', 'accepted'])
                    .get();

                var appId = '';
                var wasAccepted = false;

                if (snap.docs.isNotEmpty) {
                  final doc = snap.docs.first;
                  final data = doc.data();
                  appId = (data['appId'] ?? doc.id).toString();
                  final status = data['status'] as String?;
                  wasAccepted = status == 'accepted';
                  await doc.reference.update({
                    'status': 'withdrawn',
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  if (wasAccepted) {
                    await db.collection('jobPosts').doc(group.jobId).update({
                      'filledSlots': FieldValue.increment(-1),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    await _cancelCurrentUserSchedules(group.jobId);
                  }
                }

                await _service.leaveGroup(group.groupId, _currentUserId);
                await _notifyEmployerMemberLeftJob(
                  group: group,
                  appId: appId,
                  wasAccepted: wasAccepted,
                );
                Get.close(2);
                Get.snackbar(
                  'Đã rời nhóm',
                  'Bạn đã rời khỏi "${group.jobTitle}" và hủy ứng tuyển.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: _accent,
                  colorText: Colors.white,
                  duration: const Duration(seconds: 2),
                );
              } catch (e) {
                Get.snackbar(
                  'Lỗi',
                  'Không thể rời nhóm: $e',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
            },
            child: const Text(
              'Rời nhóm',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelCurrentUserSchedules(String jobId) async {
    final snap = await FirebaseFirestore.instance
        .collection('schedules')
        .where('candidateId', isEqualTo: _currentUserId)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    var updated = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      if ((data['jobId'] ?? '').toString() != jobId) continue;
      final status = (data['status'] ?? '').toString();
      if (status == 'cancelled' || status == 'completed') continue;
      batch.update(doc.reference, {
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      updated++;
    }
    if (updated > 0) await batch.commit();
  }

  Future<void> _notifyEmployerMemberLeftJob({
    required GroupChatModel group,
    required String appId,
    required bool wasAccepted,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      final candidateName = currentUser?.fullName.trim().isNotEmpty == true
          ? currentUser!.fullName
          : 'Ứng viên';
      await NotificationService.notifyApplicationWithdrawn(
        employerId: group.employerId,
        jobTitle: group.jobTitle,
        candidateName: candidateName,
        wasAccepted: wasAccepted,
        jobId: group.jobId,
        appId: appId,
        candidateId: _currentUserId,
      );
    } catch (_) {
      // Không chặn thao tác rời nhóm nếu chỉ lỗi gửi thông báo.
    }
  }

  void _confirmDisband(GroupChatModel group) {
    final confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFC62828),
                size: 26,
              ),
              SizedBox(width: 8),
              Text(
                'Giải tán nhóm',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFC62828),
                  fontSize: 17,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Text(
                  '⚠️  Hành động này không thể hoàn tác!\n\nToàn bộ tin nhắn, ảnh, dữ liệu điểm danh của nhóm sẽ bị xóa vĩnh viễn.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Gõ "GIẢI TÁN" để xác nhận:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmCtrl,
                autofocus: true,
                onChanged: (_) => setS(() {}),
                decoration: InputDecoration(
                  hintText: 'GIẢI TÁN',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmCtrl.text.trim() == 'GIẢI TÁN'
                    ? const Color(0xFFC62828)
                    : Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: Icon(
                Icons.delete_forever_rounded,
                color: confirmCtrl.text.trim() == 'GIẢI TÁN'
                    ? Colors.white
                    : Colors.grey.shade500,
                size: 18,
              ),
              label: Text(
                'Giải tán',
                style: TextStyle(
                  color: confirmCtrl.text.trim() == 'GIẢI TÁN'
                      ? Colors.white
                      : Colors.grey.shade500,
                ),
              ),
              onPressed: confirmCtrl.text.trim() != 'GIẢI TÁN'
                  ? null
                  : () async {
                      Get.back(); // đóng dialog
                      // Hiển thị loading
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(16),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Đang giải tán nhóm...'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                      try {
                        await _service.disbandGroup(group.groupId);
                        // Đóng loading + tất cả màn hình liên quan
                        Get.close(3);
                        Get.snackbar(
                          'Đã giải tán',
                          'Nhóm "${group.jobTitle}" đã bị xóa',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: const Color(0xFFC62828),
                          colorText: Colors.white,
                          duration: const Duration(seconds: 3),
                        );
                      } catch (e) {
                        Get.back(); // đóng loading
                        Get.snackbar(
                          'Lỗi',
                          'Không thể giải tán nhóm: $e',
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MembersScreen — Xem thành viên
// ─────────────────────────────────────────────────────────────────────────────
class _MembersScreen extends StatefulWidget {
  final GroupChatModel group;
  final bool isCandidateTheme;
  const _MembersScreen({required this.group, this.isCandidateTheme = false});

  @override
  State<_MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<_MembersScreen> {
  final _service = GroupChatService();
  List<UserModel>? _members;
  bool _loading = true;

  Color get _accent => widget.isCandidateTheme
      ? AppColors.candidatePrimary
      : AppColors.employerPrimary;

  LinearGradient get _headerGradient => widget.isCandidateTheme
      ? AppColors.candidateGradient
      : AppColors.employerGradient;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _isGroupAdmin(UserModel member) =>
      member.id == widget.group.employerId || member.role == 'employer';

  Future<void> _load() async {
    final members = await _service.getGroupMembers(widget.group.memberIds);
    members.sort((a, b) {
      final aAdmin = _isGroupAdmin(a);
      final bAdmin = _isGroupAdmin(b);
      if (aAdmin != bAdmin) return aAdmin ? -1 : 1;
      final an = '${a.firstName} ${a.lastName}'.trim().toLowerCase();
      final bn = '${b.firstName} ${b.lastName}'.trim().toLowerCase();
      return an.compareTo(bn);
    });
    if (mounted)
      setState(() {
        _members = members;
        _loading = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _accent,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: _headerGradient),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Thành viên (${widget.group.memberIds.length})',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loading
          ? Center(child: CircularProgressIndicator(color: _accent))
          : _members == null || _members!.isEmpty
          ? Center(
              child: Text(
                'Chưa có thành viên',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _members!.length,
              itemBuilder: (_, i) => _MemberCard(
                member: _members![i],
                group: widget.group,
                isCandidateTheme: widget.isCandidateTheme,
              ),
            ),
    );
  }
}

class _MemberCard extends StatefulWidget {
  final UserModel member;
  final GroupChatModel group;
  final bool isCandidateTheme;
  const _MemberCard({
    required this.member,
    required this.group,
    this.isCandidateTheme = false,
  });

  @override
  State<_MemberCard> createState() => _MemberCardState();
}

class _MemberCardState extends State<_MemberCard> {
  bool _openingChat = false;

  UserModel get member => widget.member;
  GroupChatModel get group => widget.group;

  Color get _accent => widget.isCandidateTheme
      ? AppColors.candidatePrimary
      : AppColors.employerPrimary;

  Color get _chatIconColor => widget.isCandidateTheme
      ? AppColors.candidatePrimary
      : const Color(0xFF1565C0);

  bool get _isAdmin =>
      member.id == group.employerId || member.role == 'employer';

  String get _currentUid => Get.find<AuthController>().currentUser?.id ?? '';

  bool get _isSelf => _currentUid.isNotEmpty && member.id == _currentUid;

  /// Nhắn riêng: NTD ↔ ứng viên hoặc hai thành viên khác trong cùng nhóm.
  bool get _canDirectChat {
    if (_isSelf || _currentUid.isEmpty) return false;
    if (!group.memberIds.contains(_currentUid) ||
        !group.memberIds.contains(member.id)) {
      return false;
    }
    return true;
  }

  /// Chat NTD–ứng viên (direct); còn lại dùng peer trong cùng job.
  bool get _useEmployerDirectChat {
    final employerId = group.employerId;
    if (employerId.isEmpty) return false;
    if (_currentUid == employerId) {
      return member.id != employerId && member.role != 'employer';
    }
    return member.id == employerId || member.role == 'employer';
  }

  Future<void> _openDirectChat() async {
    if (!_canDirectChat || _openingChat) return;

    final employerId = group.employerId;
    final messaging = MessagingService();

    setState(() => _openingChat = true);
    try {
      final String groupId;
      if (_useEmployerDirectChat) {
        final candidateId = _currentUid == employerId ? member.id : _currentUid;
        groupId = await messaging.getOrCreateDirectChat(
          jobId: group.jobId,
          jobTitle: group.jobTitle,
          employerId: employerId,
          candidateId: candidateId,
          excludeGroupId: group.groupId,
        );
      } else {
        groupId = await messaging.getOrCreatePeerChat(
          jobId: group.jobId,
          jobTitle: group.jobTitle,
          employerId: employerId,
          memberAId: _currentUid,
          memberBId: member.id,
          parentGroupId: group.groupId,
          excludeGroupId: group.groupId,
        );
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            groupId: groupId,
            isEmployer: _currentUid == employerId,
          ),
        ),
      );
    } catch (e) {
      Get.snackbar(
        'Không mở được chat',
        e.toString().replaceFirst('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nick = group.nicknames[member.id];
    final displayName = '${member.firstName} ${member.lastName}'.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: _accent.withOpacity(0.15),
          child: Text(
            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _accent,
              fontSize: 18,
            ),
          ),
        ),
        title: Text(
          nick != null && nick.isNotEmpty ? nick : displayName,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (nick != null && nick.isNotEmpty)
                Text(
                  displayName,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              if (nick != null && nick.isNotEmpty) const SizedBox(height: 4),
              _MemberRoleChip(isAdmin: _isAdmin, accent: _accent),
            ],
          ),
        ),
        trailing: !_canDirectChat
            ? null
            : IconButton(
                icon: _openingChat
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: _chatIconColor,
                        size: 22,
                      ),
                tooltip: 'Nhắn tin riêng',
                onPressed: _openingChat ? null : _openDirectChat,
              ),
      ),
    );
  }
}

class _MemberRoleChip extends StatelessWidget {
  final bool isAdmin;
  final Color accent;
  const _MemberRoleChip({required this.isAdmin, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isAdmin ? accent.withOpacity(0.12) : const Color(0xFFE8EAF0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAdmin ? accent.withOpacity(0.35) : const Color(0xFFCFD4DC),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAdmin
                ? Icons.admin_panel_settings_outlined
                : Icons.person_outline,
            size: 13,
            color: isAdmin ? accent : const Color(0xFF607080),
          ),
          const SizedBox(width: 4),
          Text(
            isAdmin ? 'Quản trị viên' : 'Thành viên',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isAdmin ? accent : const Color(0xFF607080),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NicknamesScreen — Đặt biệt danh
// ─────────────────────────────────────────────────────────────────────────────
class _NicknamesScreen extends StatefulWidget {
  final GroupChatModel group;
  final bool isCandidateTheme;
  const _NicknamesScreen({required this.group, this.isCandidateTheme = false});

  @override
  State<_NicknamesScreen> createState() => _NicknamesScreenState();
}

class _NicknamesScreenState extends State<_NicknamesScreen> {
  final _service = GroupChatService();
  List<UserModel>? _members;
  bool _loading = true;

  Color get _accent => widget.isCandidateTheme
      ? AppColors.candidatePrimary
      : AppColors.employerPrimary;

  LinearGradient get _headerGradient => widget.isCandidateTheme
      ? AppColors.candidateGradient
      : AppColors.employerGradient;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final members = await _service.getGroupMembers(widget.group.memberIds);
    if (mounted)
      setState(() {
        _members = members;
        _loading = false;
      });
  }

  void _editNickname(BuildContext context, UserModel user, String currentNick) {
    final ctrl = TextEditingController(text: currentNick);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Biệt danh cho\n${user.firstName} ${user.lastName}'.trim(),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nhập biệt danh (bỏ trống để xóa)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              final nick = ctrl.text.trim();
              final displayName = '${user.firstName} ${user.lastName}'.trim();
              final auth = Get.find<AuthController>();
              final cu = auth.currentUser;
              var setterName = '${cu?.firstName ?? ''} ${cu?.lastName ?? ''}'
                  .trim();
              if (setterName.isEmpty) {
                setterName = (cu?.companyName ?? '').trim();
              }
              if (setterName.isEmpty) {
                setterName = cu?.role == 'employer'
                    ? 'Nhà tuyển dụng'
                    : 'Thành viên';
              }
              await _service.setNickname(
                widget.group.groupId,
                user.id,
                nick,
                memberDisplayName: displayName.isNotEmpty
                    ? displayName
                    : 'Thành viên',
                setterDisplayName: setterName,
              );
              Get.back();
              Get.snackbar(
                'Đã lưu',
                'Biệt danh đã cập nhật — mọi người sẽ thấy trong khung chat',
                snackPosition: SnackPosition.BOTTOM,
              );
            },
            child: const Text('Lưu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GroupChatModel?>(
      stream: _service.streamGroup(widget.group.groupId),
      builder: (context, snap) {
        final liveGroup = snap.data ?? widget.group;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: _accent,
            flexibleSpace: Container(
              decoration: BoxDecoration(gradient: _headerGradient),
            ),
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Đặt biệt danh',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: _loading
              ? Center(child: CircularProgressIndicator(color: _accent))
              : _members == null || _members!.isEmpty
              ? Center(
                  child: Text(
                    'Chưa có thành viên',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _members!.length,
                  itemBuilder: (_, i) {
                    final member = _members![i];
                    final nick = liveGroup.nicknames[member.id] ?? '';
                    final displayName = '${member.firstName} ${member.lastName}'
                        .trim();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: _accent.withOpacity(0.15),
                          child: Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _accent,
                            ),
                          ),
                        ),
                        title: Text(
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: nick.isNotEmpty
                            ? Row(
                                children: [
                                  Icon(
                                    Icons.label_outline,
                                    size: 13,
                                    color: _accent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    nick,
                                    style: TextStyle(
                                      color: _accent,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                'Chưa đặt biệt danh',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                ),
                              ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.edit_rounded,
                            color: _accent,
                            size: 20,
                          ),
                          onPressed: () => _editNickname(context, member, nick),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _Tool {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;
  const _Tool({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });
}

class _ToolCell extends StatelessWidget {
  const _ToolCell({required this.tool});
  final _Tool tool;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: tool.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              gradient: tool.gradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: tool.gradient.colors.first.withOpacity(0.38),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(tool.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            tool.label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF212121),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.items});
  final List<_FeatureItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: items),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.titleColor,
    this.isLast = false,
  });

  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? titleColor;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: iconBg.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: titleColor ?? const Color(0xFF212121),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                trailing ??
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey.shade400,
                      size: 22,
                    ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 76,
            endIndent: 16,
            color: Colors.grey.shade100,
          ),
      ],
    );
  }
}
