class AuthManager {
  static bool _isLoggedIn = false;

  static bool get isLoggedIn {
    return _isLoggedIn;
  }

  static void login() {
    _isLoggedIn = true;
  }

  static void logout() {
    _isLoggedIn = false;
  }
}
