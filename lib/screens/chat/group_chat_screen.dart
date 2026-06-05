import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../common/styles/app_colors.dart';
import 'call_screen.dart';
import '../../controller/group_chat_controller.dart';
import '../../controller/login_controller.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/services/group_chat_service.dart';
import '../../data/models/group_chat_model.dart';
import '../../routes/app_routes.dart';
import 'group_management_screen.dart';
import '../../utils/chat_wallpaper_preferences.dart';
import '../../widgets/chat_conversation_background.dart';
import '../../widgets/swipe_to_reply.dart';
import '../../widgets/chat_wallpaper_picker_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GroupChatScreen — màn hình nhắn tin nhóm
// Argument: GroupChatModel
// ─────────────────────────────────────────────────────────────────────────────
class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  late final GroupChatController _ctrl;
  late final AuthController _auth;
  late final GroupChatModel _group;
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // Reply state
  ChatMessageModel? _replyToMsg;

  // Recording state
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  String? _recordingPath;
  ChatWallpaperConfig _wallpaper = const ChatWallpaperConfig();

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<GroupChatController>();
    _auth = Get.find<AuthController>();
    _group = Get.arguments as GroupChatModel;
    _wallpaper = _group.chatWallpaper;
    _loadWallpaper();
    _groupWallpaperSub = GroupChatService()
        .streamGroup(_group.groupId)
        .listen((g) {
      if (g != null && mounted) {
        setState(() => _wallpaper = g.chatWallpaper);
      }
    });
  }

  StreamSubscription<GroupChatModel?>? _groupWallpaperSub;

  Future<void> _loadWallpaper() async {
    final cfg = await ChatWallpaperPreferences.loadForGroup(_group.groupId);
    if (mounted) setState(() => _wallpaper = cfg);
  }

  @override
  void dispose() {
    _groupWallpaperSub?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _recordingTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // ── Permission helper ───────────────────────────────────────────────────────
  Future<bool> _requestPermission(Permission permission) async {
    var status = await permission.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Cần cấp quyền',
              style: TextStyle(fontWeight: FontWeight.w800)),
          content: Text(
            'Ứng dụng cần quyền ${_permissionLabel(permission)} để sử dụng tính năng này.\nVui lòng cấp quyền trong Cài đặt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child:
                  const Text('Hủy', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.employerPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Get.back();
                openAppSettings();
              },
              child: const Text('Mở Cài đặt',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return false;
    }
    status = await permission.request();
    return status.isGranted;
  }

  String _permissionLabel(Permission p) {
    if (p == Permission.camera) return 'Camera';
    if (p == Permission.microphone) return 'Microphone';
    return 'thư viện ảnh';
  }

  // ── Chọn ảnh từ thư viện ────────────────────────────────────────────────────
  Future<void> _pickFromGallery() async {
    // Thử photos (Android 13+) trước, nếu denied thì thử storage (Android < 13)
    if (Platform.isAndroid) {
      var status = await Permission.photos.request();
      if (!status.isGranted && !status.isLimited) {
        status = await Permission.storage.request();
        if (!status.isGranted) {
          if (status.isPermanentlyDenied && mounted) {
            await _showSettingsDialog('thư viện ảnh');
          }
          return;
        }
      }
    } else {
      final granted = await _requestPermission(Permission.photos);
      if (!granted) return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
      maxWidth: 1000,
      maxHeight: 1000,
    );
    if (picked == null) return;
    await _sendImageWithSizeCheck(File(picked.path));
  }

  // ── Chụp ảnh bằng camera ────────────────────────────────────────────────────
  Future<void> _takePhoto() async {
    final granted = await _requestPermission(Permission.camera);
    if (!granted) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 60,
      maxWidth: 1000,
      maxHeight: 1000,
    );
    if (picked == null) return;
    await _sendImageWithSizeCheck(File(picked.path));
  }

  // ── Kiểm tra kích thước ảnh trước khi gửi ──────────────────────────────────
  Future<void> _sendImageWithSizeCheck(File file) async {
    final bytes = await file.length();
    const limitBytes = 700 * 1024; // 700 KB

    if (bytes > limitBytes) {
      if (!mounted) return;
      final kb = (bytes / 1024).round();
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(children: [
            Icon(Icons.image_not_supported_outlined,
                color: Colors.orange, size: 22),
            SizedBox(width: 8),
            Text('Ảnh quá lớn', style: TextStyle(fontWeight: FontWeight.w800)),
          ]),
          content: Text(
            'Ảnh hiện tại là ${kb}KB (vượt giới hạn 700KB).\n\n'
            'Vui lòng chọn ảnh khác hoặc chụp ảnh mới với độ phân giải thấp hơn.',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.employerPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Get.back(),
              child: const Text('Đã hiểu',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    // Cảnh báo nhẹ nếu ảnh lớn nhưng vẫn trong giới hạn (>500KB)
    if (bytes > 500 * 1024 && mounted) {
      final kb = (bytes / 1024).round();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ảnh khá lớn (${kb}KB). Đang nén và gửi...'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.orange.shade700,
        ),
      );
    }

    await _ctrl.sendImage(file);
  }

  Future<void> _showSettingsDialog(String label) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Cần cấp quyền',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
            'Ứng dụng cần quyền $label.\nVui lòng cấp trong Cài đặt.'),
        actions: [
          TextButton(
              onPressed: () => Get.back(),
              child: const Text('Hủy',
                  style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.employerPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Get.back();
              openAppSettings();
            },
            child: const Text('Mở Cài đặt',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Ghi âm (mic) ────────────────────────────────────────────────────────────
  Future<void> _startRecording() async {
    final granted = await _requestPermission(Permission.microphone);
    if (!granted) return;

    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: _recordingPath!,
    );

    setState(() {
      _isRecording = true;
      _recordingDuration = Duration.zero;
    });

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _recordingDuration += const Duration(seconds: 1);
      });
      // Tự dừng sau 30 giây để tránh file quá lớn cho Firestore
      if (_recordingDuration.inSeconds >= 30) {
        _stopAndSendRecording();
      }
    });
  }

  Future<void> _stopAndSendRecording() async {
    _recordingTimer?.cancel();
    final path = await _recorder.stop();
    final duration = _recordingDuration;
    setState(() {
      _isRecording = false;
      _recordingDuration = Duration.zero;
    });
    if (path != null) {
      await _ctrl.sendAudio(File(path), duration);
    }
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    await _recorder.stop();
    setState(() {
      _isRecording = false;
      _recordingDuration = Duration.zero;
    });
  }

  // ── Bắt đầu cuộc gọi (thoại hoặc video qua ZEGOCLOUD) ────────────────────
  Future<void> _startCall({required bool isVideo}) async {
    final groupId = _ctrl.currentGroup.value?.groupId;
    if (groupId == null) return;

    // ZEGOCLOUD SDK tự xử lý permission internally — không pre-request ở đây.

    // ── Dialog xác nhận ───────────────────────────────────────────────────────
    final cleanId = groupId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final roomUrl = 'vl24h_${cleanId}_${isVideo ? "video" : "voice"}';

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isVideo
                    ? [const Color(0xFF1565C0), const Color(0xFF42A5F5)]
                    : [const Color(0xFF2E7D32), const Color(0xFF66BB6A)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isVideo ? 'Gọi video' : 'Gọi thoại',
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Một tin nhắn sẽ được gửi vào nhóm để các thành viên có thể tham gia.',
              style:
                  TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Icon(
                  isVideo
                      ? Icons.videocam_rounded
                      : Icons.phone_rounded,
                  size: 16,
                  color: isVideo
                      ? const Color(0xFF1565C0)
                      : const Color(0xFF2E7D32),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isVideo
                        ? 'Cuộc gọi video — cần Camera & Micro'
                        : 'Cuộc gọi thoại — cần Micro',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                ),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Hủy',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isVideo
                  ? const Color(0xFF1565C0)
                  : const Color(0xFF2E7D32),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: Icon(
              isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
              color: Colors.white,
              size: 16,
            ),
            label: Text(
              isVideo ? 'Gọi video' : 'Gọi thoại',
              style: const TextStyle(color: Colors.white),
            ),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // ── 3. Gửi tin nhắn + mở màn hình gọi ───────────────────────────────────
    await _ctrl.sendCallMessage(isVideo: isVideo, roomUrl: roomUrl);

    if (!mounted) return;
    final groupName = _ctrl.currentGroup.value?.jobTitle ?? 'Cuộc gọi';
    final user = _auth.currentUser;
    final userName =
        '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          roomUrl: roomUrl,
          isVideo: isVideo,
          groupName: groupName,
          userName: userName.isEmpty ? 'Employer' : userName,
          userId:
              user?.id ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
          callId: roomUrl,
        ),
      ),
    );
  }

  // ── Chọn file ───────────────────────────────────────────────────────────────
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) return;
      final pf = result.files.single;
      if (pf.path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không đọc được đường dẫn file.')),
          );
        }
        return;
      }

      final sizeKb = (pf.size / 1024).round();
      if (pf.size > 500 * 1024) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
            title: const Row(children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('File quá lớn',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ]),
            content: Text(
              '"${pf.name}" có kích thước ${sizeKb}KB.\n'
              'Giới hạn tối đa là 500KB.\nVui lòng chọn file nhỏ hơn.',
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.employerPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Đã hiểu',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        return;
      }

      await _ctrl.sendFile(File(pf.path!), pf.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi chọn file: $e'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // ── Lấy vị trí GPS → xác nhận → gửi ────────────────────────────────────────
  Future<void> _sendLocationWithFeedback() async {
    if (!mounted) return;

    // 1. Kiểm tra GPS service bật chưa
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          title: const Row(children: [
            Icon(Icons.location_off_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('GPS chưa bật',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ]),
          content: const Text(
              'Vui lòng bật GPS trong Cài đặt rồi thử lại.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openLocationSettings();
              },
              child: const Text('Mở Cài đặt',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    // 2. Xin quyền vị trí
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Cần quyền vị trí. Vào Cài đặt → Ứng dụng để cấp.'),
            backgroundColor: Colors.red.shade700,
            action: SnackBarAction(
              label: 'Cài đặt',
              textColor: Colors.white,
              onPressed: () => Geolocator.openAppSettings(),
            ),
          ),
        );
      }
      return;
    }

    // 3. Hiện loading
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [
          SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white),
          ),
          SizedBox(width: 12),
          Text('Đang xác định vị trí...'),
        ]),
        backgroundColor: const Color(0xFF2E7D32),
        duration: const Duration(seconds: 15),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      // 4. Lấy tọa độ GPS — dùng best accuracy, timeout 25s
      Position pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
          ),
        ).timeout(const Duration(seconds: 25));
      } on TimeoutException {
        // Hết timeout → thử lấy vị trí cuối cùng đã biết làm fallback
        final last = await Geolocator.getLastKnownPosition();
        if (last == null) {
          throw Exception('Không lấy được vị trí. Kiểm tra GPS và thử lại.');
        }
        pos = last;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Phân loại độ chính xác
      final accuracy = pos.accuracy;
      final String accuracyLabel;
      final Color accuracyColor;
      if (accuracy <= 20) {
        accuracyLabel = 'Tốt (±${accuracy.round()}m)';
        accuracyColor = const Color(0xFF2E7D32);
      } else if (accuracy <= 100) {
        accuracyLabel = 'Trung bình (±${accuracy.round()}m)';
        accuracyColor = Colors.orange;
      } else {
        accuracyLabel = 'Kém (±${accuracy.round()}m) — có thể không chính xác';
        accuracyColor = Colors.red;
      }

      // 5. Dialog xác nhận trước khi gửi
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.location_on_rounded,
                color: Color(0xFF2E7D32), size: 24),
            SizedBox(width: 8),
            Text('Gửi vị trí hiện tại',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Preview bản đồ mini với link mở Google Maps
              GestureDetector(
                onTap: () => launchUrl(
                  Uri.parse(
                    'https://www.google.com/maps/search/?api=1'
                    '&query=${pos.latitude},${pos.longitude}',
                  ),
                  mode: LaunchMode.externalApplication,
                ),
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(Icons.location_pin,
                            size: 48, color: Color(0xFF2E7D32)),
                      ),
                      Positioned(
                        bottom: 6, right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Xem trên Google Maps',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF2E7D32),
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Tọa độ
              Row(children: [
                const Icon(Icons.my_location_rounded,
                    size: 16, color: Color(0xFF2E7D32)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${pos.latitude.toStringAsFixed(6)}, '
                    '${pos.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              // Độ chính xác có màu
              Row(children: [
                Icon(Icons.gps_fixed_rounded,
                    size: 14, color: accuracyColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    accuracyLabel,
                    style: TextStyle(
                        fontSize: 11,
                        color: accuracyColor,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
              // Cảnh báo nếu kém chính xác
              if (accuracy > 100)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Row(children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 14, color: Colors.orange),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'GPS chưa ổn định. Ra ngoài trời hoặc chờ thêm để có vị trí chính xác hơn.',
                        style: TextStyle(fontSize: 10, color: Colors.orange),
                      ),
                    ),
                  ]),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Hủy',
                  style: TextStyle(color: Colors.grey.shade600)),
            ),
            // Thử lại nếu GPS kém
            if (accuracy > 100)
              TextButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Thử lại'),
                style: TextButton.styleFrom(
                    foregroundColor: Colors.orange),
                onPressed: () {
                  Navigator.of(context).pop(false);
                  Future.delayed(const Duration(milliseconds: 200),
                      _sendLocationWithFeedback);
                },
              ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 16),
              label: const Text('Gửi',
                  style: TextStyle(color: Colors.white)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await _ctrl.sendLocation(
          lat: pos.latitude,
          lng: pos.longitude,
          accuracy: pos.accuracy,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không lấy được vị trí: $e'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // ── Tạo thăm dò ý kiến ─────────────────────────────────────────────────────
  void _showCreatePollDialog() {
    final questionCtrl = TextEditingController();
    final optionCtrls = [
      TextEditingController(),
      TextEditingController(),
    ];
    bool allowMultiple = false; // single choice mặc định

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 16, top: 8),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  // Header
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF7B1FA2), Color(0xFFCE93D8)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.poll_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('Tạo thăm dò ý kiến',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 16),
                  // Câu hỏi
                  _PollTextField(
                    controller: questionCtrl,
                    hint: 'Nhập câu hỏi...',
                    icon: Icons.help_outline_rounded,
                  ),
                  const SizedBox(height: 12),
                  // Các lựa chọn
                  ...optionCtrls.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      // Icon phản ánh chế độ chọn
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          allowMultiple
                              ? Icons.check_box_outline_blank
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      Expanded(
                        child: _PollTextField(
                          controller: e.value,
                          hint: 'Lựa chọn ${e.key + 1}',
                          icon: null,
                        ),
                      ),
                      if (optionCtrls.length > 2)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: Colors.red),
                          onPressed: () =>
                              setState(() => optionCtrls.removeAt(e.key)),
                        ),
                    ]),
                  )),
                  // Thêm lựa chọn
                  if (optionCtrls.length < 4)
                    TextButton.icon(
                      onPressed: () => setState(
                          () => optionCtrls.add(TextEditingController())),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Thêm lựa chọn'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.employerPrimary),
                    ),
                  const SizedBox(height: 4),
                  // ── Toggle chế độ chọn ───────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        // 1 lựa chọn
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => allowMultiple = false),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !allowMultiple
                                    ? const Color(0xFF7B1FA2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.radio_button_checked,
                                      size: 16,
                                      color: !allowMultiple
                                          ? Colors.white
                                          : Colors.grey),
                                  const SizedBox(width: 6),
                                  Text('1 lựa chọn',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: !allowMultiple
                                            ? Colors.white
                                            : Colors.grey.shade600,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Nhiều lựa chọn
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => allowMultiple = true),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: allowMultiple
                                    ? const Color(0xFF7B1FA2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_box_outlined,
                                      size: 16,
                                      color: allowMultiple
                                          ? Colors.white
                                          : Colors.grey),
                                  const SizedBox(width: 6),
                                  Text('Nhiều lựa chọn',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: allowMultiple
                                            ? Colors.white
                                            : Colors.grey.shade600,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Nút gửi
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        backgroundColor: const Color(0xFF7B1FA2),
                      ),
                      onPressed: () async {
                        final question = questionCtrl.text.trim();
                        final opts = optionCtrls
                            .map((c) => c.text.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();
                        if (question.isEmpty || opts.length < 2) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Nhập câu hỏi và ít nhất 2 lựa chọn.'),
                            ),
                          );
                          return;
                        }
                        Navigator.of(ctx).pop();
                        await _ctrl.createPoll(
                          question: question,
                          options: opts,
                          allowMultiple: allowMultiple,
                        );
                      },
                      child: const Text('Gửi thăm dò',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();

    Map<String, dynamic>? replyMeta;
    if (_replyToMsg != null) {
      replyMeta = {
        'msgId': _replyToMsg!.msgId,
        'senderName': _replyToMsg!.senderName,
        'content': _replyToMsg!.type == 'text'
            ? _replyToMsg!.content
            : '[${_replyToMsg!.type}]',
      };
      setState(() => _replyToMsg = null);
    }

    await _ctrl.sendTextWithReply(text, replyTo: replyMeta);
    _scrollToBottom();
  }

  bool _canSwipeToReply(ChatMessageModel msg) {
    if (msg.type == 'system' || msg.senderId == 'system') return false;
    if (msg.type == 'call' || msg.type == 'recalled') return false;
    return true;
  }

  // ── Hiển thị action menu khi long press ──────────────────────────────────
  void _showMessageActions(
      BuildContext context, ChatMessageModel msg, bool isMe) {
    if (msg.type == 'system' || msg.senderId == 'system') return;
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,        // cho phép sheet cao hơn 50%
      useSafeArea: true,
      builder: (_) => _MessageActionsSheet(
        msg: msg,
        isMe: isMe,
        onReply: () {
          Navigator.pop(context);
          setState(() => _replyToMsg = msg);
        },
        onCopy: () {
          Navigator.pop(context);
          var text = msg.content.trim();
          if (text.isEmpty) {
            if (msg.type == 'image') text = '[Hình ảnh]';
            else if (msg.type == 'audio') text = '[Tin thoại]';
            else if (msg.type == 'file') text = '[Tệp đính kèm]';
            else if (msg.type == 'location') text = '[Vị trí]';
            else return;
          }
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã sao chép'),
              duration: Duration(seconds: 1),
            ),
          );
        },
        onEdit: (isMe && msg.type == 'text')
            ? () {
                Navigator.pop(context);
                _showEditDialog(context, msg);
              }
            : null,
        onRecall: isMe
            ? () async {
                Navigator.pop(context);
                await _ctrl.recallMessage(msg.msgId);
              }
            : null,
        onDelete: isMe
            ? () async {
                Navigator.pop(context);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: const Text('Xóa tin nhắn',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    content: const Text('Tin nhắn sẽ bị xóa vĩnh viễn.'),
                    actions: [
                      TextButton(
                          onPressed: () => Get.back(result: false),
                          child: const Text('Hủy',
                              style: TextStyle(color: Colors.grey))),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        onPressed: () => Get.back(result: true),
                        child: const Text('Xóa',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (ok == true) await _ctrl.deleteMessage(msg.msgId);
              }
            : null,
        onPin: () async {
          Navigator.pop(context);
          await _ctrl.pinMessage(msg.msgId);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Đã ghim tin nhắn'),
                duration: Duration(seconds: 2)),
          );
        },
      ),
    );
  }

  // ── Dialog sửa tin nhắn ──────────────────────────────────────────────────
  void _showEditDialog(BuildContext context, ChatMessageModel msg) {
    final editCtrl = TextEditingController(text: msg.content);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit_rounded, color: Color(0xFF7B1FA2), size: 22),
            SizedBox(width: 8),
            Text('Sửa tin nhắn',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: TextField(
          controller: editCtrl,
          autofocus: true,
          maxLines: 5,
          minLines: 1,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        actions: [
          TextButton(
              onPressed: Get.back,
              child: const Text('Hủy',
                  style: TextStyle(color: Colors.grey))),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B1FA2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            icon: const Icon(Icons.check_rounded,
                color: Colors.white, size: 18),
            label: const Text('Lưu',
                style: TextStyle(color: Colors.white)),
            onPressed: () async {
              final newText = editCtrl.text.trim();
              if (newText.isEmpty || newText == msg.content) {
                Get.back();
                return;
              }
              await _ctrl.editMessage(msg.msgId, newText);
              Get.back();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EBF5),
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          ChatConversationBackground(
            config: _wallpaper,
            isCandidateTheme: true,
          ),
          Column(
            children: [
              Expanded(
                child: Obx(() {
                  _scrollToBottom();
                  return ListView.builder(
                    controller: _scrollCtrl,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                    itemCount: _ctrl.messages.length,
                    itemBuilder: (_, i) {
                      final msg = _ctrl.messages[i];
                      final isMe = msg.senderId == _auth.currentUser?.id;
                      final bubble = _MessageBubble(
                        msg: msg,
                        isMe: isMe,
                        onLongPress: () =>
                            _showMessageActions(context, msg, isMe),
                      );
                      if (!_canSwipeToReply(msg)) return bubble;
                      return SwipeToReply(
                        alignEnd: isMe,
                        iconColor: const Color(0xFF2E7D32),
                        onReply: () => setState(() => _replyToMsg = msg),
                        child: bubble,
                      );
                    },
                  );
                }),
              ),
              _isRecording ? _buildRecordingBar() : _buildInputBar(),
            ],
          ),
          // Upload overlay
          Obx(() => _ctrl.isUploading.value
              ? Container(
                  color: Colors.black.withOpacity(0.35),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 22),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.employerPrimary),
                            strokeWidth: 3,
                          ),
                          SizedBox(height: 14),
                          Text(
                            'Đang gửi ảnh...',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF212121),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink()),
        ],
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.employerPrimary,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6A0DAD), Color(0xFF7B1FA2), Color(0xFF1565C0)],
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            color: Colors.white, size: 20),
        onPressed: () {
          _ctrl.closeGroup();
          Get.back();
        },
      ),
    titleSpacing: 0,
        title: Obx(() {
      final group = _ctrl.currentGroup.value ?? _group;
      return GestureDetector(
        onTap: () async {
          await Get.to(
            () => const GroupManagementScreen(),
            arguments: {'group': group, 'isCandidate': true},
            transition: Transition.downToUp,
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
          );
          await _loadWallpaper();
        },
        child: Row(
          children: [
            // Group avatar circle — hiển thị Base64 nếu có
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFCE93D8), Color(0xFF7B1FA2)],
                ),
                border: Border.all(
                    color: Colors.white.withOpacity(0.6), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: _safeAvatarImage(
                    group.groupAvatarBase64, 20),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.jobTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF69F0AE),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${group.memberIds.length} thành viên',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }),
      actions: [
        _AppBarIconBtn(
          icon: Icons.phone_rounded,
          onTap: () => _startCall(isVideo: false),
        ),
        _AppBarIconBtn(
          icon: Icons.videocam_rounded,
          onTap: () => _startCall(isVideo: true),
        ),
        Obx(() {
          final g = _ctrl.currentGroup.value ?? _group;
          return _AppBarIconBtn(
            icon: Icons.menu_rounded,
            onTap: () async {
              await Get.to(
                () => const GroupManagementScreen(),
                arguments: {'group': g, 'isCandidate': true},
                transition: Transition.downToUp,
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
              );
              await _loadWallpaper();
            },
          );
        }),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Helper: hiển thị ảnh base64 an toàn, xử lý cả Data URI prefix ──────────
  static Widget _safeAvatarImage(String? b64, double iconSize) {
    if (b64 != null && b64.isNotEmpty) {
      try {
        // Xử lý cả Data URI (data:image/...;base64,...)
        final data = b64.contains(',') ? b64.split(',').last : b64;
        final bytes = base64Decode(data.trim());
        return Image.memory(bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.group, color: Colors.white, size: iconSize));
      } catch (_) {}
    }
    return Icon(Icons.group, color: Colors.white, size: iconSize);
  }

  // ── Recording bar (thay thế input bar khi đang ghi âm) ─────────────────────
  Widget _buildRecordingBar() {
    const maxSec = 30;
    final elapsed = _recordingDuration.inSeconds.clamp(0, maxSec);
    final remaining = maxSec - elapsed;
    final progress = elapsed / maxSec;

    // Màu đổi dần: xanh → cam → đỏ
    final Color barColor;
    if (elapsed < 20) {
      barColor = const Color(0xFF2196F3); // xanh
    } else if (elapsed < 25) {
      barColor = Colors.orange;           // cam
    } else {
      barColor = Colors.red;              // đỏ
    }

    final mm = (elapsed ~/ 60).toString().padLeft(2, '0');
    final ss = (elapsed % 60).toString().padLeft(2, '0');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Thanh tiến độ ─────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 4),
          // ── Nhãn giới hạn ─────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                remaining <= 5
                    ? '⚠ Còn $remaining giây!'
                    : 'Tối đa 30 giây',
                style: TextStyle(
                  fontSize: 11,
                  color: remaining <= 5 ? Colors.red : Colors.grey.shade500,
                  fontWeight: remaining <= 5
                      ? FontWeight.w700
                      : FontWeight.normal,
                ),
              ),
              Text(
                '$elapsed / ${maxSec}s',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── Hàng nút + timer ──────────────────────────────────────────────
          Row(
            children: [
              // Nút hủy
              GestureDetector(
                onTap: _cancelRecording,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Colors.red, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              // Timer + waveform
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F9),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE8D5F5)),
                  ),
                  child: Row(
                    children: [
                      // Dot nhấp nháy — đổi màu theo giai đoạn
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: elapsed % 2 == 0
                              ? barColor
                              : barColor.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$mm:$ss',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: elapsed >= 25
                              ? Colors.red
                              : const Color(0xFF212121),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _FakeWaveform(tick: elapsed)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Nút gửi
              GestureDetector(
                onTap: _stopAndSendRecording,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: elapsed >= 25
                          ? [Colors.red.shade700, Colors.red.shade400]
                          : const [Color(0xFF7B1FA2), Color(0xFF1565C0)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (elapsed >= 25
                                ? Colors.red
                                : const Color(0xFF7B1FA2))
                            .withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.stop_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Bottom sheet đính kèm ───────────────────────────────────────────────────
  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20, top: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Đính kèm',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF212121),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _AttachOption(
                  icon: Icons.image_rounded,
                  label: 'Ảnh',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B1FA2), Color(0xFFCE93D8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await Future.delayed(const Duration(milliseconds: 350));
                    if (!mounted) return;
                    _pickFromGallery();
                  },
                ),
                _AttachOption(
                  icon: Icons.insert_drive_file_rounded,
                  label: 'File',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    // Đợi animation bottom sheet đóng hoàn toàn
                    await Future.delayed(const Duration(milliseconds: 350));
                    if (!mounted) return;
                    _pickFile();
                  },
                ),
                _AttachOption(
                  icon: Icons.location_on_rounded,
                  label: 'Vị trí',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await Future.delayed(const Duration(milliseconds: 350));
                    if (!mounted) return;
                    _sendLocationWithFeedback();
                  },
                ),
                _AttachOption(
                  icon: Icons.poll_rounded,
                  label: 'Thăm dò ý kiến',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B1FA2), Color(0xFFCE93D8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await Future.delayed(const Duration(milliseconds: 350));
                    if (!mounted) return;
                    _showCreatePollDialog();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Input bar ───────────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Reply preview bar
          if (_replyToMsg != null)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.employerPrimary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trả lời ${_replyToMsg!.senderName}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.employerPrimary),
                        ),
                        Text(
                          _replyToMsg!.type == 'text'
                              ? _replyToMsg!.content
                              : '[${_replyToMsg!.type}]',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: Colors.grey),
                    onPressed: () => setState(() => _replyToMsg = null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          // Input row
          Obx(() {
            final currentGroup = _ctrl.currentGroup.value;
            if (currentGroup?.isDissolved == true) {
              return Padding(
                padding: EdgeInsets.fromLTRB(
                    12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      'Nhóm chat đã bị khóa do công việc đã hoàn tất.',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                  12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
              child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _InputIconBtn(
            icon: Icons.add_rounded,
            bgColor: const Color(0xFF1565C0),
            onTap: _showAttachMenu,
          ),
          const SizedBox(width: 6),
          _InputIconBtn(
            icon: Icons.camera_alt_rounded,
            bgColor: const Color(0xFF37474F),
            onTap: _takePhoto,
          ),
          const SizedBox(width: 6),
          _InputIconBtn(
            icon: Icons.mic_rounded,
            bgColor: const Color(0xFF7B1FA2),
            onTap: _startRecording,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F9),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFFE0E3F0)),
              ),
              child: TextField(
                controller: _textCtrl,
                minLines: 1,
                maxLines: 4,
                style: const TextStyle(fontSize: 14.5, color: Color(0xFF212121)),
                decoration: const InputDecoration(
                  hintText: 'Nhắn tin...',
                  hintStyle: TextStyle(color: Color(0xFFADB5C9), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  isDense: true,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Obx(() => _ctrl.isSending.value
              ? const SizedBox(
                  width: 42,
                  height: 42,
                  child: Padding(
                    padding: EdgeInsets.all(9),
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ))
              : GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF7B1FA2), Color(0xFF1565C0)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x557B1FA2),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                  ),
                )),
          ],
        ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Decorative chat background
// ─────────────────────────────────────────────────────────────────────────────
class _ChatBackground extends StatelessWidget {
  const _ChatBackground();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SizedBox.expand(
      child: CustomPaint(
        painter: _BgPainter(size),
      ),
    );
  }
}

