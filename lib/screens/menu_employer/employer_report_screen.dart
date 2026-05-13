import 'package:flutter/material.dart';
import '_employer_tool_placeholder.dart';

class EmployerReportScreen extends StatelessWidget {
  const EmployerReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmployerToolPlaceholder(
      title: 'Báo cáo',
      subtitle: 'Xem báo cáo tuyển dụng và chi phí',
      icon: Icons.bar_chart_rounded,
      iconColor: Color(0xFF2E7D32),
      gradient: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
    );
  }
}
