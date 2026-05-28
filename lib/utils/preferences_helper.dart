import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Mốc "đã đọc tới" từng phòng chat — giữ sau restart nếu Firestore chậm/lỗi.
class ChatReadPreferences {
  ChatReadPreferences._();

  /// Bù lastMessageAt server nhanh hơn giờ máy một chút (không chặn tin mới).
  static const Duration clockSkew = Duration(seconds: 90);

  static String _key(String uid) => 'chat_read_watermarks_$uid';
  static String _msgBaselineKey(String uid) => 'msg_notif_baseline_$uid';

  static bool _isValidWatermarkMs(int ms) {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Bỏ mốc lưu nhầm tương lai — không thay bằng "now" (sẽ chặn mọi tin mới).
    return ms <= now + clockSkew.inMilliseconds;
  }

  static Future<Map<String, int>> getAll(String uid) async {
    if (uid.isEmpty) return {};
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(uid));
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, int>{};
      for (final e in decoded.entries) {
        final ms = (e.value as num).toInt();
        if (_isValidWatermarkMs(ms)) {
          out[e.key.toString()] = ms;
        }
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  static Future<void> markRead(
    String uid,
    String groupId,
    DateTime at,
  ) async {
    if (uid.isEmpty || groupId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final all = await getAll(uid);
    final ms = at.millisecondsSinceEpoch;
    final prev = all[groupId];
    if (prev != null && prev >= ms) return;
    all[groupId] = ms;
    await prefs.setString(_key(uid), jsonEncode(all));
  }

  /// Ẩn thông báo tin nhắn trên chuông đã có trước lúc đọc.
  static Future<void> setMessageNotifBaseline(String uid) async {
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _msgBaselineKey(uid),
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<int?> messageNotifBaselineMs(String uid) async {
    if (uid.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_msgBaselineKey(uid));
    if (ms == null || !_isValidWatermarkMs(ms)) return null;
    return ms;
  }

  static Future<void> clearUser(String uid) async {
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(uid));
    await prefs.remove(_msgBaselineKey(uid));
  }

  /// Tin đã đọc nếu không mới hơn mốc đọc (cộng skew nhỏ cho lệch giờ).
  static bool isReadUpTo({
    required Map<String, int> watermarks,
    required String groupId,
    required DateTime? lastMessageAt,
  }) {
    final wm = watermarks[groupId];
    if (wm == null) return false;
    if (lastMessageAt == null) return true;
    final cutoff = wm + clockSkew.inMilliseconds;
    return lastMessageAt.millisecondsSinceEpoch <= cutoff;
  }

  /// Chỉ ẩn notif tạo trước / đúng lúc đọc — tin sau đó vẫn hiện badge.
  static bool isMessageNotifCleared({
    required int? baselineMs,
    required DateTime createdAt,
  }) {
    if (baselineMs == null) return false;
    final cutoff = baselineMs + clockSkew.inMilliseconds;
    return createdAt.millisecondsSinceEpoch <= cutoff;
  }
}

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
