import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/app_notification_model.dart';
import '../models/attendance_model.dart';
import '../models/messaging_models.dart';
import 'attendance_service.dart';
import '../../utils/attendance_capture_helper.dart';
import 'group_chat_service.dart';
import 'notification_service.dart';

class MessagingService {
  final NotificationService _notifications = NotificationService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const _groups = 'groupChats';
  static const _messages = 'messages';

  String? get _uid => _auth.currentUser?.uid;

  String _dateKey(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

  String _timeKey(DateTime dt) => DateFormat('HH:mm').format(dt);

  Future<Map<String, ChatParticipant>> fetchParticipants(Set<String> uids) async {
    final result = <String, ChatParticipant>{};
    if (uids.isEmpty) return result;

    final list = uids.where((id) => id.isNotEmpty && id != 'system').toList();
    for (var i = 0; i < list.length; i += 30) {
      final chunk = list.sublist(
        i,
        i + 30 > list.length ? list.length : i + 30,
      );
      final snap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final d = doc.data();
        final first = (d['firstName'] as String?) ?? '';
        final last = (d['lastName'] as String?) ?? '';
        var name = '$first $last'.trim();
        if (name.isEmpty) {
          name = (d['companyName'] as String?)?.trim() ?? 'Người dùng';
        }
        result[doc.id] = ChatParticipant(
          uid: doc.id,
          name: name,
          avatarUrl: d['avatarUrl'] as String?,
          role: (d['role'] ?? 'candidate').toString(),
        );
      }
    }
    return result;
  }

  Future<void> syncChatsFromAcceptedApplications(String uid, String role) async {
    Query<Map<String, dynamic>> query;
    if (role == 'employer') {
      query = _db
          .collection('applications')
          .where('employerId', isEqualTo: uid)
          .where('status', isEqualTo: 'accepted');
    } else {
      query = _db
          .collection('applications')
          .where('candidateId', isEqualTo: uid)
          .where('status', isEqualTo: 'accepted');
    }

    final apps = await query.get();
    final groupChat = GroupChatService();
    for (final doc in apps.docs) {
      final d = doc.data();
      final jobId = (d['jobId'] ?? '').toString();
      final candidateId = (d['candidateId'] ?? '').toString();
      final employerId = (d['employerId'] ?? '').toString();
      if (jobId.isEmpty || candidateId.isEmpty || employerId.isEmpty) continue;

      final jobSnap = await _db.collection('jobPosts').doc(jobId).get();
      if (!jobSnap.exists) continue;
      final title = (jobSnap.data()?['title'] ?? 'Công việc').toString();

      await groupChat.ensureJobGroup(
        jobId: jobId,
        jobTitle: title,
        employerId: employerId,
        candidateId: candidateId,
      );
    }
  }

  /// Chat 1-1 đúng nghĩa: đúng 2 người (NTD + một ứng viên), không phải nhóm nhân viên.
  bool _isPrivateDirectChat(
    Map<String, dynamic> data, {
    required String employerId,
    required String candidateId,
  }) {
    final chatType = (data['chatType'] ?? '').toString();
    if (chatType == 'group') return false;

    final members = (data['memberIds'] as List?)
            ?.map((e) => e.toString())
            .where((id) => id.isNotEmpty)
            .toSet() ??
        {};
    if (members.length != 2) return false;
    return members.contains(employerId) && members.contains(candidateId);
  }

