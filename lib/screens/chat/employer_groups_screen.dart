import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../common/styles/app_colors.dart';
import '../../controller/group_chat_controller.dart';
import '../../data/models/group_chat_model.dart';
import '../../data/services/group_chat_service.dart';
import '../messaging/chat_room_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EmployerGroupsScreen — danh sách nhóm chat theo job
// ─────────────────────────────────────────────────────────────────────────────
class EmployerGroupsScreen extends StatelessWidget {
  const EmployerGroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(GroupChatController());

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildAppBar()],
        body: Obx(() {
          if (ctrl.isLoadingGroups.value) {
            return const Center(child: CircularProgressIndicator());
          }
          if (ctrl.groups.isEmpty) {
            return _buildEmpty();
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: ctrl.groups.length,
            itemBuilder: (_, i) {
              final g = ctrl.groups[i];
              return _GroupCard(
                key: ValueKey(g.groupId),
                group: g,
                onTap: () {
                  ctrl.openGroup(g);
                  Get.to(
                    () => ChatRoomScreen(
                      groupId: g.groupId,
                      isEmployer: true,
                    ),
                  );
                },
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 0,
      backgroundColor: AppColors.employerPrimary,
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: AppColors.employerGradient),
      ),
      title: const Text(
        'Nhóm làm việc',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group_outlined, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Chưa có nhóm nào',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Nhóm chat được tạo tự động\nkhi bạn duyệt ứng viên',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

// ─── Card cho mỗi nhóm ────────────────────────────────────────────────────────
// StatefulWidget để cache stream — tránh tạo mới stream mỗi lần Obx rebuild
class _GroupCard extends StatefulWidget {
  const _GroupCard({
    super.key,
    required this.group,
    required this.onTap,
  });

  final GroupChatModel group;
  final VoidCallback onTap;

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  late GroupChatModel _group;
  StreamSubscription<GroupChatModel?>? _sub;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    final svc = GroupChatService();
    // Fetch ngay lập tức để lấy data mới nhất (kể cả avatar)
    svc.getGroup(widget.group.groupId).then((latest) {
      if (latest != null && mounted) setState(() => _group = latest);
    });
    // Tiếp tục stream để nhận cập nhật realtime
    _sub = svc.streamGroup(widget.group.groupId).listen((updated) {
      if (updated != null && mounted) setState(() => _group = updated);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = _group;
    return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppColors.employerGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _AvatarImage(
                        base64: g.groupAvatarBase64,
                        iconSize: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.jobTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.people_outline,
                                size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              '${g.memberIds.length} thành viên',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat('dd/MM').format(g.createdAt),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 6),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

// ─── Widget hiển thị ảnh base64 an toàn ─────────────────────────────────────
class _AvatarImage extends StatelessWidget {
  final String? base64;
  final double iconSize;

  const _AvatarImage({required this.base64, required this.iconSize});

  @override
  Widget build(BuildContext context) {
    final bytes = _tryDecode(base64);
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _icon(),
      );
    }
    return _icon();
  }

  static Uint8List? _tryDecode(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try {
      // Xử lý cả Data URI (data:image/...;base64,...)
      final data = b64.contains(',') ? b64.split(',').last : b64;
      return base64Decode(data.trim());
    } catch (_) {
      return null;
    }
  }

  Widget _icon() => Icon(Icons.group, color: Colors.white, size: iconSize);
}
