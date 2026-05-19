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
import '../../routes/app_routes.dart';

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
  final _service = GroupChatService();
  final _auth = Get.find<AuthController>();
  bool _isUploadingAvatar = false;
  bool _togglingMute = false;

  @override
  void initState() {
    super.initState();
    _initGroup = Get.arguments as GroupChatModel;
  }

  String get _currentUserId => _auth.currentUser?.id ?? '';

  // ── Thay ảnh đại diện nhóm ────────────────────────────────────────────────
  Future<void> _changeAvatar(GroupChatModel group) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                    borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: Color(0xFF7B1FA2)),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library_rounded, color: Color(0xFF1565C0)),
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
      Get.snackbar('Ảnh quá lớn', 'Vui lòng chọn ảnh nhỏ hơn 500KB',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _isUploadingAvatar = true);
    try {
      final b64 = base64Encode(bytes);
      await _service.updateGroupAvatar(group.groupId, b64);
      Get.snackbar('Thành công', 'Đã cập nhật ảnh nhóm',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể cập nhật ảnh nhóm',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  // ── Mở trang thành viên ──────────────────────────────────────────────────
  void _openMembers(GroupChatModel group) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => _MembersScreen(group: group),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position:
              Tween(begin: const Offset(1, 0), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
    );
  }

  // ── Mở biệt danh ────────────────────────────────────────────────────────
  void _openNicknames(GroupChatModel group) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => _NicknamesScreen(group: group),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position:
              Tween(begin: const Offset(1, 0), end: Offset.zero).animate(anim),
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
      backgroundColor: AppColors.employerPrimary,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF6A0DAD),
                Color(0xFF7B1FA2),
                Color(0xFF1565C0),
                Color(0xFF0D47A1),
              ],
              stops: [0.0, 0.35, 0.70, 1.0],
            ),
          ),
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
                                  ? const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFFCE93D8),
                                        Color(0xFF7B1FA2)
                                      ],
                                    )
                                  : null,
                              border:
                                  Border.all(color: Colors.white, width: 3),
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
                                ? const Icon(Icons.group,
                                    color: Colors.white, size: 40)
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
                                        blurRadius: 6),
                                  ],
                                ),
                                child: _isUploadingAvatar
                                    ? const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF7B1FA2)))
                                    : const Icon(Icons.camera_alt_rounded,
                                        size: 16, color: Color(0xFF7B1FA2)),
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
                          const Icon(Icons.people_alt_outlined,
                              color: Colors.white70, size: 15),
                          const SizedBox(width: 5),
                          Text(
                            '${group.memberIds.length} thành viên',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
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
        icon: const Icon(Icons.arrow_back_ios_new,
            color: Colors.white, size: 20),
        onPressed: () => Get.back(),
      ),
      title: const Text(
        'Quản lý nhóm',
        style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
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
            end: Alignment.bottomRight),
        onTap: () => _openMembers(group),
      ),
      _Tool(
        icon: Icons.badge_rounded,
        label: 'Biệt danh',
        gradient: const LinearGradient(
            colors: [Color(0xFF7B1FA2), Color(0xFFCE93D8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        onTap: () => _openNicknames(group),
      ),
      _Tool(
        icon: Icons.fact_check_rounded,
        label: 'Điểm danh',
        gradient: const LinearGradient(
            colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        onTap: () => Get.toNamed(
          AppRoutes.attendance,
          arguments: {
            'groupId': group.groupId,
            'jobId': group.jobId,
            'jobTitle': group.jobTitle,
            'memberIds': group.memberIds,
          },
        ),
      ),
      _Tool(
        icon: Icons.calendar_month_rounded,
        label: 'Lịch làm việc',
        gradient: const LinearGradient(
            colors: [Color(0xFFE65100), Color(0xFFFFB74D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        onTap: () => Get.toNamed(AppRoutes.workSchedule, arguments: group),
      ),
      _Tool(
        icon: Icons.report_problem_rounded,
        label: 'Khiếu nại',
        gradient: const LinearGradient(
            colors: [Color(0xFFC62828), Color(0xFFEF9A9A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        onTap: () => Get.toNamed(AppRoutes.complaint, arguments: group),
      ),
      _Tool(
        icon: Icons.search_rounded,
        label: 'Tìm tin nhắn',
        gradient: const LinearGradient(
            colors: [Color(0xFF00695C), Color(0xFF4DB6AC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        onTap: () => _openSearch(group),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4)),
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
    try {
      await _service.toggleMute(group.groupId, _currentUserId, isMuted);
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
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Switch(
                  value: !isMuted,
                  onChanged: (_) => _toggleMute(group),
                  activeColor: AppColors.employerPrimary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
          onTap: () => _toggleMute(group),
        ),
        _FeatureItem(
          icon: Icons.edit_outlined,
          iconBg: const Color(0xFF6A1B9A),
          title: 'Đổi tên nhóm',
          subtitle: group.jobTitle,
          onTap: () => _renameGroup(group),
        ),
        _FeatureItem(
          icon: Icons.delete_forever_outlined,
          iconBg: const Color(0xFFC62828),
          title: 'Giải tán nhóm',
          subtitle: 'Xóa nhóm và toàn bộ dữ liệu',
          titleColor: const Color(0xFFC62828),
          onTap: () => _confirmDisband(group),
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
        title: const Row(
          children: [
            Icon(Icons.edit_rounded, color: Color(0xFF6A1B9A), size: 22),
            SizedBox(width: 8),
            Text('Đổi tên nhóm',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
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
                borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        actions: [
          TextButton(
              onPressed: Get.back,
              child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.employerPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            icon: const Icon(Icons.check_rounded,
                color: Colors.white, size: 18),
            label: const Text('Lưu',
                style: TextStyle(color: Colors.white)),
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
              Get.snackbar('Đổi tên thành công', 'Tên nhóm: $name',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                  duration: const Duration(seconds: 2));
            },
          ),
        ],
      ),
    );
  }

  void _confirmDisband(GroupChatModel group) {
    final confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFC62828), size: 26),
              SizedBox(width: 8),
              Text('Giải tán nhóm',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFC62828),
                      fontSize: 17)),
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
              const Text('Gõ "GIẢI TÁN" để xác nhận:',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
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
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: Get.back,
                child: const Text('Hủy',
                    style: TextStyle(color: Colors.grey))),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      confirmCtrl.text.trim() == 'GIẢI TÁN'
                          ? const Color(0xFFC62828)
                          : Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              icon: Icon(Icons.delete_forever_rounded,
                  color: confirmCtrl.text.trim() == 'GIẢI TÁN'
                      ? Colors.white
                      : Colors.grey.shade500,
                  size: 18),
              label: Text('Giải tán',
                  style: TextStyle(
                      color: confirmCtrl.text.trim() == 'GIẢI TÁN'
                          ? Colors.white
                          : Colors.grey.shade500)),
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
                                borderRadius:
                                    BorderRadius.all(Radius.circular(16))),
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
                        Get.snackbar('Lỗi', 'Không thể giải tán nhóm: $e',
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                            snackPosition: SnackPosition.BOTTOM);
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
  const _MembersScreen({required this.group});

  @override
  State<_MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<_MembersScreen> {
  final _service = GroupChatService();
  List<UserModel>? _members;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final members =
        await _service.getGroupMembers(widget.group.memberIds);
    if (mounted) setState(() { _members = members; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.employerPrimary,
        flexibleSpace: Container(
            decoration:
                const BoxDecoration(gradient: AppColors.employerGradient)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Thành viên (${widget.group.memberIds.length})',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      backgroundColor: const Color(0xFFF2F4F8),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _members == null || _members!.isEmpty
              ? Center(
                  child: Text('Chưa có thành viên',
                      style: TextStyle(color: Colors.grey.shade500)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _members!.length,
                  itemBuilder: (_, i) =>
                      _MemberCard(member: _members![i], group: widget.group),
                ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final UserModel member;
  final GroupChatModel group;
  const _MemberCard({required this.member, required this.group});

  @override
  Widget build(BuildContext context) {
    final nick = group.nicknames[member.id];
    final displayName =
        '${member.firstName} ${member.lastName}'.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor:
              AppColors.employerPrimary.withOpacity(0.15),
          child: Text(
            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.employerPrimary,
                fontSize: 18),
          ),
        ),
        title: Text(
          nick != null && nick.isNotEmpty ? nick : displayName,
          style: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: nick != null && nick.isNotEmpty
            ? Text(displayName,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade500))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded,
                  color: Color(0xFF1565C0), size: 22),
              tooltip: 'Chat cá nhân',
              onPressed: () {
                // TODO: Chuyển đến chat cá nhân khi implement
                Get.snackbar(
                  'Chat cá nhân',
                  'Tính năng đang phát triển',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 2),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NicknamesScreen — Đặt biệt danh
// ─────────────────────────────────────────────────────────────────────────────
class _NicknamesScreen extends StatefulWidget {
  final GroupChatModel group;
  const _NicknamesScreen({required this.group});

  @override
  State<_NicknamesScreen> createState() => _NicknamesScreenState();
}

class _NicknamesScreenState extends State<_NicknamesScreen> {
  final _service = GroupChatService();
  List<UserModel>? _members;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final members =
        await _service.getGroupMembers(widget.group.memberIds);
    if (mounted) setState(() { _members = members; _loading = false; });
  }

  void _editNickname(BuildContext context, UserModel user,
      String currentNick) {
    final ctrl = TextEditingController(text: currentNick);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Biệt danh cho\n${user.firstName} ${user.lastName}'.trim(),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nhập biệt danh (bỏ trống để xóa)',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: Get.back,
              child: const Text('Hủy',
                  style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B1FA2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              final nick = ctrl.text.trim();
              await _service.setNickname(
                  widget.group.groupId, user.id, nick);
              Get.back();
              Get.snackbar('Đã lưu', 'Biệt danh đã cập nhật',
                  snackPosition: SnackPosition.BOTTOM);
            },
            child: const Text('Lưu',
                style: TextStyle(color: Colors.white)),
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
            backgroundColor: AppColors.employerPrimary,
            flexibleSpace: Container(
                decoration: const BoxDecoration(
                    gradient: AppColors.employerGradient)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Đặt biệt danh',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          backgroundColor: const Color(0xFFF2F4F8),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _members == null || _members!.isEmpty
                  ? Center(
                      child: Text('Chưa có thành viên',
                          style:
                              TextStyle(color: Colors.grey.shade500)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _members!.length,
                      itemBuilder: (_, i) {
                        final member = _members![i];
                        final nick =
                            liveGroup.nicknames[member.id] ?? '';
                        final displayName =
                            '${member.firstName} ${member.lastName}'
                                .trim();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2))
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.employerPrimary
                                  .withOpacity(0.15),
                              child: Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.employerPrimary),
                              ),
                            ),
                            title: Text(displayName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            subtitle: nick.isNotEmpty
                                ? Row(children: [
                                    const Icon(Icons.label_outline,
                                        size: 13,
                                        color: Color(0xFF7B1FA2)),
                                    const SizedBox(width: 4),
                                    Text(nick,
                                        style: const TextStyle(
                                            color: Color(0xFF7B1FA2),
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic)),
                                  ])
                                : Text('Chưa đặt biệt danh',
                                    style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 12)),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit_rounded,
                                  color: Color(0xFF7B1FA2), size: 20),
                              onPressed: () =>
                                  _editNickname(context, member, nick),
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
  const _Tool(
      {required this.icon,
      required this.label,
      required this.gradient,
      required this.onTap});
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
                    offset: const Offset(0, 5)),
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
                color: Color(0xFF212121)),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4)),
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
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: titleColor ?? const Color(0xFF212121))),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                trailing ??
                    Icon(Icons.chevron_right_rounded,
                        color: Colors.grey.shade400, size: 22),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
              height: 1,
              indent: 76,
              endIndent: 16,
              color: Colors.grey.shade100),
      ],
    );
  }
}

