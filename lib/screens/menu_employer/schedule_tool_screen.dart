import 'package:flutter/material.dart';
import '_employer_tool_placeholder.dart';

class ScheduleToolScreen extends StatelessWidget {
  const ScheduleToolScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmployerToolPlaceholder(
      title: 'Công cụ tạo lịch',
      subtitle: 'Tạo và phân công ca làm việc',
      icon: Icons.calendar_month_outlined,
      iconColor: Color(0xFF0277BD),
      gradient: [Color(0xFF0277BD), Color(0xFF01579B)],
    );
  }
}
