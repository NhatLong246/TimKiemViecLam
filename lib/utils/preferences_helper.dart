import 'package:shared_preferences/shared_preferences.dart';

class PreferencesHelper {
  static const String rememberMeKey = 'remember_me';
  static const String emailKey = 'saved_email';
  static const String onboardingCompletedKey = 'onboarding_completed';

  static Future<void> saveRememberMe(bool rememberMe, String email) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(rememberMeKey, rememberMe);
    if (rememberMe && email.isNotEmpty) {
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

  static Future<void> setOnboardingCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingCompletedKey, completed);
  }

  static Future<bool> getOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(onboardingCompletedKey) ?? false;
  }
}
