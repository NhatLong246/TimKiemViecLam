import 'package:shared_preferences/shared_preferences.dart';

class PreferencesHelper {
  static const String rememberMeKey = 'remember_me';
  static const String emailKey = 'saved_email';

  static Future<void> saveRememberMe(bool rememberMe, String email) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(rememberMeKey, rememberMe);
    if (rememberMe) {
      await prefs.setString(emailKey, email);
    } else {
      await prefs.remove(emailKey);
    }
  }

  static Future<bool> getRememberMe() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(rememberMeKey) ?? false;
  }

  static Future<String?> getSavedEmail() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(emailKey);
  }
}