class _BgPainter extends CustomPainter {
  final Size screenSize;
  const _BgPainter(this.screenSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0x0C7B1FA2);
    canvas.drawCircle(
        Offset(screenSize.width * 0.85, screenSize.height * 0.12), 90, paint);

    paint.color = const Color(0x081565C0);
    canvas.drawCircle(
        Offset(screenSize.width * 0.1, screenSize.height * 0.35), 70, paint);

    paint.color = const Color(0x067B1FA2);
    canvas.drawCircle(
        Offset(screenSize.width * 0.75, screenSize.height * 0.65), 110, paint);

    paint.color = const Color(0x051565C0);
    canvas.drawCircle(
        Offset(screenSize.width * 0.2, screenSize.height * 0.85), 80, paint);
  }

  @override
  bool shouldRepaint(_BgPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Message bubble
// ─────────────────────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.msg,
    required this.isMe,
    this.onLongPress,
  });

  final ChatMessageModel msg;
  final bool isMe;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    if (msg.type == 'system') return _SystemMessage(content: msg.content);
    if (msg.type == 'schedule') {
      return GestureDetector(
          onLongPress: onLongPress,
          child: _ScheduleBubble(msg: msg, isMe: isMe));
    }
    if (msg.type == 'image') {
      return GestureDetector(
          onLongPress: onLongPress,
          child: _ImageBubble(msg: msg, isMe: isMe));
    }
    if (msg.type == 'audio') {
      return GestureDetector(
          onLongPress: onLongPress,
          child: _AudioBubble(msg: msg, isMe: isMe));
    }
    if (msg.type == 'file') {
      return GestureDetector(
          onLongPress: onLongPress,
          child: _FileBubble(msg: msg, isMe: isMe));
    }
    if (msg.type == 'location') {
      return GestureDetector(
          onLongPress: onLongPress,
          child: _LocationBubble(msg: msg, isMe: isMe));
    }
    if (msg.type == 'poll') {
      return GestureDetector(
          onLongPress: onLongPress,
          child: _PollBubble(msg: msg, isMe: isMe));
    }
    if (msg.type == 'call') return _CallBubble(msg: msg, isMe: isMe);

    // recalled
    if (msg.type == 'recalled') {
      return _RecalledBubble(isMe: isMe, time: msg.createdAt);
    }

    // text (and fallback)
    final replyTo = msg.metadata?['replyTo'] as Map?;
    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              _Avatar(name: msg.senderName),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 3),
                      child: Text(
                        msg.senderName,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _nameColor(msg.senderName),
                        ),
                      ),
                    ),
                  // Bubble — IntrinsicWidth để vừa với nội dung
                  IntrinsicWidth(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.72,
                      ),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
                        decoration: BoxDecoration(
                          gradient: isMe
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF7B1FA2), Color(0xFF1565C0)],
                                )
                              : null,
                          color: isMe ? null : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(isMe ? 18 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 18),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isMe
                                  ? const Color(0x407B1FA2)
                                  : Colors.black.withOpacity(0.07),
                              blurRadius: isMe ? 10 : 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Reply preview
                            if (replyTo != null) ...[
                              Container(
                                padding: const EdgeInsets.all(8),
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? Colors.white.withOpacity(0.15)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border(
                                    left: BorderSide(
                                      color: isMe
                                          ? Colors.white.withOpacity(0.6)
                                          : AppColors.employerPrimary,
                                      width: 3,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      replyTo['senderName'] as String? ?? '',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isMe
                                            ? Colors.white.withOpacity(0.9)
                                            : AppColors.employerPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      replyTo['content'] as String? ?? '',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isMe
                                            ? Colors.white.withOpacity(0.75)
                                            : Colors.grey.shade600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            // Content
                            Text(
                              msg.content,
                              style: TextStyle(
                                color: isMe
                                    ? Colors.white
                                    : const Color(0xFF1A1A2E),
                                fontSize: 14.5,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 3),
                            // Time + edited + checkmark
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (msg.edited) ...[
                                  Text(
                                    'đã sửa · ',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic,
                                      color: isMe
                                          ? Colors.white.withOpacity(0.55)
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                                ],
                                Text(
                                  DateFormat('HH:mm').format(msg.createdAt),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isMe
                                        ? Colors.white.withOpacity(0.6)
                                        : Colors.grey.shade400,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 3),
                                  Icon(
                                    Icons.done_all_rounded,
                                    size: 12,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isMe) const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  Color _nameColor(String name) {
    final colors = [
      const Color(0xFF1565C0),
      const Color(0xFF7B1FA2),
      const Color(0xFF2E7D32),
      const Color(0xFFE65100),
      const Color(0xFF00695C),
      const Color(0xFFC62828),
    ];
    final idx = name.isNotEmpty
        ? name.codeUnits.reduce((a, b) => a + b) % colors.length
        : 0;
    return colors[idx];
  }
}

// ─── System message ───────────────────────────────────────────────────────────
// ─── Tin nhắn đã thu hồi ─────────────────────────────────────────────────────
class _RecalledBubble extends StatelessWidget {
  const _RecalledBubble({required this.isMe, required this.time});
  final bool isMe;
  final DateTime time;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block_rounded,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text(
                  'Tin nhắn đã được thu hồi',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('HH:mm').format(time),
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action sheet khi long press ─────────────────────────────────────────────
class _MessageActionsSheet extends StatelessWidget {
  const _MessageActionsSheet({
    required this.msg,
    required this.isMe,
    required this.onReply,
    required this.onCopy,
    required this.onPin,
    this.onEdit,
    this.onRecall,
    this.onDelete,
  });

  final ChatMessageModel msg;
  final bool isMe;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback onPin;
  final VoidCallback? onEdit;
  final VoidCallback? onRecall;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    // Danh sách actions
    final actions = <_ActionItem>[
      _ActionItem(
        icon: Icons.reply_rounded,
        label: 'Trả lời',
        subtitle: 'Trích dẫn và phản hồi',
        color: const Color(0xFF1565C0),
        onTap: onReply,
      ),
      if (msg.type == 'text')
        _ActionItem(
          icon: Icons.copy_rounded,
          label: 'Sao chép',
          subtitle: 'Chép vào clipboard',
          color: const Color(0xFF2E7D32),
          onTap: onCopy,
        ),
      _ActionItem(
        icon: Icons.push_pin_rounded,
        label: 'Ghim tin nhắn',
        subtitle: 'Xem lại dễ dàng',
        color: const Color(0xFFE65100),
        onTap: onPin,
      ),
      if (onEdit != null)
        _ActionItem(
          icon: Icons.edit_rounded,
          label: 'Sửa tin nhắn',
          subtitle: 'Chỉnh sửa nội dung',
          color: const Color(0xFF00695C),
          onTap: onEdit!,
        ),
      if (onRecall != null)
        _ActionItem(
          icon: Icons.undo_rounded,
          label: 'Thu hồi',
          subtitle: 'Xóa với tất cả thành viên',
          color: const Color(0xFF7B1FA2),
          onTap: onRecall!,
        ),
      if (onDelete != null)
        _ActionItem(
          icon: Icons.delete_outline_rounded,
          label: 'Xóa',
          subtitle: 'Xóa vĩnh viễn',
          color: const Color(0xFFC62828),
          onTap: onDelete!,
        ),
    ];

    return Container(
      decoration: BoxDecoration(        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // Không set chiều cao cố định — để co theo nội dung
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Preview nội dung tin nhắn
          if (msg.type == 'text')
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                msg.content,
                style: const TextStyle(fontSize: 14, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 8),
          // List các action (cuộn nếu nhiều)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 62,
                color: Colors.grey.shade100),
            itemBuilder: (_, i) {
              final a = actions[i];
              return ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: a.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(a.icon, color: a.color, size: 20),
                ),
                title: Text(a.label,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: a.color == const Color(0xFFC62828)
                            ? a.color
                            : null)),
                subtitle: Text(a.subtitle,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
                trailing: Icon(Icons.chevron_right_rounded,
                    color: Colors.grey.shade300, size: 20),
                onTap: a.onTap,
              );
            },
          ),
          // Safe area bottom
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}


// ─── System message ───────────────────────────────────────────────────────────
class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.content});
  final String content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0x1A2E7D32), Color(0x1A43A047)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x252E7D32)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 12, color: Color(0xFF2E7D32)),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  content,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1B5E20),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Schedule bubble ──────────────────────────────────────────────────────────
