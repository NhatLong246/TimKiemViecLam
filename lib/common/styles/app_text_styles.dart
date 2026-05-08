import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyle {
  static TextStyle title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.dark,
  );
  static TextStyle subtitle = TextStyle(fontSize: 14, color: AppColors.grey);
  static TextStyle whiteTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );
  static TextStyle whiteSubtitle = TextStyle(
    fontSize: 14,
    color: Colors.white70,
  );
}
