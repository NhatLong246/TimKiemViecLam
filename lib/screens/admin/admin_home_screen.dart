import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_routes.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF37474F),
        foregroundColor: Colors.white,
        title: const Text('Admin'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            icon: Icons.payments_outlined,
            title: 'Duyệt giải ngân',
            subtitle: 'NTD chỉ giải ngân sau khi bạn cho phép',
            onTap: () => Get.toNamed(AppRoutes.adminDisbursements),
          ),
          const SizedBox(height: 12),
          _card(
            icon: Icons.gavel_outlined,
            title: 'Danh mục khiếu nại',
            subtitle: 'Khiếu nại NV, khiếu nại công việc',
            onTap: () => Get.toNamed(AppRoutes.complaintsCatalog),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF37474F).withValues(alpha: 0.12),
          child: Icon(icon, color: const Color(0xFF37474F)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
