import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/messaging_models.dart';

class MessagingService {
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
    for (final doc in apps.docs) {
      final d = doc.data();
      final jobId = (d['jobId'] ?? '').toString();
      final candidateId = (d['candidateId'] ?? '').toString();
      final employerId = (d['employerId'] ?? '').toString();
      if (jobId.isEmpty || candidateId.isEmpty || employerId.isEmpty) continue;

      final jobSnap = await _db.collection('jobPosts').doc(jobId).get();
      if (!jobSnap.exists) continue;
      final title = (jobSnap.data()?['title'] ?? 'Công việc').toString();

      await getOrCreateDirectChat(
        jobId: jobId,
        jobTitle: title,
        employerId: employerId,
        candidateId: candidateId,
        applicationId: doc.id,
      );
    }
  }

  Future<String> getOrCreateDirectChat({
    required String jobId,
    required String jobTitle,
    required String employerId,
    required String candidateId,
    String? applicationId,
  }) async {
    final existing = await _db
        .collection(_groups)
        .where('jobId', isEqualTo: jobId)
        .where('candidateId', isEqualTo: candidateId)
        .where('chatType', isEqualTo: 'direct')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final ref = _db.collection(_groups).doc();
    final memberIds = [employerId, candidateId];

    await ref.set({
      'groupId': ref.id,
      'jobId': jobId,
      'jobTitle': jobTitle,
      'employerId': employerId,
      'candidateId': candidateId,
      if (applicationId != null) 'applicationId': applicationId,
      'memberIds': memberIds,
      'chatType': 'direct',
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageText': 'Bắt đầu trò chuyện về "$jobTitle"',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': 'system',
    });

    await _db.collection('jobPosts').doc(jobId).set(
      {'groupChatId': ref.id},
      SetOptions(merge: true),
    );

    await _sendMessageRaw(
      ref.id,
      senderId: 'system',
      type: 'system',
      content:
          'Hội thoại việc làm đã mở. Trao đổi công việc, điểm danh đầu/cuối ca và gửi lịch làm việc tại đây.',
    );

    return ref.id;
  }

  Stream<List<ConversationThread>> streamConversations(String uid) {
    return _db
        .collection(_groups)
        .where('memberIds', arrayContains: uid)
        .snapshots()
        .asyncMap((snap) async {
      final threads = <ConversationThread>[];
      final peerIds = <String>{};

      for (final doc in snap.docs) {
        final data = doc.data();
        final members = (data['memberIds'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final peerId = members.firstWhere(
          (id) => id != uid,
          orElse: () => (data['employerId'] ?? '').toString(),
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
        final peerId = members.firstWhere(
          (id) => id != uid,
          orElse: () => (data['employerId'] ?? '').toString(),
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
    });
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
    final peerId = members.firstWhere(
      (id) => id != currentUid,
      orElse: () => (data['employerId'] ?? '').toString(),
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

  Future<void> sendText(String groupId, String text) async {
    final uid = _uid;
    if (uid == null) throw Exception('Chưa đăng nhập');
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await _sendMessageRaw(
      groupId,
      senderId: uid,
      type: 'text',
      content: trimmed,
    );
    await _updatePreview(groupId, trimmed, uid);
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

    await _sendMessageRaw(
      groupId,
      senderId: uid,
      type: 'attendance_checkin',
      content: 'Đã điểm danh đầu ca lúc $time',
      metadata: {
        'date': date,
        'time': time,
        'attendanceId': attendanceId,
        'jobId': jobId,
      },
    );
    await _updatePreview(groupId, 'Điểm danh đầu ca · $time', uid);
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

    await _sendMessageRaw(
      groupId,
      senderId: uid,
      type: 'attendance_checkout',
      content: 'Đã điểm danh cuối ca lúc $time',
      metadata: {
        'date': date,
        'time': time,
        'jobId': jobId,
      },
    );
    await _updatePreview(groupId, 'Điểm danh cuối ca · $time', uid);
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

  Future<void> _sendMessageRaw(
    String groupId, {
    required String senderId,
    required String type,
    required String content,
    Map<String, dynamic>? metadata,
  }) async {
    final ref = _db.collection(_groups).doc(groupId).collection(_messages).doc();
    await ref.set({
      'msgId': ref.id,
      'senderId': senderId,
      'type': type,
      'content': content,
      if (metadata != null) 'metadata': metadata,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updatePreview(
    String groupId,
    String preview,
    String senderId,
  ) async {
    await _db.collection(_groups).doc(groupId).update({
      'lastMessageText': preview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': senderId,
    });
  }
}
