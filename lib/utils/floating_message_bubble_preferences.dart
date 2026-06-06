import 'package:shared_preferences/shared_preferences.dart';

/// Lưu trạng thái kéo ẩn overlay nổi.
class FloatingMessageBubblePreferences {
  static String _msgHiddenKey(String userId, bool isEmployer) =>
      'floating_msg_bubble_hidden_${userId}_${isEmployer ? 'employer' : 'candidate'}';

  static String _msgHiddenUnreadKey(String userId, bool isEmployer) =>
      'floating_msg_bubble_hidden_unread_${userId}_${isEmployer ? 'employer' : 'candidate'}';

  static String _msgHiddenLastAtKey(String userId, bool isEmployer) =>
      'floating_msg_bubble_hidden_last_at_${userId}_${isEmployer ? 'employer' : 'candidate'}';

  static Future<({bool hidden, int hiddenWhileUnread, int? lastMessageAtMs})> loadMessageBubble(
    String userId,
    bool isEmployer,
  ) async {
    if (userId.isEmpty) return (hidden: false, hiddenWhileUnread: 0, lastMessageAtMs: null);
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_msgHiddenLastAtKey(userId, isEmployer));
    return (
      hidden: prefs.getBool(_msgHiddenKey(userId, isEmployer)) ?? false,
      hiddenWhileUnread: prefs.getInt(_msgHiddenUnreadKey(userId, isEmployer)) ?? 0,
      lastMessageAtMs: ms,
    );
  }

  static Future<void> saveMessageBubbleDismissed(
    String userId,
    bool isEmployer, {
    required int unreadAtDismiss,
    int? lastMessageAtMs,
  }) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_msgHiddenKey(userId, isEmployer), true);
    await prefs.setInt(_msgHiddenUnreadKey(userId, isEmployer), unreadAtDismiss);
    if (lastMessageAtMs != null) {
      await prefs.setInt(_msgHiddenLastAtKey(userId, isEmployer), lastMessageAtMs);
    } else {
      await prefs.remove(_msgHiddenLastAtKey(userId, isEmployer));
    }
  }

  static Future<void> clearMessageBubbleDismissed(
    String userId,
    bool isEmployer,
  ) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_msgHiddenKey(userId, isEmployer));
    await prefs.remove(_msgHiddenUnreadKey(userId, isEmployer));
    await prefs.remove(_msgHiddenLastAtKey(userId, isEmployer));
  }

  static String _chatbotHiddenKey(String userId) =>
      'floating_chatbot_hidden_$userId';

  static Future<bool> loadChatbotHidden(String userId) async {
    if (userId.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_chatbotHiddenKey(userId)) ?? false;
  }

  static Future<void> saveChatbotDismissed(String userId) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chatbotHiddenKey(userId), true);
  }

  static Future<void> clearChatbotDismissed(String userId) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chatbotHiddenKey(userId));
  }
}
