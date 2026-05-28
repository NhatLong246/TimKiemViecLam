import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hình nền khung chat — đồng bộ theo nhóm trên Firestore (mọi thành viên thấy giống nhau).
class ChatWallpaperConfig {
  final String? presetId;
  final String? imageBase64;

  const ChatWallpaperConfig({this.presetId, this.imageBase64});

  bool get hasCustomImage =>
      imageBase64 != null && imageBase64!.trim().isNotEmpty;

  bool get usesPreset =>
      !hasCustomImage && presetId != null && presetId!.isNotEmpty;

  bool get isDefault => !hasCustomImage && !usesPreset;

  factory ChatWallpaperConfig.fromGroupFields({
    String? presetId,
    String? imageBase64,
  }) {
    if (imageBase64 != null && imageBase64.trim().isNotEmpty) {
      return ChatWallpaperConfig(imageBase64: imageBase64);
    }
    if (presetId != null &&
        presetId.isNotEmpty &&
        presetId != ChatWallpaperPresets.defaultId) {
      return ChatWallpaperConfig(presetId: presetId);
    }
    return const ChatWallpaperConfig();
  }
}

class ChatWallpaperPreferences {
  /// Đọc hình nền nhóm từ Firestore (ưu tiên).
  static Future<ChatWallpaperConfig> loadForGroup(String groupId) async {
    if (groupId.isEmpty) return const ChatWallpaperConfig();
    try {
      final snap = await FirebaseFirestore.instance
          .collection('groupChats')
          .doc(groupId)
          .get();
      if (!snap.exists) return const ChatWallpaperConfig();
      final wpRaw = snap.data()?['chatWallpaper'] as Map?;
      if (wpRaw == null) return const ChatWallpaperConfig();
      return ChatWallpaperConfig.fromGroupFields(
        presetId: wpRaw['presetId']?.toString(),
        imageBase64: wpRaw['imageBase64']?.toString(),
      );
    } catch (_) {
      return const ChatWallpaperConfig();
    }
  }

  static String _key(String userId, String groupId) =>
      'chat_wallpaper_${userId}_$groupId';

  static Future<ChatWallpaperConfig> load(
    String userId,
    String groupId,
  ) async {
    if (userId.isEmpty || groupId.isEmpty) {
      return const ChatWallpaperConfig();
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId, groupId));
    if (raw == null || raw.isEmpty) return const ChatWallpaperConfig();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return ChatWallpaperConfig(
        presetId: map['preset']?.toString(),
        imageBase64: map['image']?.toString(),
      );
    } catch (_) {
      return const ChatWallpaperConfig();
    }
  }

  static Future<void> savePreset(
    String userId,
    String groupId,
    String presetId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(userId, groupId),
      jsonEncode({'preset': presetId}),
    );
  }

  static Future<void> saveImage(
    String userId,
    String groupId,
    String base64,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(userId, groupId),
      jsonEncode({'image': base64}),
    );
  }

  static Future<void> clear(String userId, String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId, groupId));
  }
}

/// Preset có sẵn (không cần asset).
class ChatWallpaperPresets {
  ChatWallpaperPresets._();

  static const String defaultId = 'default';

  static String labelFor(String presetId) {
    for (final p in items) {
      if (p.id == presetId) return p.label;
    }
    return presetId;
  }

  static const List<({String id, String label})> items = [
    (id: 'default', label: 'Mặc định'),
    (id: 'light', label: 'Sáng'),
    (id: 'cream', label: 'Kem'),
    (id: 'mint', label: 'Xanh mint'),
    (id: 'lime', label: 'Xanh chanh'),
    (id: 'forest', label: 'Rừng xanh'),
    (id: 'teal', label: 'Ngọc lam'),
    (id: 'aqua', label: 'Xanh aqua'),
    (id: 'sky', label: 'Xanh trời'),
    (id: 'ocean', label: 'Biển'),
    (id: 'indigo', label: 'Chàm'),
    (id: 'lavender', label: 'Tím nhạt'),
    (id: 'violet', label: 'Tím'),
    (id: 'grape', label: 'Tím nho'),
    (id: 'rose', label: 'Hồng'),
    (id: 'blush', label: 'Hồng phấn'),
    (id: 'peach', label: 'Đào'),
    (id: 'coral', label: 'San hô'),
    (id: 'sunset', label: 'Hoàng hôn'),
    (id: 'sand', label: 'Cát'),
    (id: 'lemon', label: 'Vàng chanh'),
    (id: 'slate', label: 'Xám xanh'),
    (id: 'mocha', label: 'Cà phê'),
    (id: 'dots', label: 'Chấm bi'),
    (id: 'stripes', label: 'Sọc'),
    (id: 'grid', label: 'Lưới'),
    // Màu tối
    (id: 'charcoal', label: 'Than'),
    (id: 'midnight', label: 'Nửa đêm'),
    (id: 'navy_dark', label: 'Xanh đêm'),
    (id: 'forest_dark', label: 'Rừng tối'),
    (id: 'teal_dark', label: 'Ngọc đậm'),
    (id: 'purple_dark', label: 'Tím đêm'),
    (id: 'wine', label: 'Rượu vang'),
    (id: 'slate_dark', label: 'Xám đậm'),
    (id: 'obsidian', label: 'Đen đá'),
    (id: 'amoled', label: 'Đen thuần'),
    (id: 'dots_dark', label: 'Chấm tối'),
    (id: 'stripes_dark', label: 'Sọc tối'),
    (id: 'grid_dark', label: 'Lưới tối'),
  ];
}
