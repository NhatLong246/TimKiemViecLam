import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_chat_model.dart';
import '../models/chat_message_model.dart';
import '../models/user_model.dart';

class GroupChatService {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _groups => _db.collection('groupChats');

  // ─── Tạo group mới sau khi duyệt ứng viên ───────────────────────────────
  Future<String> createGroup({
    required String jobId,
    required String jobTitle,
    required String employerId,
    required List<String> memberIds,
  }) async {
    // Kiểm tra job đã có group chưa (duplicate check)
    final jobDoc = await _db.collection('jobPosts').doc(jobId).get();
    if (jobDoc.exists) {
      final existingGroupId = jobDoc.data()?['groupChatId'] as String?;
      if (existingGroupId != null && existingGroupId.isNotEmpty) {
        return existingGroupId;
      }
    }

    // Tạo group mới
    final ref = _groups.doc();
    final model = GroupChatModel(
      groupId: ref.id,
      jobId: jobId,
      jobTitle: jobTitle,
      employerId: employerId,
      memberIds: memberIds,
      createdAt: DateTime.now(),
    );

    await ref.set(model.toMap());

    // Cập nhật groupChatId vào jobPosts
    await _db.collection('jobPosts').doc(jobId).update({
      'groupChatId': ref.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Gửi tin nhắn hệ thống chào mừng
    await _sendSystemMessage(
      ref.id,
      'Nhóm chat đã được tạo. Chào mừng đến với $jobTitle!',
    );

    return ref.id;
  }

  // ─── Thêm thành viên vào group (khi duyệt thêm ứng viên) ────────────────
  Future<void> addMember(String groupId, String candidateId) async {
    await _groups.doc(groupId).update({
      'memberIds': FieldValue.arrayUnion([candidateId]),
    });
  }

  // ─── Gửi tin nhắn ────────────────────────────────────────────────────────
  Future<void> sendMessage(String groupId, ChatMessageModel message) async {
    await _groups
        .doc(groupId)
        .collection('messages')
        .add(message.toMap());
  }

  // ─── Stream tin nhắn real-time ────────────────────────────────────────────
  Stream<List<ChatMessageModel>> streamMessages(String groupId) {
    return _groups
        .doc(groupId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChatMessageModel.fromMap(d.data(), d.id))
            .toList());
  }

  // ─── Stream danh sách groups của Employer ────────────────────────────────
  // Không dùng orderBy cùng with where để tránh yêu cầu composite index
  // Thay vào đó sort trong memory
  Stream<List<GroupChatModel>> streamEmployerGroups(String employerId) {
    return _groups
        .where('employerId', isEqualTo: employerId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => GroupChatModel.fromMap(
                  d.data() as Map<String, dynamic>, d.id))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // ─── Lấy 1 group theo ID ─────────────────────────────────────────────────
  Future<GroupChatModel?> getGroup(String groupId) async {
    final doc = await _groups.doc(groupId).get();
    if (!doc.exists) return null;
    return GroupChatModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  // ─── Cập nhật trạng thái cuộc gọi ───────────────────────────────────────
  Future<void> updateCallStatus(
      String groupId, String msgId, String status) async {
    await _groups
        .doc(groupId)
        .collection('messages')
        .doc(msgId)
        .update({'metadata.status': status});
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
          (k, v) => MapEntry(k as String, List<String>.from(v ?? [])));

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
      return GroupChatModel.fromMap(
          doc.data() as Map<String, dynamic>, doc.id);
    });
  }

  // ─── Cập nhật ảnh đại diện nhóm (Base64) ─────────────────────────────────
  Future<void> updateGroupAvatar(String groupId, String base64) async {
    await _groups.doc(groupId).update({'groupAvatarBase64': base64});
  }

  // ─── Đặt biệt danh cho thành viên ────────────────────────────────────────
  Future<void> setNickname(
      String groupId, String userId, String nickname) async {
    await _groups
        .doc(groupId)
        .update({'nicknames.$userId': nickname});
  }

  // ─── Lấy thông tin thành viên từ Firestore ────────────────────────────────
  Future<List<UserModel>> getGroupMembers(List<String> memberIds) async {
    if (memberIds.isEmpty) return [];
    final futures =
        memberIds.map((id) => _db.collection('users').doc(id).get()).toList();
    final snaps = await Future.wait(futures);
    return snaps
        .where((s) => s.exists)
        .map((s) =>
            UserModel.fromMap(s.data() as Map<String, dynamic>))
        .toList();
  }

  // ─── Sửa nội dung tin nhắn ───────────────────────────────────────────────
  Future<void> editMessage(
      String groupId, String msgId, String newContent) async {
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
      String groupId, String query) async {
    if (query.trim().isEmpty) return [];
    final snap = await _groups
        .doc(groupId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .get();

    final lower = query.toLowerCase().trim();
    return snap.docs
        .map((d) => ChatMessageModel.fromMap(d.data(), d.id))
        .where((m) =>
            m.type == 'text' &&
            m.content.toLowerCase().contains(lower))
        .toList();
  }

  // ─── Bật / tắt thông báo nhóm cho 1 user ────────────────────────────────
  Future<void> toggleMute(
      String groupId, String userId, bool currentlyMuted) async {
    await _groups.doc(groupId).update({
      'mutedBy': currentlyMuted
          ? FieldValue.arrayRemove([userId])
          : FieldValue.arrayUnion([userId]),
    });
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

    // Xóa document nhóm
    await _groups.doc(groupId).delete();
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
}
