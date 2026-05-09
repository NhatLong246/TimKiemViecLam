import 'package:flutter/material.dart';

class AppColors {
  // Legacy
  static const Color primaryBlue = Color(0xFF2F80ED);
  static const Color background = Color(0xFFF0F4F8);
  static const Color white = Colors.white;
  static const Color grey = Color(0xFF828282);
  static const Color dark = Color(0xFF333333);

  // Candidate role (xanh lá)
  static const Color candidatePrimary = Color(0xFF2E7D32);
  static const Color candidatePrimaryLight = Color(0xFF4CAF50);
  static const Color candidatePrimaryDark = Color(0xFF1B5E20);

  // Employer / Manager role (tím → xanh dương, trái → phải)
  static const Color employerPrimary = Color(0xFF7B1FA2);
  static const Color employerPrimaryLight = Color(0xFFAB47BC);
  static const Color employerSecondary = Color(0xFF1565C0);
  static const Color employerSecondaryLight = Color(0xFF42A5F5);

  // Gradient helpers
  static const LinearGradient candidateGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF4CAF50)],
  );

  static const LinearGradient employerGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF7B1FA2), Color(0xFF1565C0)],
  );
}
