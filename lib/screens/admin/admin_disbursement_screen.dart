import 'package:flutter/material.dart';

class AdminDisbursementScreen extends StatelessWidget {
  const AdminDisbursementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF37474F),
        foregroundColor: Colors.white,
        title: const Text('Duyệt giải ngân'),
      ),
      body: const Center(
        child: Text(
          'Tính năng đang được phát triển.\n(Hệ thống hiện tại tự động duyệt để NTD tự xử lý)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