  Future<String> getOrCreateDirectChat({
    required String jobId,
    required String jobTitle,
    required String employerId,
    required String candidateId,
    String? applicationId,
    /// Không dùng lại document nhóm việc đang mở (tránh nhầm nhóm ↔ chat riêng).
    String? excludeGroupId,
  }) async {
    if (employerId.isEmpty || candidateId.isEmpty || employerId == candidateId) {
      throw ArgumentError('Thiếu hoặc trùng employerId / candidateId');
    }

    final existing = await _db
        .collection(_groups)
        .where('jobId', isEqualTo: jobId)
        .where('employerId', isEqualTo: employerId)
        .where('candidateId', isEqualTo: candidateId)
        .where('chatType', isEqualTo: 'direct')
        .get();

    for (final doc in existing.docs) {
      if (excludeGroupId != null && doc.id == excludeGroupId) continue;
      final data = doc.data();
      if (_isPrivateDirectChat(
        data,
        employerId: employerId,
        candidateId: candidateId,
      )) {
        return doc.id;
      }
    }

    final ref = _db.collection(_groups).doc();
    final memberIds = [employerId, candidateId];

    await ref.set({
      'groupId': ref.id,
      'jobId': jobId,
      'jobTitle': jobTitle,
      'employerId': employerId,
      'candidateId': candidateId,
      ...(applicationId == null ? const {} : {'applicationId': applicationId}),
      'memberIds': memberIds,
      'chatType': 'direct',
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageText': 'Bắt đầu trò chuyện riêng về "$jobTitle"',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': 'system',
      'unreadCounts': {},
    });

    await _sendMessageRaw(
      ref.id,
      senderId: 'system',
      type: 'system',
      content:
          'Bạn có thể trao đổi tin nhắn, gửi ảnh, file, vị trí hoặc gọi thoại/video tại đây.',
    );

    return ref.id;
  }

  static String peerPairKey(
    String jobId,
    String memberAId,
    String memberBId,
  ) {
    final sorted = [memberAId, memberBId]..sort();
    return '${jobId}_${sorted[0]}_${sorted[1]}';
  }

  /// Chat 1-1 giữa hai thành viên cùng nhóm việc (không phải cặp NTD–ứng viên).
  Future<String> getOrCreatePeerChat({
    required String jobId,
    required String jobTitle,
    required String employerId,
    required String memberAId,
    required String memberBId,
    String? parentGroupId,
    String? excludeGroupId,
  }) async {
    if (memberAId.isEmpty || memberBId.isEmpty || memberAId == memberBId) {
      throw ArgumentError('Cần hai thành viên khác nhau');
    }

    final pairKey = peerPairKey(jobId, memberAId, memberBId);

    final existing = await _db
        .collection(_groups)
        .where('peerPairKey', isEqualTo: pairKey)
        .get();

    for (final doc in existing.docs) {
      if (excludeGroupId != null && doc.id == excludeGroupId) continue;
      final members = (doc.data()['memberIds'] as List?)
              ?.map((e) => e.toString())
              .where((id) => id.isNotEmpty)
              .toSet() ??
          {};
      if (members.contains(memberAId) && members.contains(memberBId)) {
        final sortedPair = [memberAId, memberBId]..sort();
        if (members.length > 2 ||
            (doc.data()['chatType'] ?? '').toString() != 'peer') {
          await doc.reference.update({
            'memberIds': sortedPair,
            'chatType': 'peer',
          });
        }
        return doc.id;
      }
    }

    final ref = _db.collection(_groups).doc();
    final memberIds = [memberAId, memberBId]..sort();

    await ref.set({
      'groupId': ref.id,
      'jobId': jobId,
      'jobTitle': jobTitle,
      'employerId': employerId,
      'memberIds': memberIds,
      'peerPairKey': pairKey,
      'chatType': 'peer',
      ...(parentGroupId == null ? const {} : {'parentGroupId': parentGroupId}),
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageText': 'Bắt đầu trò chuyện riêng',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': 'system',
      'unreadCounts': {},
    });

    await _sendMessageRaw(
      ref.id,
      senderId: 'system',
      type: 'system',
      content:
          'Cuộc trò chuyện riêng giữa hai thành viên trong nhóm "$jobTitle".',
    );

    return ref.id;
  }

  /// Hội thoại user là thành viên (`memberIds`).
  Stream<List<ConversationThread>> streamConversations(String uid) {
    return _db
        .collection(_groups)
        .where('memberIds', arrayContains: uid)
        .snapshots()
        .asyncMap((snap) => _buildThreadsFromSnapshot(snap, uid));
  }

  /// NTD: thêm nhóm theo `employerId` (nhóm cũ có thể thiếu NTD trong memberIds).
  Stream<List<ConversationThread>> streamConversationsForEmployer(String uid) {
    return _db
        .collection(_groups)
        .where('employerId', isEqualTo: uid)
        .snapshots()
        .asyncMap((snap) => _buildThreadsFromSnapshot(snap, uid));
  }

