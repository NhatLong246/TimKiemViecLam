import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_chat_model.dart';
import 'messaging_service.dart';
import '../models/app_notification_model.dart';
import 'notification_service.dart';
import '../models/chat_message_model.dart';
import '../models/user_model.dart';
import '../../utils/chat_wallpaper_preferences.dart';

class GroupChatService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groupChats');

  /// Một nhóm chat duy nhất theo job — thêm ứng viên khi duyệt, không tạo chat 1-1.
  Future<String> ensureJobGroup({
    required String jobId,
    required String jobTitle,
    required String employerId,
    required String candidateId,
  }) async {
    if (jobId.isEmpty || employerId.isEmpty || candidateId.isEmpty) {
      throw ArgumentError('Thiếu jobId / employerId / candidateId');
    }

    final jobDoc = await _db.collection('jobPosts').doc(jobId).get();
    var groupId = (jobDoc.data()?['groupChatId'] ?? '').toString();

    if (groupId.isNotEmpty) {
      final gSnap = await _groups.doc(groupId).get();
      if (gSnap.exists) {
        final chatType = (gSnap.data()?['chatType'] ?? '').toString();
        if (chatType == 'group') {
          await _addMembers(groupId, employerId, candidateId);
          return groupId;
        }
      }
      groupId = '';
    }

    final byJob = await _groups
        .where('jobId', isEqualTo: jobId)
        .where('chatType', isEqualTo: 'group')
        .limit(1)
        .get();
    if (byJob.docs.isNotEmpty) {
      groupId = byJob.docs.first.id;
      await _addMembers(groupId, employerId, candidateId);
      await _db.collection('jobPosts').doc(jobId).update({
        'groupChatId': groupId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return groupId;
    }

    return createGroup(
      jobId: jobId,
      jobTitle: jobTitle,
      employerId: employerId,
      memberIds: [employerId, candidateId],
    );
  }

  Future<void> _addMembers(
    String groupId,
    String employerId,
    String candidateId,
  ) async {
    final wasNew = await _groups.doc(groupId).get().then((d) {
      if (!d.exists) return false;
      final members = List<String>.from(d.data()?['memberIds'] as List? ?? []);
      return !members.contains(candidateId);
    });

    await _groups.doc(groupId).update({
      'memberIds': FieldValue.arrayUnion([employerId, candidateId]),
      'chatType': 'group',
    });

    if (wasNew) {
      await _sendSystemMessage(
        groupId,
        'Thành viên mới đã tham gia nhóm chat.',
      );
    }
  }

  // ─── Tạo group mới sau khi duyệt ứng viên ───────────────────────────────
  Future<String> createGroup({
    required String jobId,
    required String jobTitle,
    required String employerId,
    required List<String> memberIds,
  }) async {
    final jobDoc = await _db.collection('jobPosts').doc(jobId).get();
    if (jobDoc.exists) {
      final existingGroupId = jobDoc.data()?['groupChatId'] as String?;
      if (existingGroupId != null && existingGroupId.isNotEmpty) {
        final g = await _groups.doc(existingGroupId).get();
        if (g.exists && (g.data()?['chatType'] ?? '') == 'group') {
          for (final id in memberIds) {
            await _addMembers(existingGroupId, employerId, id);
          }
          return existingGroupId;
        }
      }
    }

    final allMembers = <String>{
      employerId,
      ...memberIds,
    }.where((id) => id.isNotEmpty).toList();

    final ref = _groups.doc();
    await ref.set({
      'groupId': ref.id,
      'jobId': jobId,
      'jobTitle': jobTitle,
      'employerId': employerId,
      'memberIds': allMembers,
      'chatType': 'group',
      'nicknames': <String, String>{},
      'mutedBy': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageText': 'Nhóm chat đã được tạo. Chào mừng đến với $jobTitle!',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': 'system',
      'unreadCounts': <String, int>{},
    });

    await _db.collection('jobPosts').doc(jobId).update({
      'groupChatId': ref.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _sendSystemMessage(
      ref.id,
      'Nhóm chat đã được tạo. Chào mừng đến với $jobTitle!',
    );

    return ref.id;
  }

  // ─── Thêm thành viên vào group (khi duyệt thêm ứng viên) ────────────────
  Future<void> addMember(String groupId, String candidateId) async {
    final snap = await _groups.doc(groupId).get();
    if (!snap.exists) return;
    final employerId = (snap.data()?['employerId'] ?? '').toString();
    await _addMembers(groupId, employerId, candidateId);
  }

  // ─── Gửi tin nhắn ────────────────────────────────────────────────────────
  Future<void> sendMessage(String groupId, ChatMessageModel message) async {
    await _groups.doc(groupId).collection('messages').add(message.toMap());

    final senderId = message.senderId;
    if (senderId.isNotEmpty && senderId != 'system') {
      var preview = message.content.trim();
      if (preview.isEmpty) {
        preview = switch (message.type) {
          'image' => '[Hình ảnh]',
          'audio' => '[Tin thoại]',
          'file' => '[Tệp đính kèm]',
          'location' => '[Vị trí]',
          'call' => '[Cuộc gọi]',
          _ => '[Tin nhắn]',
        };
      }
      await MessagingService().recordOutgoingMessage(
        groupId: groupId,
        senderId: senderId,
        preview: preview,
      );
    }
  }

  // ─── Stream tin nhắn real-time ────────────────────────────────────────────
  Stream<List<ChatMessageModel>> streamMessages(String groupId) {
    return _groups
        .doc(groupId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ChatMessageModel.fromMap(d.data(), d.id))
              .toList(),
        );
  }

  // ─── Stream danh sách groups của Employer ────────────────────────────────
  // Không dùng orderBy cùng with where để tránh yêu cầu composite index
  // Thay vào đó sort trong memory
  Stream<List<GroupChatModel>> streamEmployerGroups(String employerId) {
    return _groups.where('employerId', isEqualTo: employerId).snapshots().map((
      snap,
    ) {
      final list =
          snap.docs
              .map(
                (d) => GroupChatModel.fromMap(
                  d.data() as Map<String, dynamic>,
                  d.id,
                ),
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ─── Lấy 1 group theo ID ─────────────────────────────────────────────────
  Future<List<GroupChatModel>> listEmployerGroups(String employerId) async {
    if (employerId.isEmpty) return [];
    final snap = await _groups.where('employerId', isEqualTo: employerId).get();
    return snap.docs
        .map(
          (d) => GroupChatModel.fromMap(d.data() as Map<String, dynamic>, d.id),
        )
        .toList();
  }

  /// Chỉ nhóm việc (`chatType: group`) — dùng cho điểm danh tự động.
  Future<List<GroupChatModel>> listEmployerJobGroups(String employerId) async {
    if (employerId.isEmpty) return [];
    final snap = await _groups
        .where('employerId', isEqualTo: employerId)
        .where('chatType', isEqualTo: 'group')
        .get();
    return snap.docs
        .map(
          (d) => GroupChatModel.fromMap(d.data() as Map<String, dynamic>, d.id),
        )
        .toList();
  }

  Future<GroupChatModel?> getGroup(String groupId) async {
    final doc = await _groups.doc(groupId).get();
    if (!doc.exists) return null;
    return GroupChatModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  // ─── Cập nhật trạng thái cuộc gọi ───────────────────────────────────────
  Future<void> updateCallStatus(
    String groupId,
    String msgId,
    String status,
  ) async {
    await _groups.doc(groupId).collection('messages').doc(msgId).update({
      'metadata.status': status,
    });
  }

  // ─── Cập nhật vote cho poll ───────────────────────────────────────────────
  Future<void> votePoll({
    required String groupId,
    required String msgId,
    required int optionIndex,
    required String userId,
  }) async {
    final msgRef = _groups.doc(groupId).collection('messages').doc(msgId);

    await _db.runTransaction((txn) async {
      final doc = await txn.get(msgRef);
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      final meta = Map<String, dynamic>.from(data['metadata'] ?? {});
      final allowMultiple = meta['allowMultiple'] == true;
      final rawVotes = meta['votes'] as Map? ?? {};
      final votes = rawVotes.map(
        (k, v) => MapEntry(k as String, List<String>.from(v ?? [])),
      );

      final key = '$optionIndex';
      votes.putIfAbsent(key, () => []);

      if (allowMultiple) {
        // Cho phép chọn nhiều: toggle option này
        if (votes[key]!.contains(userId)) {
          votes[key]!.remove(userId); // bỏ chọn
        } else {
          votes[key]!.add(userId); // thêm chọn
        }
      } else {
        // Chỉ 1 lựa chọn: xóa khỏi tất cả option khác trước
        for (final k in votes.keys) {
          if (k != key) votes[k]!.remove(userId);
        }
        if (votes[key]!.contains(userId)) {
          votes[key]!.remove(userId); // tap lại để bỏ
        } else {
          votes[key]!.add(userId);
        }
      }

      meta['votes'] = votes;
      txn.update(msgRef, {'metadata': meta});
    });
  }

  // ─── Stream 1 group theo ID (live update) ───────────────────────────────
  Stream<GroupChatModel?> streamGroup(String groupId) {
    return _groups.doc(groupId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return GroupChatModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    });
  }

  // ─── Cập nhật ảnh đại diện nhóm (Base64) ─────────────────────────────────
  Future<void> updateGroupAvatar(String groupId, String base64) async {
    await _groups.doc(groupId).update({'groupAvatarBase64': base64});
  }

  // ─── Hình nền hội thoại (chung cả nhóm) ───────────────────────────────────
  Future<void> saveGroupWallpaperPreset(
    String groupId,
    String presetId, {
    String? changedByName,
  }) async {
    await _groups.doc(groupId).update({
      'chatWallpaper': {
        'presetId': presetId,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    });
    final actor = _wallpaperActorName(changedByName);
    final label = ChatWallpaperPresets.labelFor(presetId);
    await _postSystemChatNotice(
      groupId,
      '$actor đã đổi hình nền hội thoại sang "$label".',
    );
  }

  Future<void> saveGroupWallpaperImage(
    String groupId,
    String base64, {
    String? changedByName,
  }) async {
    await _groups.doc(groupId).update({
      'chatWallpaper': {
        'imageBase64': base64,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    });
    final actor = _wallpaperActorName(changedByName);
    await _postSystemChatNotice(
      groupId,
      '$actor đã đặt hình nền hội thoại từ thư viện ảnh.',
    );
  }

  Future<void> clearGroupWallpaper(
    String groupId, {
    String? changedByName,
  }) async {
    await _groups.doc(groupId).update({'chatWallpaper': FieldValue.delete()});
    final actor = _wallpaperActorName(changedByName);
    await _postSystemChatNotice(
      groupId,
      '$actor đã đặt lại hình nền hội thoại mặc định.',
    );
  }

  String _wallpaperActorName(String? changedByName) {
    final name = (changedByName ?? '').trim();
    return name.isNotEmpty ? name : 'Một thành viên';
  }

  // ─── Đặt biệt danh cho thành viên ────────────────────────────────────────
  Future<void> setNickname(
    String groupId,
    String userId,
    String nickname, {
    String? memberDisplayName,
    String? setterDisplayName,
  }) async {
    final setter = (setterDisplayName ?? '').trim().isNotEmpty
        ? setterDisplayName!.trim()
        : 'Một thành viên';
    final target = (memberDisplayName ?? '').trim().isNotEmpty
        ? memberDisplayName!.trim()
        : 'thành viên';

    late final String notice;
    if (nickname.trim().isEmpty) {
      await _groups.doc(groupId).update({
        'nicknames.$userId': FieldValue.delete(),
      });
      notice = '$setter đã xóa biệt danh của $target.';
    } else {
      final nick = nickname.trim();
      await _groups.doc(groupId).update({'nicknames.$userId': nick});
      notice = '$setter đã đặt biệt danh "$nick" cho $target.';
    }

    await _postSystemChatNotice(groupId, notice);
  }

  /// NTD nhắc điểm danh — chỉ gửi thông báo cho nhân viên (không đăng chat nhóm).
  Future<void> sendAttendanceRequest({
    required String groupId,
    required String jobId,
    required String attendanceId,
    required String targetUserId,
    required String targetName,
    required bool isCheckIn,
    required String expectedStartTime,
    bool allowDuplicate = false,
  }) async {
    final phase = isCheckIn ? 'check_in' : 'check_out';
    final label = isCheckIn ? 'đầu ca' : 'cuối ca';
    final name = targetName.isNotEmpty ? targetName : 'Bạn';

    final notifications = NotificationService();
    if (!allowDuplicate &&
        await notifications.hasRecentAttendanceRequest(
          userId: targetUserId,
          jobId: jobId,
          phase: phase,
        )) {
      return;
    }

    await notifications.sendToUser(
      userId: targetUserId,
      title: 'Điểm danh $label',
      body:
          'Xin chào $name, vui lòng chụp ảnh điểm danh $label (trong 15 phút). '
          'Nhấn thông báo để mở màn điểm danh.',
      category: NotificationCategory.job,
      data: {
        'groupId': groupId,
        'attendanceId': attendanceId,
        'phase': phase,
        'jobId': jobId,
        'expectedStartTime': expectedStartTime,
        'type': 'attendance_request',
      },
    );
  }

  Future<void> sendAttendanceNotify(String groupId, String content) async {
    await _postSystemChatNotice(groupId, content);
  }

  /// Tin hệ thống trong khung chat + cập nhật dòng xem trước hội thoại.
  Future<void> _postSystemChatNotice(String groupId, String content) async {
    await _sendSystemMessage(groupId, content);
    final preview = content.length > 80
        ? '${content.substring(0, 80)}…'
        : content;
    await MessagingService().recordOutgoingMessage(
      groupId: groupId,
      senderId: 'system',
      preview: preview,
    );
  }

  /// Đăng lịch làm việc (workSchedules) ra khung chat nhóm.
  Future<void> postWorkScheduleToChat({
    required String groupId,
    required String jobTitle,
    required String date,
    required String shiftStart,
    required String shiftEnd,
    required String generalContent,
    required List<Map<String, String>> memberTasks,
  }) async {
    final tasksText = memberTasks
        .where((t) => (t['content'] ?? '').trim().isNotEmpty)
        .map((t) => '• ${t['name']}: ${t['content']}')
        .join('\n');
    final content = StringBuffer()
      ..writeln('📋 Phân công công việc · $jobTitle')
      ..writeln('Ngày $date · Ca $shiftStart – $shiftEnd');
    if (generalContent.trim().isNotEmpty) {
      content.writeln(generalContent.trim());
    }
    if (tasksText.isNotEmpty) content.writeln(tasksText);

    await _groups.doc(groupId).collection('messages').add({
      'senderId': 'system',
      'senderName': 'Phân công CV',
      'content': content.toString().trim(),
      'type': 'schedule',
      'metadata': {
        'jobTitle': jobTitle,
        'date': date,
        'startTime': shiftStart,
        'endTime': shiftEnd,
        'source': 'work_schedule',
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    await MessagingService().recordOutgoingMessage(
      groupId: groupId,
      senderId: 'system',
      preview: 'Phân công $date · $shiftStart–$shiftEnd',
    );
  }

  /// Gửi thông báo phân công riêng cho từng nhân viên (không gửi NTD).
  Future<int> notifyWorkAssignmentToMembers({
    required String groupId,
    required String jobTitle,
    required String date,
    required String shiftStart,
    required String shiftEnd,
    required String generalContent,
    required List<Map<String, String>> memberTasks,
    required String employerId,
  }) async {
    var sent = 0;
    for (final t in memberTasks) {
      final userId = (t['userId'] ?? '').toString();
      if (userId.isEmpty || userId == employerId) continue;

      final name = (t['name'] ?? 'Bạn').toString();
      final task = (t['content'] ?? '').trim();
      final body = StringBuffer()
        ..writeln('Xin chào $name, bạn có phân công mới.')
        ..writeln('$jobTitle · ngày $date')
        ..writeln('Ca làm: $shiftStart – $shiftEnd');
      if (generalContent.trim().isNotEmpty) {
        body.writeln('Yêu cầu chung: ${generalContent.trim()}');
      }
      if (task.isNotEmpty) {
        body.writeln('Nhiệm vụ của bạn: $task');
      } else {
        body.writeln('Nhấn thông báo để xem phân công.');
      }

      await NotificationService().sendToUser(
        userId: userId,
        title: 'Phân công công việc',
        body: body.toString().trim(),
        category: NotificationCategory.job,
        data: {
          'groupId': groupId,
          'date': date,
          'type': 'work_assignment',
          'shiftStart': shiftStart,
          'shiftEnd': shiftEnd,
        },
      );
      sent++;
    }
    return sent;
  }

  // ─── Lấy thông tin thành viên từ Firestore ────────────────────────────────
  Future<List<UserModel>> getGroupMembers(List<String> memberIds) async {
    if (memberIds.isEmpty) return [];
    final futures = memberIds
        .map((id) => _db.collection('users').doc(id).get())
        .toList();
    final snaps = await Future.wait(futures);
    return snaps
        .where((s) => s.exists)
        .map((s) => UserModel.fromMap(s.data() as Map<String, dynamic>))
        .toList();
  }

  // ─── Sửa nội dung tin nhắn ───────────────────────────────────────────────
  Future<void> editMessage(
    String groupId,
    String msgId,
    String newContent,
  ) async {
    await _groups.doc(groupId).collection('messages').doc(msgId).update({
      'content': newContent,
      'edited': true,
    });
  }

  // ─── Thu hồi tin nhắn (chỉ đổi content) ─────────────────────────────────
  Future<void> recallMessage(String groupId, String msgId) async {
    await _groups.doc(groupId).collection('messages').doc(msgId).update({
      'content': 'Tin nhắn đã được thu hồi',
      'type': 'recalled',
    });
  }

  // ─── Xóa tin nhắn (xóa hẳn document) ────────────────────────────────────
  Future<void> deleteMessage(String groupId, String msgId) async {
    await _groups.doc(groupId).collection('messages').doc(msgId).delete();
  }

  // ─── Ghim / bỏ ghim tin nhắn ─────────────────────────────────────────────
  Future<void> pinMessage(String groupId, String msgId) async {
    await _groups.doc(groupId).update({
      'pinnedMsgIds': FieldValue.arrayUnion([msgId]),
    });
  }

  Future<void> unpinMessage(String groupId, String msgId) async {
    await _groups.doc(groupId).update({
      'pinnedMsgIds': FieldValue.arrayRemove([msgId]),
    });
  }

  // ─── Tìm kiếm tin nhắn theo từ khóa ──────────────────────────────────────
  Future<List<ChatMessageModel>> searchMessages(
    String groupId,
    String query,
  ) async {
    if (query.trim().isEmpty) return [];
    final snap = await _groups
        .doc(groupId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .get();

    final lower = query.toLowerCase().trim();
    return snap.docs.map((d) => ChatMessageModel.fromMap(d.data(), d.id)).where(
      (m) {
        if (m.content.toLowerCase().contains(lower)) return true;
        if (m.type == 'schedule' && m.content.toLowerCase().contains(lower)) {
          return true;
        }
        return false;
      },
    ).toList();
  }

  // ─── Bật / tắt thông báo nhóm cho 1 user ────────────────────────────────
  Future<void> toggleMute(
    String groupId,
    String userId,
    bool currentlyMuted,
  ) async {
    await _groups.doc(groupId).update({
      'mutedBy': currentlyMuted
          ? FieldValue.arrayRemove([userId])
          : FieldValue.arrayUnion([userId]),
    });
  }

  // ─── Rời nhóm: gỡ user khỏi memberIds (không xóa nhóm) ───────────────────
  Future<void> leaveGroup(String groupId, String userId) async {
    final ref = _groups.doc(groupId);
    final snap = await ref.get();
    if (!snap.exists) return;

    await ref.update({
      'memberIds': FieldValue.arrayRemove([userId]),
      'mutedBy': FieldValue.arrayRemove([userId]),
    });
    await _removeMemberFromWorkSchedules(groupId, userId);
    await _sendSystemMessage(groupId, 'Một thành viên đã rời khỏi nhóm');
  }

  Future<void> _removeMemberFromWorkSchedules(
    String groupId,
    String userId,
  ) async {
    final snap = await _db
        .collection('workSchedules')
        .where('groupId', isEqualTo: groupId)
        .get();
    if (snap.docs.isEmpty) return;

    WriteBatch batch = _db.batch();
    var opCount = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final rawTasks = data['tasks'] as List? ?? const [];
      final keptTasks = rawTasks.where((task) {
        if (task is! Map) return true;
        return (task['userId'] ?? '').toString() != userId;
      }).toList();
      if (keptTasks.length == rawTasks.length) continue;
      batch.update(doc.reference, {
        'tasks': keptTasks,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      opCount++;
      if (opCount >= 400) {
        await batch.commit();
        batch = _db.batch();
        opCount = 0;
      }
    }
    if (opCount > 0) await batch.commit();
  }

  // ─── Giải tán nhóm: xóa tất cả messages rồi xóa group ───────────────────
  Future<void> disbandGroup(String groupId) async {
    final msgCol = _groups.doc(groupId).collection('messages');

    // Xóa messages theo từng batch (Firestore giới hạn 500 ops/batch)
    WriteBatch batch = _db.batch();
    int opCount = 0;
    QuerySnapshot snap;

    do {
      snap = await msgCol.limit(400).get();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
        opCount++;
        if (opCount >= 400) {
          await batch.commit();
          batch = _db.batch();
          opCount = 0;
        }
      }
    } while (snap.docs.length == 400);

    if (opCount > 0) await batch.commit();

    await _deleteWorkSchedulesForGroup(groupId);

    // Xóa document nhóm
    await _groups.doc(groupId).delete();
  }

  Future<void> _deleteWorkSchedulesForGroup(String groupId) async {
    final snap = await _db
        .collection('workSchedules')
        .where('groupId', isEqualTo: groupId)
        .get();
    if (snap.docs.isEmpty) return;

    WriteBatch batch = _db.batch();
    var opCount = 0;
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
      opCount++;
      if (opCount >= 400) {
        await batch.commit();
        batch = _db.batch();
        opCount = 0;
      }
    }
    if (opCount > 0) await batch.commit();
  }

  // ─── Private: gửi tin nhắn hệ thống ─────────────────────────────────────
  Future<void> _sendSystemMessage(String groupId, String content) async {
    await _groups.doc(groupId).collection('messages').add({
      'senderId': 'system',
      'senderName': 'Hệ thống',
      'content': content,
      'type': 'system',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Nhóm đã giải tán mà user tham gia — dùng cho khiếu nại sau giải tán.
  Future<List<GroupChatModel>> listDissolvedGroupsForUser(String uid) async {
    final snap = await _groups
        .where('memberIds', arrayContains: uid)
        .limit(60)
        .get();
    final list = <GroupChatModel>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final chatType = (data['chatType'] ?? 'group').toString();
      if (chatType != 'group') continue;
      final status = (data['status'] as String?) ?? 'active';
      if (status != 'closed') continue;
      list.add(GroupChatModel.fromMap(data, doc.id));
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
}
