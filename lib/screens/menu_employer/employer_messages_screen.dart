import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '_employer_tool_placeholder.dart';

class EmployerMessagesScreen extends StatelessWidget {
  const EmployerMessagesScreen({super.key});

  static const _gradient = [Color(0xFF1565C0), Color(0xFF7B1FA2)];

  @override
  Widget build(BuildContext context) {
    return EmployerToolPlaceholder(
      title: 'Tin nhắn việc làm',
      subtitle: 'Quản lý nhóm chat và trao đổi công việc',
      icon: Icons.chat_bubble_outline_rounded,
      iconColor: const Color(0xFF1565C0),
      gradient: _gradient,
    );
  }
}
