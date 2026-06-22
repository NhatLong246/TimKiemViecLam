import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../common/styles/app_colors.dart';
import '../../controller/messaging_controller.dart';
import '../../controller/group_chat_controller.dart';
import 'chat_room_screen.dart';
import 'dart:convert';

class ChatHistoryScreen extends StatelessWidget {
  final bool isEmployer;
  
  const ChatHistoryScreen({super.key, required this.isEmployer});

  @override
  Widget build(BuildContext context) {
    if (isEmployer) {
      Get.put(GroupChatController());
    } else {
      Get.put(MessagingController());
    }

    return Scaffold(
      backgroundColor: isEmployer ? Colors.white : const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: isEmployer ? AppColors.employerPrimary : const Color(0xFF2E7D32),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: isEmployer ? AppColors.employerGradient : const LinearGradient(
              colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)],
            ),
          ),
        ),
        title: const Text(
          'Lịch sử nhóm chat',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isEmployer ? _buildEmployerList(context) : _buildCandidateList(context),
    );
  }

  Widget _buildEmployerList(BuildContext context) {
    final ctrl = Get.find<GroupChatController>();
    return Obx(() {
      final historyGroups = ctrl.groups.where((g) => g.isDissolved).toList();
      if (ctrl.isLoadingGroups.value && historyGroups.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (historyGroups.isEmpty) return _buildEmpty();

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: historyGroups.length,
        itemBuilder: (_, i) {
          final g = historyGroups[i];
          final avatarBytes = g.groupAvatarBase64 != null 
              ? base64Decode(g.groupAvatarBase64!.split(',').last) 
              : null;
          
          return _buildCard(
            context,
            title: g.jobTitle,
            subtitle: '${g.memberIds.length} thành viên',
            time: g.createdAt,
            avatarBytes: avatarBytes,
            isEmployer: true,
            onTap: () {
              ctrl.openGroup(g);
              Get.to(() => ChatRoomScreen(
                groupId: g.groupId,
                isEmployer: true,
              ));
            },
          );
        },
      );
    });
  }

  Widget _buildCandidateList(BuildContext context) {
    final ctrl = Get.find<MessagingController>();
    return Obx(() {
      final historyGroups = ctrl.conversations
          .where((c) => c.isGroupChat && c.isClosed)
          .toList();
          
      if (ctrl.isLoading.value && historyGroups.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (historyGroups.isEmpty) return _buildEmpty();

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: historyGroups.length,
        itemBuilder: (_, i) {
          final c = historyGroups[i];
          final avatarBytes = c.groupAvatarBase64 != null 
              ? base64Decode(c.groupAvatarBase64!.split(',').last) 
              : null;
          
          return _buildCard(
            context,
            title: c.jobTitle,
            subtitle: c.lastMessageText ?? 'Nhóm đã kết thúc',
            time: c.lastMessageAt ?? DateTime.now(),
            avatarBytes: avatarBytes,
            isEmployer: false,
            onTap: () async {
              await ctrl.markConversationRead(c.groupId);
              Get.to(() => ChatRoomScreen(
                groupId: c.groupId,
                isEmployer: false,
              ));
            },
          );
        },
      );
    });
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_toggle_off, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Chưa có lịch sử nhóm chat',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Các nhóm chat đã kết thúc sẽ xuất hiện ở đây.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required DateTime time,
    required dynamic avatarBytes,
    required bool isEmployer,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isEmployer ? AppColors.employerPrimary.withOpacity(0.1) : const Color(0xFF2E7D32).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: avatarBytes != null
                    ? Image.memory(avatarBytes, fit: BoxFit.cover)
                    : Icon(Icons.group, color: isEmployer ? AppColors.employerPrimary : const Color(0xFF2E7D32)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Kết thúc',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateFormat('dd/MM').format(time),
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 6),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
