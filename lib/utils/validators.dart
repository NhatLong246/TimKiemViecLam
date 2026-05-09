class Validators {
  /// Họ / Tên: không được chứa số, ít nhất 2 ký tự
  static String? validateName(String value, String fieldName) {
    if (value.trim().isEmpty) return '$fieldName không được để trống';
    if (RegExp(r'[0-9]').hasMatch(value)) return '$fieldName không được chứa số';
    if (value.trim().length < 2) return '$fieldName phải có ít nhất 2 ký tự';
    return null;
  }

  /// Số điện thoại: 10–12 số, bắt đầu bằng 0
  static String? validatePhone(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty) return 'Số điện thoại không được để trống';
    if (!RegExp(r'^0[0-9]{9,11}$').hasMatch(cleaned)) {
      return 'Số điện thoại phải 10–12 số và bắt đầu bằng số 0';
    }
    return null;
  }

  /// Email: đúng định dạng chuẩn
  static String? validateEmail(String value) {
    if (value.trim().isEmpty) return 'Email không được để trống';
    if (!RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
        .hasMatch(value.trim())) {
      return 'Email không đúng định dạng (vd: ten@gmail.com)';
    }
    return null;
  }

  /// Mật khẩu: ít nhất 6 ký tự
  static String? validatePassword(String value) {
    if (value.isEmpty) return 'Mật khẩu không được để trống';
    if (value.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
    return null;
  }

  /// Tên đăng nhập: chữ cái, số, dấu _, ít nhất 3 ký tự
  static String? validateUsername(String value) {
    if (value.trim().isEmpty) return 'Tên đăng nhập không được để trống';
    if (value.trim().length < 3) return 'Tên đăng nhập phải có ít nhất 3 ký tự';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
      return 'Tên đăng nhập chỉ gồm chữ cái, số và dấu _';
    }
    return null;
  }

  static String? validateRequired(String value, String fieldName) {
    if (value.trim().isEmpty) return '$fieldName không được để trống';
    return null;
  }
}
