import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../common/styles/app_colors.dart';
import '../../controller/group_chat_controller.dart';
import '../../data/models/group_chat_model.dart';
import '../../routes/app_routes.dart';
import '../messaging/conversation_list_screen.dart';

class EmployerMessagesScreen extends StatelessWidget {
  const EmployerMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F4F8),
        appBar: AppBar(
          backgroundColor: AppColors.employerPrimary,
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppColors.employerGradient),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20),
            onPressed: () => Get.back(),
          ),
          title: const Text(
            'Message',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            indicator: const UnderlineTabIndicator(
              borderSide: BorderSide(color: Colors.white, width: 3),
              insets: EdgeInsets.symmetric(horizontal: 20),
            ),
            tabs: const [
              Tab(text: 'Nhóm chat'),
              Tab(text: 'Chat cá nhân'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _GroupChatTab(),
            ConversationListScreen(isEmployer: true),
          ],
        ),
      ),
    );
  }
}

// ─── Tab 1: Nhóm chat ────────────────────────────────────────────────────────
class _GroupChatTab extends StatelessWidget {
  const _GroupChatTab();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.isRegistered<GroupChatController>()
        ? Get.find<GroupChatController>()
        : Get.put(GroupChatController());

    return Obx(() {
      if (ctrl.isLoadingGroups.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (ctrl.groups.isEmpty) {
        return _buildEmpty();
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: ctrl.groups.length,
        itemBuilder: (_, i) => _GroupChatCard(
          group: ctrl.groups[i],
          onTap: () {
            ctrl.openGroup(ctrl.groups[i]);
            Get.toNamed(AppRoutes.groupChat, arguments: ctrl.groups[i]);
          },
        ),
      );
    });
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
              color: Colors.grey.shade600,
            ),
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

// ─── Card nhóm chat ───────────────────────────────────────────────────────────
class _GroupChatCard extends StatelessWidget {
  const _GroupChatCard({required this.group, required this.onTap});

  final GroupChatModel group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
                child: const Icon(Icons.group, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.jobTitle,
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
                          '${group.memberIds.length} thành viên',
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
                    DateFormat('dd/MM').format(group.createdAt),
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
