import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import '../data/models/group_chat_model.dart';
import '../data/models/chat_message_model.dart';
import '../data/services/group_chat_service.dart';
import '../controller/login_controller.dart';

class GroupChatController extends GetxController {
  final _service = GroupChatService();
  final _auth = Get.find<AuthController>();

  // ─── State ────────────────────────────────────────────────────────────────
  final groups = <GroupChatModel>[].obs;
  final messages = <ChatMessageModel>[].obs;
  final currentGroup = Rxn<GroupChatModel>();
  final isLoadingGroups = false.obs;
  final isSending = false.obs;
  final isUploading = false.obs;

  StreamSubscription<List<GroupChatModel>>? _groupsSub;
  StreamSubscription<List<ChatMessageModel>>? _messagesSub;
  StreamSubscription<GroupChatModel?>? _groupMetaSub; // live update cho 1 nhóm

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    final uid = _auth.currentUser?.id;
    if (uid != null && uid.isNotEmpty) {
      _listenGroups(uid);
    } else {
      // User model chưa load kịp → chờ rồi thử lại
      Future.delayed(const Duration(milliseconds: 800), () {
        final retryUid = _auth.currentUser?.id;
        if (retryUid != null && retryUid.isNotEmpty) {
          _listenGroups(retryUid);
        }
      });
    }
  }

  @override
  void onClose() {
    _groupsSub?.cancel();
    _messagesSub?.cancel();
    super.onClose();
  }

  // ─── Groups list ─────────────────────────────────────────────────────────
  void _listenGroups(String employerId) {
    isLoadingGroups.value = true;
    _groupsSub?.cancel();
    _groupsSub = _service.streamEmployerGroups(employerId).listen(
      (data) {
        groups.assignAll(data);
        isLoadingGroups.value = false;
      },
      onError: (e) {
        isLoadingGroups.value = false;
        Get.snackbar(
          'Lỗi tải nhóm chat',
          e.toString().length > 100
              ? '${e.toString().substring(0, 100)}...'
              : e.toString(),
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 6),
        );
      },
    );
  }

  // ─── Open a group → stream messages + stream group metadata (avatar…) ────
  void openGroup(GroupChatModel group) {
    currentGroup.value = group;
    messages.clear();

    // Fetch ngay lập tức để lấy avatar/data mới nhất
    _service.getGroup(group.groupId).then((latest) {
      if (latest != null) currentGroup.value = latest;
    });

    // Stream messages
    _messagesSub?.cancel();
    _messagesSub = _service.streamMessages(group.groupId).listen((data) {
      messages.assignAll(data);
    });

    // Stream group metadata (avatar, tên, thành viên, mutedBy…)
    _groupMetaSub?.cancel();
    _groupMetaSub = _service.streamGroup(group.groupId).listen((updated) {
      if (updated != null) currentGroup.value = updated;
    });
  }

  void closeGroup() {
    _messagesSub?.cancel();
    _groupMetaSub?.cancel();
    currentGroup.value = null;
    messages.clear();
  }

  // ─── Send message ─────────────────────────────────────────────────────────
  Future<void> sendText(String content) async {
    final groupId = currentGroup.value?.groupId;
    if (groupId == null || content.trim().isEmpty) return;

    isSending.value = true;
    final user = _auth.currentUser;
    final senderName =
        '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim();

    final msg = ChatMessageModel(
      msgId: '',
      senderId: user?.id ?? '',
      senderName: senderName.isEmpty ? 'Employer' : senderName,
      content: content.trim(),
      type: 'text',
      createdAt: DateTime.now(),
    );

    await _service.sendMessage(groupId, msg);
    isSending.value = false;
  }

  // ─── Gửi ảnh (Base64 → Firestore) ──────────────────────────────────────
  Future<void> sendImage(File file) async {
    final groupId = currentGroup.value?.groupId;
    if (groupId == null) return;

    isUploading.value = true;
    try {
      final bytes = await file.readAsBytes();

      // Giới hạn 700KB để không vượt 1MB/document Firestore
      if (bytes.lengthInBytes > 700 * 1024) {
        Get.snackbar(
          'Ảnh quá lớn',
          'Vui lòng chọn ảnh nhỏ hơn 700KB hoặc giảm chất lượng.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final ext = file.path.split('.').last.toLowerCase();
      final mime = (ext == 'png') ? 'image/png'
          : (ext == 'webp') ? 'image/webp'
          : 'image/jpeg';
      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';

      final user = _auth.currentUser;
      final senderName =
          '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim();

      final msg = ChatMessageModel(
        msgId: '',
        senderId: user?.id ?? '',
        senderName: senderName.isEmpty ? 'Employer' : senderName,
        content: '[Hình ảnh]',
        type: 'image',
        attachmentUrl: dataUrl,
        createdAt: DateTime.now(),
      );
      await _service.sendMessage(groupId, msg);
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể gửi ảnh: $e',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 5));
    } finally {
      isUploading.value = false;
    }
  }

  // ─── Gửi âm thanh (Base64 → Firestore) ──────────────────────────────────
  Future<void> sendAudio(File file, Duration duration) async {
    final groupId = currentGroup.value?.groupId;
    if (groupId == null) return;

    isUploading.value = true;
    try {
      final bytes = await file.readAsBytes();

      if (bytes.lengthInBytes > 700 * 1024) {
        Get.snackbar(
          'Ghi âm quá dài',
          'Tối đa khoảng 30 giây. Vui lòng thử lại.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final dataUrl = 'data:audio/mp4;base64,${base64Encode(bytes)}';
      final user = _auth.currentUser;
      final senderName =
          '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim();
      final totalSec = duration.inSeconds;
      final label =
          '${(totalSec ~/ 60).toString().padLeft(2, '0')}:${(totalSec % 60).toString().padLeft(2, '0')}';

      final msg = ChatMessageModel(
        msgId: '',
        senderId: user?.id ?? '',
        senderName: senderName.isEmpty ? 'Employer' : senderName,
        content: label,
        type: 'audio',
        attachmentUrl: dataUrl,
        createdAt: DateTime.now(),
      );
      await _service.sendMessage(groupId, msg);
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể gửi âm thanh: $e',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 5));
    } finally {
      isUploading.value = false;
    }
  }

  // ─── Gửi file (Base64 → Firestore) ──────────────────────────────────────
  Future<void> sendFile(File file, String fileName) async {
    final groupId = currentGroup.value?.groupId;
    if (groupId == null) return;

    isUploading.value = true;
    try {
      final bytes = await file.readAsBytes();
      const limitBytes = 500 * 1024; // 500KB cho file (nhỏ hơn ảnh)

      if (bytes.lengthInBytes > limitBytes) {
        Get.snackbar(
          'File quá lớn',
          'Tối đa 500KB. File này ${(bytes.lengthInBytes / 1024).round()}KB.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
        return;
      }

      final ext = fileName.contains('.')
          ? fileName.split('.').last.toLowerCase()
          : 'bin';
      final mime = _mimeFromExt(ext);
      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';

      final user = _auth.currentUser;
      final senderName =
          '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim();

      final msg = ChatMessageModel(
        msgId: '',
        senderId: user?.id ?? '',
        senderName: senderName.isEmpty ? 'Employer' : senderName,
        content: fileName,
        type: 'file',
        attachmentUrl: dataUrl,
        metadata: {'size': bytes.lengthInBytes, 'ext': ext},
        createdAt: DateTime.now(),
      );
      await _service.sendMessage(groupId, msg);
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể gửi file: $e',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isUploading.value = false;
    }
  }

  // ─── Gửi vị trí GPS (tọa độ đã xác nhận từ screen) ─────────────────────
  Future<void> sendLocation({
    required double lat,
    required double lng,
    double accuracy = 0,
  }) async {
    final groupId = currentGroup.value?.groupId;
    if (groupId == null) return;

    isUploading.value = true;
    try {
      final user = _auth.currentUser;
      final senderName =
          '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim();

      final msg = ChatMessageModel(
        msgId: '',
        senderId: user?.id ?? '',
        senderName: senderName.isEmpty ? 'Employer' : senderName,
        content: '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}',
        type: 'location',
        metadata: {'lat': lat, 'lng': lng, 'accuracy': accuracy},
        createdAt: DateTime.now(),
      );
      await _service.sendMessage(groupId, msg);
    } catch (e) {
      Get.snackbar('Lỗi', 'Không gửi được vị trí: $e',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isUploading.value = false;
    }
  }

  // ─── Tạo thăm dò ý kiến ──────────────────────────────────────────────────
  Future<void> createPoll({
    required String question,
    required List<String> options,
    bool allowMultiple = false,
  }) async {
    final groupId = currentGroup.value?.groupId;
    if (groupId == null) return;
    if (question.trim().isEmpty || options.length < 2) return;

    final user = _auth.currentUser;
    final senderName =
        '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim();

    final votes = {for (var i = 0; i < options.length; i++) '$i': <String>[]};

    final msg = ChatMessageModel(
      msgId: '',
      senderId: user?.id ?? '',
      senderName: senderName.isEmpty ? 'Employer' : senderName,
      content: question.trim(),
      type: 'poll',
      metadata: {
        'options': options.map((o) => o.trim()).toList(),
        'votes': votes,
        'closed': false,
        'allowMultiple': allowMultiple,
      },
      createdAt: DateTime.now(),
    );
    await _service.sendMessage(groupId, msg);
  }

  // ─── Vote poll ────────────────────────────────────────────────────────────
  Future<void> votePoll(String msgId, int optionIndex) async {
    final groupId = currentGroup.value?.groupId;
    final userId = _auth.currentUser?.id;
    if (groupId == null || userId == null) return;

    await _service.votePoll(
      groupId: groupId,
      msgId: msgId,
      optionIndex: optionIndex,
      userId: userId,
    );
  }

  String get currentUserId => _auth.currentUser?.id ?? '';

  // ─── Helper: xác định MIME type từ extension ─────────────────────────────
  String _mimeFromExt(String ext) => switch (ext) {
        'pdf' => 'application/pdf',
        'doc' || 'docx' => 'application/msword',
        'xls' || 'xlsx' => 'application/vnd.ms-excel',
        'ppt' || 'pptx' => 'application/vnd.ms-powerpoint',
        'txt' => 'text/plain',
        'zip' => 'application/zip',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        _ => 'application/octet-stream',
      };

  // ─── Gửi tin nhắn cuộc gọi ───────────────────────────────────────────────
  Future<void> sendCallMessage({
    required bool isVideo,
    required String roomUrl,
  }) async {
    final groupId = currentGroup.value?.groupId;
    if (groupId == null) return;

    final user = _auth.currentUser;
    final senderName =
        '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim();

    final msg = ChatMessageModel(
      msgId: '',
      senderId: user?.id ?? '',
      senderName: senderName.isEmpty ? 'Employer' : senderName,
      content: isVideo ? 'Cuộc gọi video' : 'Cuộc gọi thoại',
      type: 'call',
      metadata: {
        'isVideo': isVideo,
        'roomUrl': roomUrl,
        'status': 'ongoing', // ongoing | ended
        'startedAt': DateTime.now().millisecondsSinceEpoch,
      },
      createdAt: DateTime.now(),
    );
    await _service.sendMessage(groupId, msg);
  }

  Future<void> endCall(String msgId) async {
    final groupId = currentGroup.value?.groupId;
    if (groupId == null) return;
    await _service.updateCallStatus(groupId, msgId, 'ended');
  }

  Future<void> sendScheduleMessage(String scheduleContent) async {
    final groupId = currentGroup.value?.groupId;
    if (groupId == null) return;

    final user = _auth.currentUser;
    final senderName =
        '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim();

    final msg = ChatMessageModel(
      msgId: '',
      senderId: user?.id ?? '',
      senderName: senderName.isEmpty ? 'Employer' : senderName,
      content: scheduleContent,
      type: 'schedule',
      createdAt: DateTime.now(),
    );
    await _service.sendMessage(groupId, msg);
  }

  // ─── Sửa tin nhắn ────────────────────────────────────────────────────────
  Future<void> editMessage(String msgId, String newContent) async {
    final groupId = currentGroup.value?.groupId;
    if (groupId == null || newContent.trim().isEmpty) return;
    await _service.editMessage(groupId, msgId, newContent.trim());
  }

  // ─── Thu hồi / Xóa / Ghim ────────────────────────────────────────────────
  Future<void> recallMessage(String msgId) async {
    final groupId = currentGroup.value?.groupId;
    if (groupId == null) return;
    await _service.recallMessage(groupId, msgId);
  }

  Future<void> deleteMessage(String msgId) async {
    final groupId = currentGroup.value?.groupId;
    if (groupId == null) return;
    await _service.deleteMessage(groupId, msgId);
  }

  Future<void> pinMessage(String msgId) async {
    final groupId = currentGroup.value?.groupId;
    if (groupId == null) return;
    await _service.pinMessage(groupId, msgId);
  }

  // ─── Gửi tin nhắn với reply metadata ─────────────────────────────────────
  Future<void> sendTextWithReply(String content,
      {Map<String, dynamic>? replyTo}) async {
    final groupId = currentGroup.value?.groupId;
    if (groupId == null || content.trim().isEmpty) return;

    isSending.value = true;
    final user = _auth.currentUser;
    final senderName =
        '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim();

    final msg = ChatMessageModel(
      msgId: '',
      senderId: user?.id ?? '',
      senderName: senderName.isEmpty ? 'Employer' : senderName,
      content: content.trim(),
      type: 'text',
      metadata: replyTo != null ? {'replyTo': replyTo} : null,
      createdAt: DateTime.now(),
    );

    await _service.sendMessage(groupId, msg);
    isSending.value = false;
  }

  // ─── Create group (called when employer approves candidate) ───────────────
  Future<String> createOrGetGroup({
    required String jobId,
    required String jobTitle,
    required String employerId,
    required List<String> initialMembers,
  }) async {
    return _service.createGroup(
      jobId: jobId,
      jobTitle: jobTitle,
      employerId: employerId,
      memberIds: initialMembers,
    );
  }

  Future<void> addMember(String groupId, String candidateId) async {
    await _service.addMember(groupId, candidateId);
  }
}
