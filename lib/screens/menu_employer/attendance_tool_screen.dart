import 'package:flutter/material.dart';
import '_employer_tool_placeholder.dart';

class AttendanceToolScreen extends StatelessWidget {
  const AttendanceToolScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmployerToolPlaceholder(
      title: 'Công cụ điểm danh',
      subtitle: 'Theo dõi chuyên cần từng ca làm',
      icon: Icons.how_to_reg_outlined,
      iconColor: Color(0xFF7B1FA2),
      gradient: [Color(0xFF7B1FA2), Color(0xFF4A148C)],
    );
  }
}