class _ScheduleBubble extends StatelessWidget {
  const _ScheduleBubble({required this.msg, required this.isMe});
  final ChatMessageModel msg;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x337B1FA2)),
            boxShadow: [
              BoxShadow(
                color: const Color(0x207B1FA2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF7B1FA2), Color(0xFF1565C0)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.assignment_rounded,
                        color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Phân công công việc',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Text(
                  msg.content,
                  style: const TextStyle(
                      fontSize: 13.5, color: Color(0xFF1A1A2E), height: 1.4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Text(
                  DateFormat('HH:mm').format(msg.createdAt),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── AppBar icon button ───────────────────────────────────────────────────────
class _AppBarIconBtn extends StatelessWidget {
  const _AppBarIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ─── Input icon button ────────────────────────────────────────────────────────
class _InputIconBtn extends StatelessWidget {
  const _InputIconBtn(
      {required this.icon, required this.bgColor, required this.onTap});
  final IconData icon;
  final Color bgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: bgColor, size: 20),
      ),
    );
  }
}

// ─── Attach option ────────────────────────────────────────────────────────────
class _AttachOption extends StatelessWidget {
  const _AttachOption({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: gradient.colors.first.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF424242),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Fake waveform decoration ─────────────────────────────────────────────────
class _FakeWaveform extends StatelessWidget {
  const _FakeWaveform({required this.tick});
  final int tick;

  static const _heights = [6.0, 14.0, 10.0, 18.0, 8.0, 16.0, 12.0, 20.0,
                            7.0, 15.0, 11.0, 18.0, 9.0, 14.0, 6.0, 12.0];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(_heights.length, (i) {
        final active = i <= (tick % _heights.length);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 3,
          height: _heights[i],
          decoration: BoxDecoration(
            color: active
                ? AppColors.employerPrimary
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

// ─── Audio bubble ─────────────────────────────────────────────────────────────
class _AudioBubble extends StatefulWidget {
  const _AudioBubble({required this.msg, required this.isMe});
  final ChatMessageModel msg;
  final bool isMe;

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  static const _waveHeights = [5.0, 12.0, 8.0, 16.0, 10.0, 18.0,
                                7.0, 14.0, 9.0, 16.0, 6.0, 11.0];

  final _player = AudioPlayer();
  bool _isPlaying = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final raw = widget.msg.attachmentUrl ?? '';
    if (raw.isEmpty) return;

    if (_isPlaying) {
      await _player.stop();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    try {
      final base64Str = raw.contains(',') ? raw.split(',').last : raw;
      final bytes = base64Decode(base64Str);

      // Ghi ra file tạm — Android MediaPlayer không hỗ trợ play từ bytes trực tiếp
      final dir = await getTemporaryDirectory();
      final tmpFile = File('${dir.path}/ap_${widget.msg.msgId}.m4a');
      await tmpFile.writeAsBytes(bytes, flush: true);

      await _player.play(DeviceFileSource(tmpFile.path));
      if (mounted) setState(() => _isPlaying = true);

      _player.onPlayerComplete.first.then((_) {
        if (mounted) setState(() => _isPlaying = false);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể phát audio: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.isMe;
    final msg = widget.msg;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            _Avatar(name: msg.senderName),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(
                      msg.senderName,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade600),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                    minWidth: 160,
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF7B1FA2), Color(0xFF1565C0)],
                          )
                        : null,
                    color: isMe ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isMe
                            ? const Color(0x407B1FA2)
                            : Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Play/Stop button
                          GestureDetector(
                            onTap: _togglePlay,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isMe
                                    ? Colors.white.withOpacity(0.2)
                                    : AppColors.employerPrimary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isPlaying
                                    ? Icons.stop_rounded
                                    : Icons.play_arrow_rounded,
                                color: isMe
                                    ? Colors.white
                                    : AppColors.employerPrimary,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Waveform static
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: _waveHeights.map((h) => Container(
                                width: 3,
                                height: _isPlaying ? h * 1.3 : h,
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? Colors.white.withOpacity(
                                          _isPlaying ? 1.0 : 0.7)
                                      : AppColors.employerPrimary.withOpacity(
                                          _isPlaying ? 0.9 : 0.5),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              )).toList(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Duration label
                          Text(
                            msg.content,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isMe
                                  ? Colors.white
                                  : const Color(0xFF212121),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('HH:mm').format(msg.createdAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: isMe
                                    ? Colors.white.withOpacity(0.65)
                                    : Colors.grey.shade500,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 3),
                              Icon(Icons.done_all_rounded,
                                  size: 13,
                                  color: Colors.white.withOpacity(0.7)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 6),
        ],
      ),
    );
  }
}

// ─── Image bubble ─────────────────────────────────────────────────────────────
class _ImageBubble extends StatelessWidget {
  const _ImageBubble({required this.msg, required this.isMe});
  final ChatMessageModel msg;
  final bool isMe;

  Widget _buildImageWidget() {
    final raw = msg.attachmentUrl ?? '';
    if (raw.startsWith('data:')) {
      // Base64 data URL
      try {
        final base64Str = raw.contains(',') ? raw.split(',').last : raw;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _brokenIcon(),
        );
      } catch (_) {
        return _brokenIcon();
      }
    }
    // Fallback: không có ảnh
    return _brokenIcon();
  }

  Widget _brokenIcon() => Container(
        height: 100,
        color: const Color(0xFFEEF0F7),
        child: const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.grey),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            _Avatar(name: msg.senderName),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(
                      msg.senderName,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                // Image container
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.65,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isMe
                            ? const Color(0x407B1FA2)
                            : Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      _buildImageWidget(),
                      // Timestamp overlay
                      Positioned(
                        bottom: 6,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('HH:mm').format(msg.createdAt),
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.white),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 3),
                                const Icon(Icons.done_all_rounded,
                                    size: 12, color: Colors.white70),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 6),
        ],
      ),
    );
  }
}

// ─── File bubble ──────────────────────────────────────────────────────────────
class _FileBubble extends StatelessWidget {
  const _FileBubble({required this.msg, required this.isMe});
  final ChatMessageModel msg;
  final bool isMe;

  IconData _iconForExt(String ext) => switch (ext) {
        'pdf' => Icons.picture_as_pdf_rounded,
        'doc' || 'docx' => Icons.description_rounded,
        'xls' || 'xlsx' => Icons.table_chart_rounded,
        'ppt' || 'pptx' => Icons.slideshow_rounded,
        'zip' => Icons.folder_zip_rounded,
        'txt' => Icons.text_snippet_rounded,
        _ => Icons.insert_drive_file_rounded,
      };

  Color _colorForExt(String ext) => switch (ext) {
        'pdf' => const Color(0xFFE53935),
        'doc' || 'docx' => const Color(0xFF1565C0),
        'xls' || 'xlsx' => const Color(0xFF2E7D32),
        'ppt' || 'pptx' => const Color(0xFFE65100),
        'zip' => const Color(0xFF6A1B9A),
        _ => const Color(0xFF455A64),
      };

  @override
  Widget build(BuildContext context) {
    final ext = (msg.metadata?['ext'] as String? ?? '').toLowerCase();
    final sizeKb =
        msg.metadata?['size'] != null ? (msg.metadata!['size'] as int) ~/ 1024 : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[_Avatar(name: msg.senderName), const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(msg.senderName,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600)),
                  ),
                Container(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? const LinearGradient(
                            colors: [Color(0xFF7B1FA2), Color(0xFF1565C0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight)
                        : null,
                    color: isMe ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isMe
                            ? const Color(0x407B1FA2)
                            : Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.white.withOpacity(0.2)
                              : _colorForExt(ext).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_iconForExt(ext),
                            color: isMe ? Colors.white : _colorForExt(ext),
                            size: 24),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isMe
                                    ? Colors.white
                                    : const Color(0xFF212121),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sizeKb > 0 ? '${sizeKb}KB' : ext.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                color: isMe
                                    ? Colors.white.withOpacity(0.65)
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Text(
                    DateFormat('HH:mm').format(msg.createdAt),
                    style:
                        TextStyle(fontSize: 10, color: Colors.grey.shade400),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 6),
        ],
      ),
    );
  }
}

