import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../common/styles/app_colors.dart';
import '../controller/login_controller.dart';
import '../data/services/group_chat_service.dart';
import '../utils/chat_wallpaper_preferences.dart';
import 'chat_conversation_background.dart';

/// Bottom sheet chọn hình nền hội thoại.
Future<bool> showChatWallpaperPicker({
  required BuildContext context,
  required String groupId,
  bool isCandidateTheme = false,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ChatWallpaperPickerSheet(
      groupId: groupId,
      isCandidateTheme: isCandidateTheme,
    ),
  );
  return result == true;
}

class ChatWallpaperPickerSheet extends StatefulWidget {
  final String groupId;
  final bool isCandidateTheme;

  const ChatWallpaperPickerSheet({
    super.key,
    required this.groupId,
    this.isCandidateTheme = false,
  });

  @override
  State<ChatWallpaperPickerSheet> createState() =>
      _ChatWallpaperPickerSheetState();
}

class _ChatWallpaperPickerSheetState extends State<ChatWallpaperPickerSheet> {
  final _groupService = GroupChatService();
  ChatWallpaperConfig _current = const ChatWallpaperConfig();
  bool _loading = true;
  bool _saving = false;

  Color get _accent => widget.isCandidateTheme
      ? AppColors.candidatePrimary
      : AppColors.employerPrimary;

  String get _actorName {
    final u = Get.find<AuthController>().currentUser;
    if (u == null) return 'Một thành viên';
    final name = u.fullName.trim();
    if (name.isNotEmpty) return name;
    if (u.username.trim().isNotEmpty) return u.username.trim();
    return 'Một thành viên';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = await ChatWallpaperPreferences.loadForGroup(widget.groupId);
    if (mounted) {
      setState(() {
        _current = cfg;
        _loading = false;
      });
    }
  }

  Future<void> _applyPreset(String presetId) async {
    setState(() => _saving = true);
    try {
      await _groupService.saveGroupWallpaperPreset(
        widget.groupId,
        presetId,
        changedByName: _actorName,
      );
      if (mounted) {
        setState(() {
          _current = ChatWallpaperConfig(presetId: presetId);
          _saving = false;
        });
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        Get.snackbar(
          'Không lưu được',
          e.toString().replaceFirst('Exception: ', ''),
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1200,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (bytes.length > 900 * 1024) {
      Get.snackbar(
        'Ảnh quá lớn',
        'Vui lòng chọn ảnh nhỏ hơn 900KB',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _saving = true);
    final b64 = base64Encode(bytes);
    try {
      await _groupService.saveGroupWallpaperImage(
        widget.groupId,
        b64,
        changedByName: _actorName,
      );
      if (mounted) {
        setState(() {
          _current = ChatWallpaperConfig(imageBase64: b64);
          _saving = false;
        });
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        Get.snackbar(
          'Không lưu được',
          e.toString().replaceFirst('Exception: ', ''),
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  Future<void> _resetDefault() async {
    setState(() => _saving = true);
    try {
      await _groupService.clearGroupWallpaper(
        widget.groupId,
        changedByName: _actorName,
      );
      if (mounted) {
        setState(() {
          _current = const ChatWallpaperConfig();
          _saving = false;
        });
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        Get.snackbar(
          'Không lưu được',
          e.toString().replaceFirst('Exception: ', ''),
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  bool _isSelectedPreset(String id) =>
      !_current.hasCustomImage && (_current.presetId ?? ChatWallpaperPresets.defaultId) == id;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Hình nền hội thoại',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Mọi thành viên trong nhóm đều thấy nền này.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              if (_loading)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(color: _accent),
                  ),
                )
              else ...[
                SizedBox(
                  height: 88,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _actionChip(
                        icon: Icons.photo_library_outlined,
                        label: 'Thư viện ảnh',
                        onTap: _saving ? null : _pickFromGallery,
                      ),
                      const SizedBox(width: 10),
                      _actionChip(
                        icon: Icons.refresh_rounded,
                        label: 'Mặc định',
                        onTap: _saving ? null : _resetDefault,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.78,
                  children: [
                    for (final p in ChatWallpaperPresets.items)
                      _presetTile(p.id, p.label),
                  ],
                ),
              ],
              if (_saving) ...[
                const SizedBox(height: 12),
                Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _accent,
                    ),
                  ),
                ),
              ],
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: _accent.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _accent, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _accent,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _presetTile(String presetId, String label) {
    final selected = _isSelectedPreset(presetId);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _saving ? null : () => _applyPreset(presetId),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? _accent : Colors.grey.shade300,
                    width: selected ? 2.5 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: ChatConversationBackground(
                  config: ChatWallpaperConfig(presetId: presetId),
                  isCandidateTheme: widget.isCandidateTheme,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? _accent : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
