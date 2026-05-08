class Validators {
  static String? validateEmail(String value) {
    if (value.isEmpty) {
      return 'Email không được để trống';
    }
    if (!value.contains('@')) {
      return 'Email không hợp lệ';
    }
    return null;
  }

  static String? validatePassword(String value) {
    if (value.isEmpty) {
      return 'Password không được để trống';
    }
    if (value.length < 6) {
      return 'Password phải >= 6 ký tự';
    }
    return null;
  }

  static String? validateRequired(String value, String fieldName) {
    if (value.isEmpty) {
      return '$fieldName không được để trống';
    }
    return null;
  }

  static String? validatePhone(String value) {
    if (value.isEmpty) {
      return 'Số điện thoại không được để trống';
    }
    if (value.length < 9) {
      return 'Số điện thoại không hợp lệ';
    }
    return null;
  }
}