  Future<List<ConversationThread>> _buildThreadsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
    String uid,
  ) async {
    final threads = <ConversationThread>[];
    final peerIds = <String>{};

    for (final doc in snap.docs) {
      final data = doc.data();
      final members = (data['memberIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final peerId = _resolvePeerId(
        members: members,
        currentUid: uid,
        employerId: (data['employerId'] ?? '').toString(),
        candidateId: (data['candidateId'] ?? '').toString(),
      );
      if (peerId.isNotEmpty) peerIds.add(peerId);
    }

    final profiles = await fetchParticipants(peerIds);

    for (final doc in snap.docs) {
      final data = doc.data();
      final members = (data['memberIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final peerId = _resolvePeerId(
        members: members,
        currentUid: uid,
        employerId: (data['employerId'] ?? '').toString(),
        candidateId: (data['candidateId'] ?? '').toString(),
      );
      final profile = profiles[peerId];
      threads.add(
        ConversationThread.fromMap(
          doc.id,
          data,
          currentUid: uid,
          peerName: profile?.name ?? 'Người dùng',
          peerAvatarUrl: profile?.avatarUrl,
        ),
      );
    }

    threads.sort((a, b) {
      final da = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return threads;
  }

  /// Gọi sau mỗi tin gửi (job chat hoặc group chat NTD) — cập nhật badge + thông báo chuông.
  Future<void> recordOutgoingMessage({
    required String groupId,
    required String senderId,
    required String preview,
  }) =>
      _updatePreview(groupId, preview, senderId);

  Future<void> markConversationRead(String groupId, String userId) async {
    if (groupId.isEmpty || userId.isEmpty) return;
    final ref = _db.collection(_groups).doc(groupId);
    final payload = {
      'unreadCounts.$userId': 0,
      'lastReadAt.$userId': FieldValue.serverTimestamp(),
    };
    try {
      await ref.update(payload);
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        await ref.set(payload, SetOptions(merge: true));
        return;
      }
      await ref.set(payload, SetOptions(merge: true));
    }
  }

  Stream<List<JobChatMessage>> streamMessages(String groupId) {
    return _db
        .collection(_groups)
        .doc(groupId)
        .collection(_messages)
        .orderBy('createdAt', descending: true)
        .limit(120)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => JobChatMessage.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<ConversationThread?> getThread(String groupId, String currentUid) async {
    final doc = await _db.collection(_groups).doc(groupId).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    final members = (data['memberIds'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final peerId = _resolvePeerId(
      members: members,
      currentUid: currentUid,
      employerId: (data['employerId'] ?? '').toString(),
      candidateId: (data['candidateId'] ?? '').toString(),
    );
    final profiles = await fetchParticipants({peerId});
    final profile = profiles[peerId];
    return ConversationThread.fromMap(
      doc.id,
      data,
      currentUid: currentUid,
      peerName: profile?.name ?? 'Người dùng',
      peerAvatarUrl: profile?.avatarUrl,
    );
  }

  Future<void> sendText(
    String groupId,
    String text, {
    Map<String, dynamic>? replyTo,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Chưa đăng nhập');
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await _sendMessageRaw(
      groupId,
      senderId: uid,
      type: 'text',
      content: trimmed,
      metadata: replyTo != null ? {'replyTo': replyTo} : null,
    );
    await _updatePreview(groupId, trimmed, uid);
  }

  String _resolvePeerId({
    required List<String> members,
    required String currentUid,
    required String employerId,
    required String candidateId,
  }) {
    for (final id in members) {
      if (id.isNotEmpty && id != currentUid) return id;
    }
    if (candidateId.isNotEmpty && candidateId != currentUid) return candidateId;
    if (employerId.isNotEmpty && employerId != currentUid) return employerId;
    return '';
  }

  Future<void> toggleMessageReaction({
    required String groupId,
    required String msgId,
    required String emoji,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Chưa đăng nhập');

    final ref = _db.collection(_groups).doc(groupId).collection(_messages).doc(msgId);
    final snap = await ref.get();
    if (!snap.exists) return;

    final data = snap.data() ?? {};
    final reactions = Map<String, dynamic>.from(
      (data['reactions'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? {},
    );

    if (reactions[uid]?.toString() == emoji) {
      reactions.remove(uid);
    } else {
      reactions[uid] = emoji;
    }

    await ref.update({'reactions': reactions});
  }

  Future<String> sendCallMessage({
    required String groupId,
    required bool isVideo,
    required String roomUrl,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Chưa đăng nhập');

    final ref = _db.collection(_groups).doc(groupId).collection(_messages).doc();
    final content = isVideo ? 'Cuộc gọi video' : 'Cuộc gọi thoại';
    await ref.set({
      'msgId': ref.id,
      'senderId': uid,
      'type': 'call',
      'content': content,
      'metadata': {
        'isVideo': isVideo,
        'roomUrl': roomUrl,
        'status': 'ongoing',
        'startedAt': DateTime.now().millisecondsSinceEpoch,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _updatePreview(groupId, content, uid);

    try {
      final snap = await _db.collection(_groups).doc(groupId).get();
      if (snap.exists) {
        final data = snap.data() ?? {};
        final members = (data['memberIds'] as List?)?.map((e) => e.toString()).toList() ?? [];
        final employerId = (data['employerId'] ?? '').toString();
        
        final recipientIds = <String>{...members};
        if (employerId.isNotEmpty) recipientIds.add(employerId);
        recipientIds.remove(uid);

        final senderProfiles = await fetchParticipants({uid});
        final callerName = senderProfiles[uid]?.name ?? 'Ai đó';
        final jobTitle = (data['jobTitle'] ?? '').toString();
        final finalCallerName = data['chatType'] == 'group' ? '$callerName (Nhóm $jobTitle)' : callerName;

        for (final recipientId in recipientIds) {
          await _notifications.notifyIncomingCall(
            recipientId: recipientId,
            groupId: groupId,
            callerName: finalCallerName,
            isVideo: isVideo,
            roomUrl: roomUrl,
          );
        }
      }
    } catch (e) {
      debugPrint('Lỗi gửi thông báo cuộc gọi: $e');
    }

    return ref.id;
  }

  Future<void> updateCallStatus({
    required String groupId,
    required String msgId,
    required String status,
  }) async {
    await _db
        .collection(_groups)
        .doc(groupId)
        .collection(_messages)
        .doc(msgId)
        .update({'metadata.status': status});
  }

  Future<void> deleteMessage({
    required String groupId,
    required String msgId,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Chưa đăng nhập');

    final ref = _db.collection(_groups).doc(groupId).collection(_messages).doc(msgId);
    final snap = await ref.get();
    if (!snap.exists) return;

    final senderId = (snap.data()?['senderId'] ?? '').toString();
    if (senderId != uid) {
      throw Exception('Chỉ xóa được tin nhắn của bạn');
    }
    await ref.delete();
    await _refreshGroupPreviewFromLatestMessage(groupId);
  }

  Future<void> editMessage({
    required String groupId,
    required String msgId,
    required String newContent,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Chưa đăng nhập');

    final ref = _db.collection(_groups).doc(groupId).collection(_messages).doc(msgId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('Không tìm thấy tin nhắn');

    final data = snap.data() ?? {};
    if ((data['senderId'] ?? '').toString() != uid) {
      throw Exception('Chỉ sửa được tin nhắn của bạn');
    }
    if ((data['type'] ?? 'text').toString() != 'text') {
      throw Exception('Chỉ sửa được tin nhắn văn bản');
    }

    final trimmed = newContent.trim();
    if (trimmed.isEmpty) {
      throw Exception('Nội dung tin nhắn không được để trống');
    }

    await ref.update({
      'content': trimmed,
      'edited': true,
    });
    await _refreshGroupPreviewFromLatestMessage(groupId);
  }

  Future<void> recallMessage({
    required String groupId,
    required String msgId,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Chưa đăng nhập');

    final ref = _db.collection(_groups).doc(groupId).collection(_messages).doc(msgId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('Không tìm thấy tin nhắn');

    if ((snap.data()?['senderId'] ?? '').toString() != uid) {
      throw Exception('Chỉ thu hồi được tin nhắn của bạn');
    }

    await ref.update({
      'content': 'Tin nhắn đã được thu hồi',
      'type': 'recalled',
    });
    await _refreshGroupPreviewFromLatestMessage(groupId);
  }

  Future<void> pinMessage({
    required String groupId,
    required String msgId,
  }) async {
    await _db.collection(_groups).doc(groupId).update({
      'pinnedMsgIds': FieldValue.arrayUnion([msgId]),
    });
  }

  Future<void> unpinMessage({
    required String groupId,
    required String msgId,
  }) async {
    await _db.collection(_groups).doc(groupId).update({
      'pinnedMsgIds': FieldValue.arrayRemove([msgId]),
    });
  }

  Future<void> checkInShift({
    required String groupId,
    required String jobId,
    required String employerId,
    required String candidateId,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Chưa đăng nhập');
    if (uid != candidateId) {
      throw Exception('Chỉ ứng viên mới điểm danh đầu ca');
    }

    final now = DateTime.now();
    final date = _dateKey(now);
    final time = _timeKey(now);

    final existing = await _findTodayAttendance(jobId, date);
    if (_hasCheckIn(existing, candidateId)) {
      throw Exception('Bạn đã điểm danh đầu ca hôm nay');
    }

    final attendanceId = await _upsertAttendanceRecord(
      existing: existing,
      jobId: jobId,
      groupId: groupId,
      employerId: employerId,
      date: date,
      candidateId: candidateId,
      checkInTime: time,
      checkInAt: now,
    );

    await _notifyEmployerAttendanceResult(
      employerId: employerId,
      groupId: groupId,
      jobId: jobId,
      attendanceId: attendanceId,
      candidateName: 'Nhân viên',
      isCheckIn: true,
      timeLabel: time,
    );
  }

  Future<void> checkOutShift({
    required String groupId,
    required String jobId,
    required String employerId,
    required String candidateId,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Chưa đăng nhập');
    if (uid != candidateId) {
      throw Exception('Chỉ ứng viên mới điểm danh cuối ca');
    }

    final now = DateTime.now();
    final date = _dateKey(now);
    final time = _timeKey(now);

    final existing = await _findTodayAttendance(jobId, date);
    if (!_hasCheckIn(existing, candidateId)) {
      throw Exception('Hãy điểm danh đầu ca trước');
    }
    if (_hasCheckOut(existing, candidateId)) {
      throw Exception('Bạn đã điểm danh cuối ca hôm nay');
    }

    await _updateCheckOut(
      doc: existing!,
      candidateId: candidateId,
      checkOutTime: time,
      checkOutAt: now,
    );

    await _notifyEmployerAttendanceResult(
      employerId: employerId,
      groupId: groupId,
      jobId: jobId,
      attendanceId: existing.id,
      candidateName: 'Nhân viên',
      isCheckIn: false,
      timeLabel: time,
    );
  }

  Future<String> createSchedule({
    required String groupId,
    required String jobId,
    required String employerId,
    required String candidateId,
    required String date,
    required String startTime,
    required String endTime,
    required String jobTitle,
    String? jobLocation,
    String? employerName,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Chưa đăng nhập');

    final dup = await _db
        .collection('schedules')
        .where('jobId', isEqualTo: jobId)
        .where('candidateId', isEqualTo: candidateId)
        .where('date', isEqualTo: date)
        .limit(1)
        .get();
    if (dup.docs.isNotEmpty) {
      throw Exception('Đã có lịch cho ngày này');
    }

    final ref = _db.collection('schedules').doc();
    await ref.set({
      'scheduleId': ref.id,
      'jobId': jobId,
      'candidateId': candidateId,
      'employerId': employerId,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'status': 'scheduled',
      'jobTitle': jobTitle,
      if (jobLocation != null && jobLocation.isNotEmpty)
        'jobLocation': jobLocation,
      if (employerName != null && employerName.isNotEmpty)
        'employerName': employerName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final content =
        'Lịch ca: $jobTitle · $date ($startTime – $endTime)';

    await _sendMessageRaw(
      groupId,
      senderId: uid,
      type: 'schedule',
      content: content,
      metadata: {
        'scheduleId': ref.id,
        'jobId': jobId,
        'jobTitle': jobTitle,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'candidateId': candidateId,
        'employerId': employerId,
      },
    );
    await _updatePreview(groupId, content, uid);
    return ref.id;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findTodayAttendance(
    String jobId,
    String date,
  ) async {
    final snap = await _db
        .collection('attendance')
        .where('jobId', isEqualTo: jobId)
        .where('date', isEqualTo: date)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first;
  }

  bool _hasCheckIn(
    DocumentSnapshot<Map<String, dynamic>>? doc,
    String candidateId,
  ) {
    if (doc == null) return false;
    final records = doc.data()?['records'] as List? ?? [];
    return records.any(
      (r) =>
          r is Map &&
          (r['candidateId'] ?? '').toString() == candidateId &&
          (r['checkInTime'] ?? '').toString().isNotEmpty,
    );
  }

  bool _hasCheckOut(
    DocumentSnapshot<Map<String, dynamic>>? doc,
    String candidateId,
  ) {
    if (doc == null) return false;
    final records = doc.data()?['records'] as List? ?? [];
    return records.any(
      (r) =>
          r is Map &&
          (r['candidateId'] ?? '').toString() == candidateId &&
          (r['checkOutTime'] ?? '').toString().isNotEmpty,
    );
  }

  Future<String> _upsertAttendanceRecord({
    required DocumentSnapshot<Map<String, dynamic>>? existing,
    required String jobId,
    required String groupId,
    required String employerId,
    required String date,
    required String candidateId,
    required String checkInTime,
    required DateTime checkInAt,
  }) async {
    final record = {
      'candidateId': candidateId,
      'checkInTime': checkInTime,
      'checkInAt': Timestamp.fromDate(checkInAt),
      'status': 'on_time',
      'lateMinutes': 0,
    };

    if (existing == null) {
      final ref = _db.collection('attendance').doc();
      await ref.set({
        'attendanceId': ref.id,
        'jobId': jobId,
        'groupId': groupId,
        'employerId': employerId,
        'date': date,
        'expectedStartTime': checkInTime,
        'records': [record],
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    }

    final data = Map<String, dynamic>.from(existing.data() ?? {});
    final records = List<Map<String, dynamic>>.from(
      (data['records'] as List?)?.map(
            (e) => Map<String, dynamic>.from(e as Map),
          ) ??
          [],
    );
    records.removeWhere((r) => r['candidateId'] == candidateId);
    records.add(record);
    await existing.reference.update({'records': records});
    return existing.id;
  }

  Future<void> _updateCheckOut({
    required DocumentSnapshot<Map<String, dynamic>> doc,
    required String candidateId,
    required String checkOutTime,
    required DateTime checkOutAt,
  }) async {
    final data = Map<String, dynamic>.from(doc.data() ?? {});
    final records = List<Map<String, dynamic>>.from(
      (data['records'] as List?)?.map(
            (e) => Map<String, dynamic>.from(e as Map),
          ) ??
          [],
    );

    for (var i = 0; i < records.length; i++) {
      if (records[i]['candidateId'] == candidateId) {
        records[i] = {
          ...records[i],
          'checkOutTime': checkOutTime,
          'checkOutAt': Timestamp.fromDate(checkOutAt),
        };
        break;
      }
    }
    await doc.reference.update({'records': records});
  }

  /// Ứng viên chụp ảnh sau yêu cầu điểm danh của NTD.
  Future<void> submitAttendancePhotoFromRequest({
    required String groupId,
    required String jobId,
    required String attendanceId,
    required bool isCheckIn,
    required String photoBase64,
    required String expectedStartTime,
    required AttendanceCaptureMeta captureMeta,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Chưa đăng nhập');

    final record = await AttendanceService().submitAttendancePhoto(
      attendanceId: attendanceId,
      candidateId: uid,
      isCheckIn: isCheckIn,
      photoBase64: photoBase64,
      expectedStartTime: expectedStartTime,
      captureMeta: captureMeta,
    );

    final attSnap = await _db.collection('attendance').doc(attendanceId).get();
    final employerId =
        (attSnap.data()?['employerId'] ?? '').toString();

    await _notifyEmployerAttendanceResult(
      employerId: employerId,
      groupId: groupId,
      jobId: jobId,
      attendanceId: attendanceId,
      candidateName: record.candidateName,
      isCheckIn: isCheckIn,
      record: record,
    );
  }

  /// NTD nhận thông báo khi nhân viên chụp ảnh điểm danh (không đăng chat).
  Future<void> _notifyEmployerAttendanceResult({
    required String employerId,
    required String groupId,
    required String jobId,
    required String attendanceId,
    required String candidateName,
    required bool isCheckIn,
    AttendanceRecord? record,
    String? timeLabel,
  }) async {
    if (employerId.isEmpty) return;

    final label = isCheckIn ? 'đầu ca' : 'cuối ca';
    final name = candidateName.trim().isNotEmpty ? candidateName.trim() : 'Nhân viên';
    final lateNote = isCheckIn &&
            record != null &&
            record.status == 'late'
        ? ' (trễ ${record.lateMinutes} phút)'
        : '';

    final body = StringBuffer()..writeln('$name đã điểm danh $label$lateNote.');

    if (record != null) {
      final when =
          isCheckIn ? record.checkInCapturedAt : record.checkOutCapturedAt;
      final loc =
          isCheckIn ? record.checkInLocation : record.checkOutLocation;
      if (when != null && when.isNotEmpty) {
        body.writeln('🕐 $when');
      } else if (timeLabel != null && timeLabel.isNotEmpty) {
        body.writeln('🕐 $timeLabel');
      }
      if (loc != null && loc.isNotEmpty) {
        body.writeln('📍 $loc');
      }
    } else if (timeLabel != null && timeLabel.isNotEmpty) {
      body.writeln('🕐 $timeLabel');
    }

    body.writeln('Nhấn thông báo để xem màn điểm danh.');

    await _notifications.notifyEmployer(
      employerId: employerId,
      type: 'attendance_result',
      title: isCheckIn
          ? 'Nhân viên điểm danh đầu ca'
          : 'Nhân viên điểm danh cuối ca',
      body: body.toString().trim(),
      category: NotificationCategory.job,
      data: {
        'groupId': groupId,
        'jobId': jobId,
        'attendanceId': attendanceId,
        'phase': isCheckIn ? 'check_in' : 'check_out',
        'type': 'attendance_result',
      },
    );
  }

  Future<void> _sendMessageRaw(
    String groupId, {
    required String senderId,
    required String type,
    required String content,
    Map<String, dynamic>? metadata,
    String? attachmentUrl,
  }) async {
    final ref = _db.collection(_groups).doc(groupId).collection(_messages).doc();
    await ref.set({
      'msgId': ref.id,
      'senderId': senderId,
      'type': type,
      'content': content,
      ...(metadata == null ? const {} : {'metadata': metadata}),
      ...(attachmentUrl == null ? const {} : {'attachmentUrl': attachmentUrl}),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendAttachmentMessage({
    required String groupId,
    required String type,
    required String content,
    String? attachmentUrl,
    Map<String, dynamic>? metadata,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Chưa đăng nhập');

    await _sendMessageRaw(
      groupId,
      senderId: uid,
      type: type,
      content: content,
      metadata: metadata,
      attachmentUrl: attachmentUrl,
    );
    await _updatePreview(groupId, content, uid);
  }

  Future<void> _updatePreview(
    String groupId,
    String preview,
    String senderId,
  ) async {
    final ref = _db.collection(_groups).doc(groupId);
    final snap = await ref.get();
    if (!snap.exists) return;

    final data = snap.data() ?? {};

    if (senderId == 'system') {
      await ref.update({
        'lastMessageText': preview,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': senderId,
      });
      return;
    }

    var members = (data['memberIds'] as List?)
            ?.map((e) => e.toString())
            .where((id) => id.isNotEmpty)
            .toList() ??
        [];
    final employerId = (data['employerId'] ?? '').toString();
    final chatType = (data['chatType'] ?? 'direct').toString();
    // Chỉ nhóm việc mới thêm NTD vào memberIds — tránh peer/direct bị tính thành nhóm.
    if (chatType == 'group' &&
        employerId.isNotEmpty &&
        !members.contains(employerId)) {
      await ref.update({
        'memberIds': FieldValue.arrayUnion([employerId]),
      });
      members = [...members, employerId];
    }

    final muted = (data['mutedBy'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final jobTitle = (data['jobTitle'] ?? 'Nhóm chat').toString();
    final isGroupChat = chatType == 'group' ||
        (chatType != 'peer' && chatType != 'direct' && members.length > 2);
    final rawUnread = data['unreadCounts'] as Map? ?? {};

    final recipientIds = <String>{...members};
    if (chatType == 'group' && employerId.isNotEmpty) {
      recipientIds.add(employerId);
    }
    recipientIds.remove(senderId);

    final updates = <String, dynamic>{
      'lastMessageText': preview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': senderId,
    };

    for (final memberId in recipientIds) {
      if (!muted.contains(memberId)) {
        updates['unreadCounts.$memberId'] = FieldValue.increment(1);
      }
    }
    await ref.update(updates);

    final senderProfiles = await fetchParticipants({senderId});
    final senderName = senderProfiles[senderId]?.name ?? 'Ai đó';
    final shortPreview = preview.length > 80
        ? '${preview.substring(0, 80)}…'
        : preview;

    for (final recipientId in recipientIds) {
      if (muted.contains(recipientId)) continue;

      final prev = (rawUnread[recipientId] as num?)?.toInt() ?? 0;
      final newCount = prev + 1;

      String title;
      String body;
      if (isGroupChat) {
        title = 'Tin nhắn nhóm mới';
        body = newCount > 1
            ? 'Bạn có $newCount tin nhắn mới trong "$jobTitle"'
            : '$senderName: $shortPreview · $jobTitle';
      } else {
        title = 'Tin nhắn mới';
        body = newCount > 1
            ? 'Bạn có $newCount tin nhắn mới từ $senderName'
            : '$senderName: $shortPreview';
      }

      await _notifications.notifyNewChatMessage(
        recipientId: recipientId,
        groupId: groupId,
        title: title,
        body: body,
        unreadCount: newCount,
        isGroupChat: isGroupChat,
        senderName: senderName,
        preview: shortPreview,
      );
    }
  }

  Future<void> _refreshGroupPreviewFromLatestMessage(String groupId) async {
    final groupRef = _db.collection(_groups).doc(groupId);
    final latest = await groupRef
        .collection(_messages)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (latest.docs.isEmpty) {
      await groupRef.update({
        'lastMessageText': '',
        'lastSenderId': '',
        'lastMessageAt': null,
      });
      return;
    }

    final data = latest.docs.first.data();
    final type = (data['type'] ?? 'text').toString();
    final content = (data['content'] ?? '').toString();
    final senderId = (data['senderId'] ?? '').toString();
    final preview = _previewForMessageType(type, content);

    await groupRef.update({
      'lastMessageText': preview,
      'lastSenderId': senderId,
      'lastMessageAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
    });
  }

  String _previewForMessageType(String type, String content) {
    switch (type) {
      case 'image':
        return '[Hình ảnh]';
      case 'audio':
        return '[Tin thoại]';
      case 'file':
        return '[Tệp đính kèm]';
      case 'location':
        return '[Vị trí]';
      case 'call':
        return 'Cuộc gọi';
      case 'schedule':
        return content.isNotEmpty ? content : 'Lịch ca làm';
      case 'attendance_request':
        return 'Yêu cầu điểm danh';
      case 'attendance_checkin':
      case 'attendance_checkout':
        return 'Điểm danh';
      case 'recalled':
        return 'Tin nhắn đã được thu hồi';
      default:
        return content;
    }
  }
}
