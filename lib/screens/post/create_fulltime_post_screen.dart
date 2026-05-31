import 'package:flutter/material.dart';

import 'create_post_screen.dart';

/// Màn tạo / sửa bài đăng Full-time (tách khỏi Part-time).
class CreateFulltimePostScreen extends StatelessWidget {
  const CreateFulltimePostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CreatePostScreen(initialJobType: 'full_time');
  }
}