// ─── Location bubble ───────────────────────────────────────────────────────────
class _LocationBubble extends StatelessWidget {
  const _LocationBubble({required this.msg, required this.isMe});
  final ChatMessageModel msg;
  final bool isMe;

  Future<void> _openMaps(double lat, double lng) async {
    // Thử geo: URI trước (Android mở app bản đồ gốc)
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri);
        return;
      }
    } catch (_) {}

    // Fallback: mở Google Maps trên trình duyệt
    final webUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final lat = (msg.metadata?['lat'] as num?)?.toDouble() ?? 0;
    final lng = (msg.metadata?['lng'] as num?)?.toDouble() ?? 0;
    final accuracy = (msg.metadata?['accuracy'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[_Avatar(name: msg.senderName), const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(msg.senderName,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600)),
                  ),
                GestureDetector(
                  onTap: () => _openMaps(lat, lng),
                  child: Container(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.72),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isMe ? 20 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Placeholder bản đồ
                        Container(
                          height: 120,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Grid giả map
                              CustomPaint(
                                size: const Size(double.infinity, 120),
                                painter: _MapGridPainter(),
                              ),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                              color: Color(0x442E7D32),
                                              blurRadius: 12)
                                        ],
                                      ),
                                      child: const Icon(
                                          Icons.location_on_rounded,
                                          color: Color(0xFF2E7D32),
                                          size: 28),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.9),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: const Text('Nhấn để mở bản đồ',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF2E7D32),
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Tọa độ
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          child: Row(
                            children: [
                              const Icon(Icons.my_location_rounded,
                                  size: 16, color: Color(0xFF2E7D32)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF212121)),
                                    ),
                                    if (accuracy > 0)
                                      Text(
                                        'Độ chính xác: ±${accuracy.round()}m',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade500),
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.open_in_new_rounded,
                                  size: 14, color: Color(0xFF2E7D32)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3, right: 4, left: 4),
                  child: Text(
                    DateFormat('HH:mm').format(msg.createdAt),
                    style:
                        TextStyle(fontSize: 10, color: Colors.grey.shade400),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB2DFDB)
      ..strokeWidth = 1;
    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_MapGridPainter old) => false;
}

