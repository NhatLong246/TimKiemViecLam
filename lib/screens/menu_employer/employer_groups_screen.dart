import 'package:flutter/material.dart';
import '_employer_tool_placeholder.dart';

class EmployerGroupsScreen extends StatelessWidget {
  const EmployerGroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmployerToolPlaceholder(
      title: 'Nhóm',
      subtitle: 'Quản lý nhóm ứng viên của bạn',
      icon: Icons.group_outlined,
      iconColor: Color(0xFF6A1B9A),
      gradient: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
    );
  }
}
