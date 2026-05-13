import 'package:flutter/material.dart';
import '_employer_tool_placeholder.dart';

class RatingToolScreen extends StatelessWidget {
  const RatingToolScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmployerToolPlaceholder(
      title: 'Công cụ đánh giá',
      subtitle: 'Đánh giá nhân viên sau ca làm',
      icon: Icons.star_border_rounded,
      iconColor: Color(0xFFF57F17),
      gradient: [Color(0xFFF57F17), Color(0xFFE65100)],
    );
  }
}