// ─── Poll bubble ──────────────────────────────────────────────────────────────
class _PollBubble extends StatelessWidget {
  const _PollBubble({required this.msg, required this.isMe});
  final ChatMessageModel msg;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<GroupChatController>();
    final meta = msg.metadata ?? {};
    final options = List<String>.from(meta['options'] ?? []);
    final rawVotes = (meta['votes'] as Map?) ?? {};
    final votes = rawVotes.map(
        (k, v) => MapEntry(k as String, List<String>.from(v ?? [])));
    final isClosed = meta['closed'] == true;
    final allowMultiple = meta['allowMultiple'] == true;
    final userId = ctrl.currentUserId;

    int totalVotes = 0;
    int? myVote;
    for (int i = 0; i < options.length; i++) {
      final list = votes['$i'] ?? [];
      totalVotes += list.length;
      if (list.contains(userId)) myVote = i;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[_Avatar(name: msg.senderName), const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(msg.senderName,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600)),
                  ),
                Container(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.82),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header poll
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF7B1FA2), Color(0xFFCE93D8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.poll_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                msg.content,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14),
                              ),
                            ),
                            if (isClosed)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(8)),
                                child: const Text('Đã đóng',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 10)),
                              ),
                          ],
                        ),
                      ),
                      // Options
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            ...options.asMap().entries.map((e) {
                              final idx = e.key;
                              final label = e.value;
                              final optVotes = votes['$idx']?.length ?? 0;
                              final pct = totalVotes > 0
                                  ? optVotes / totalVotes
                                  : 0.0;
                              final isSelected = allowMultiple
                                  ? (votes['$idx']?.contains(userId) ?? false)
                                  : myVote == idx;

                              return GestureDetector(
                                onTap: isClosed
                                    ? null
                                    : () => ctrl.votePoll(msg.msgId, idx),
                                child: Container(
                                  margin:
                                      const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFF3E5F5)
                                        : const Color(0xFFF8F9FB),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF7B1FA2)
                                          : Colors.grey.shade200,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            allowMultiple
                                                ? (isSelected
                                                    ? Icons.check_box_rounded
                                                    : Icons.check_box_outline_blank)
                                                : (isSelected
                                                    ? Icons.radio_button_checked
                                                    : Icons.radio_button_unchecked),
                                            size: 16,
                                            color: isSelected
                                                ? const Color(0xFF7B1FA2)
                                                : Colors.grey,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(label,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w700
                                                      : FontWeight.normal,
                                                  color: isSelected
                                                      ? const Color(
                                                          0xFF7B1FA2)
                                                      : const Color(
                                                          0xFF212121),
                                                )),
                                          ),
                                          Text(
                                            '$optVotes',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected
                                                    ? const Color(0xFF7B1FA2)
                                                    : Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: pct,
                                          minHeight: 4,
                                          backgroundColor:
                                              Colors.grey.shade200,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            isSelected
                                                ? const Color(0xFF7B1FA2)
                                                : const Color(0xFFCE93D8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            // Footer
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$totalVotes phiếu bầu',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500),
                                ),
                                Text(
                                  DateFormat('HH:mm')
                                      .format(msg.createdAt),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade400),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 6),
        ],
      ),
    );
  }
}

