import 'package:flutter/material.dart';

/// Màn hiển thị nội dung văn bản (hướng dẫn, chính sách).
class SettingsTextScreen extends StatelessWidget {
  const SettingsTextScreen({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF666666)),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF222222),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Text(
          body.trim(),
          style: const TextStyle(
            fontSize: 15,
            height: 1.55,
            color: Color(0xFF333333),
          ),
        ),
      ),
    );
  }
}
