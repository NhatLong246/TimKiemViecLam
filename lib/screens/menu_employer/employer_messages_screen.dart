import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../common/styles/app_colors.dart';
import '../../controller/messaging_controller.dart';
import '../../utils/messaging_bootstrap.dart';
import '../messaging/conversation_list_screen.dart';
import '../messaging/chat_history_screen.dart';

class EmployerMessagesScreen extends StatefulWidget {
  const EmployerMessagesScreen({super.key});

  @override
  State<EmployerMessagesScreen> createState() => _EmployerMessagesScreenState();
}

class _EmployerMessagesScreenState extends State<EmployerMessagesScreen> {
  @override
  void initState() {
    super.initState();
    MessagingBootstrap.startIfLoggedIn();
    MessagingBootstrap.ensureController().loadInbox();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
          title: Obx(() {
            final total = Get.isRegistered<MessagingController>()
                ? Get.find<MessagingController>().unreadTotal.value
                : 0;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Message',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                if (total > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      total > 99 ? '99+' : '$total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            );
          }),
          actions: [
            IconButton(
              icon: const Icon(Icons.history_rounded, color: Colors.white),
              tooltip: 'Lịch sử nhóm chat',
              onPressed: () {
                Get.to(() => const ChatHistoryScreen(isEmployer: true));
              },
            ),
          ],
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
            ConversationListScreen(
              isEmployer: true,
              embedded: true,
              inboxFilter: ConversationInboxFilter.groupsOnly,
            ),
            ConversationListScreen(
              isEmployer: true,
              embedded: true,
              inboxFilter: ConversationInboxFilter.directOnly,
            ),
          ],
        ),
      ),
    );
  }
}