// ─── Poll text field helper ───────────────────────────────────────────────────
class _PollTextField extends StatelessWidget {
  const _PollTextField(
      {required this.controller, required this.hint, this.icon});
  final TextEditingController controller;
  final String hint;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: icon != null
              ? Icon(icon, size: 18, color: Colors.grey.shade400)
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: icon != null ? 12 : 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}

// ─── Call bubble ──────────────────────────────────────────────────────────────
class _CallBubble extends StatelessWidget {
  const _CallBubble({required this.msg, required this.isMe});
  final ChatMessageModel msg;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final meta = msg.metadata ?? {};
    final isVideo = meta['isVideo'] == true;
    final roomUrl = meta['roomUrl'] as String? ?? '';
    final status = meta['status'] as String? ?? 'ongoing';
    final isOngoing = status == 'ongoing';

    final Color primary =
        isVideo ? const Color(0xFF1565C0) : const Color(0xFF2E7D32);
    final Color light =
        isVideo ? const Color(0xFFE3F2FD) : const Color(0xFFE8F5E9);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: isOngoing ? primary.withOpacity(0.3) : Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 10,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            children: [
              // Header gradient
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isOngoing
                        ? [primary, primary.withOpacity(0.7)]
                        : [Colors.grey.shade400, Colors.grey.shade300],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(
                  children: [
                    // Animated ring khi đang gọi
                    if (isOngoing)
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.15),
                            ),
                          ),
                          Icon(
                            isVideo
                                ? Icons.videocam_rounded
                                : Icons.phone_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ],
                      )
                    else
                      Icon(
                        isVideo
                            ? Icons.videocam_off_rounded
                            : Icons.phone_missed_rounded,
                        color: Colors.white70,
                        size: 26,
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isVideo ? 'Cuộc gọi video' : 'Cuộc gọi thoại',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Row(children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: isOngoing
                                    ? const Color(0xFF69F0AE)
                                    : Colors.white38,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isOngoing ? 'Đang diễn ra' : 'Đã kết thúc',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    Text(
                      DateFormat('HH:mm').format(msg.createdAt),
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 10),
                    ),
                  ],
                ),
              ),

              // Body: người gọi + nút tham gia
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  children: [
                    Row(children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: light,
                        child: Text(
                          msg.senderName.isNotEmpty
                              ? msg.senderName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${msg.senderName} đã bắt đầu cuộc gọi',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600),
                        ),
                      ),
                    ]),
                    if (isOngoing && roomUrl.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          icon: Icon(
                            isVideo
                                ? Icons.videocam_rounded
                                : Icons.phone_rounded,
                            size: 18,
                          ),
                          label: Text(
                            isVideo ? 'Tham gia video call' : 'Tham gia cuộc gọi',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          onPressed: () {
                            final u = Get.find<AuthController>().currentUser;
                            final uName =
                                '${u?.firstName ?? ''} ${u?.lastName ?? ''}'
                                    .trim();
                            // Lấy callId từ roomUrl (phần cuối path)
                            final uri = Uri.tryParse(roomUrl);
                            final rawId = uri?.pathSegments.isNotEmpty == true
                                ? uri!.pathSegments.last
                                : 'room';
                            final callId =
                                rawId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CallScreen(
                                  roomUrl: roomUrl,
                                  isVideo: isVideo,
                                  groupName: msg.senderName,
                                  userName: uName.isEmpty ? 'Người dùng' : uName,
                                  userId: u?.id ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
                                  callId: callId.isEmpty ? 'vl24hroom' : callId,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Avatar nhỏ (bubble người khác) ──────────────────────────────────────────
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});
  final String name;

  static const _colors = [
    [Color(0xFF7B1FA2), Color(0xFFAB47BC)],
    [Color(0xFF1565C0), Color(0xFF42A5F5)],
    [Color(0xFF2E7D32), Color(0xFF66BB6A)],
    [Color(0xFFE65100), Color(0xFFFFB74D)],
    [Color(0xFF00695C), Color(0xFF4DB6AC)],
    [Color(0xFFC62828), Color(0xFFEF9A9A)],
  ];

  @override
  Widget build(BuildContext context) {
    final idx = name.isNotEmpty
        ? name.codeUnits.reduce((a, b) => a + b) % _colors.length
        : 0;
    final colorPair = _colors[idx];

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colorPair,
        ),
        boxShadow: [
          BoxShadow(
            color: colorPair[0].withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
