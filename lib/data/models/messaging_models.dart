import 'package:cloud_firestore/cloud_firestore.dart';

/// Khớp [ChatReadPreferences.clockSkew] — tránh phụ thuộc utils trong model.
const Duration _kReadClockSkew = Duration(seconds: 90);

class ConversationThread {
  final String groupId;
  final String jobId;
  final String jobTitle;
  final String employerId;
  final String? candidateId;
  final List<String> memberIds;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final String? lastSenderId;
  final String peerId;
  final String peerName;
  final String? peerAvatarUrl;
  final String chatType; // direct | group | peer
  final int unreadCount;
  /// User đã tắt thông báo nhóm (mutedBy).
  final bool notificationsMuted;
  final String? groupAvatarBase64;
  final String status;

  /// Nhóm việc (không gồm chat peer/direct 1-1 giữa thành viên).
  bool get isGroupChat {
    if (chatType == 'peer') return false;
    if (chatType == 'direct') return memberIds.length > 2;
    if (chatType == 'group') return true;
    return memberIds.length > 2;
  }

  bool get isClosed => status == 'closed';

  /// Tiêu đề danh sách: tab Nhóm chat → tên việc; tab Cá nhân → tên đối phương.
  String listTitle({required bool groupTab}) =>
      groupTab ? jobTitle : peerName;

  /// Dòng phụ danh sách — không dùng; chỉ hiện tiêu đề + tin nhắn mới nhất.
  String listSubtitle({required bool groupTab}) => '';

  /// Chữ cái avatar trên danh sách.
  String listAvatarLetter({required bool groupTab}) {
    final src = groupTab ? jobTitle : peerName;
    return src.isNotEmpty ? src[0].toUpperCase() : '?';
  }

  /// Ứng viên nào được dùng khi điểm danh (đầu/cuối ca).
  /// Nhóm 3+ người: mỗi ứng viên điểm danh cho chính mình.
  /// Chat 1-1: dùng candidateId trên document (hoặc chính uid nếu thiếu).
  String? attendanceCandidateId(String currentUid, String currentRole) {
    if (currentRole != 'candidate') return null;
    if (!memberIds.contains(currentUid)) return null;

    if (isGroupChat) {
      return currentUid;
    }

    if (candidateId != null &&
        candidateId!.isNotEmpty &&
        candidateId == currentUid) {
      return currentUid;
    }

    // Chat direct cũ thiếu candidateId trên Firestore
    if (candidateId == null || candidateId!.isEmpty) {
      return currentUid;
    }

    return null;
  }

  const ConversationThread({
    required this.groupId,
    required this.jobId,
    required this.jobTitle,
    required this.employerId,
    this.candidateId,
    required this.memberIds,
    this.lastMessageText,
    this.lastMessageAt,
    this.lastSenderId,
    required this.peerId,
    required this.peerName,
    this.peerAvatarUrl,
    this.chatType = 'direct',
    this.unreadCount = 0,
    this.notificationsMuted = false,
    this.groupAvatarBase64,
    this.status = 'active',
  });

  ConversationThread copyWith({
    int? unreadCount,
    bool? notificationsMuted,
    String? groupAvatarBase64,
    String? status,
  }) {
    return ConversationThread(
      groupId: groupId,
      jobId: jobId,
      jobTitle: jobTitle,
      employerId: employerId,
      candidateId: candidateId,
      memberIds: memberIds,
      lastMessageText: lastMessageText,
      lastMessageAt: lastMessageAt,
      lastSenderId: lastSenderId,
      peerId: peerId,
      peerName: peerName,
      peerAvatarUrl: peerAvatarUrl,
      chatType: chatType,
      unreadCount: unreadCount ?? this.unreadCount,
      notificationsMuted: notificationsMuted ?? this.notificationsMuted,
      groupAvatarBase64: groupAvatarBase64 ?? this.groupAvatarBase64,
      status: status ?? this.status,
    );
  }

  factory ConversationThread.fromMap(
    String groupId,
    Map<String, dynamic> map, {
    required String currentUid,
    required String peerName,
    String? peerAvatarUrl,
  }) {
    final members = (map['memberIds'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final employerId = (map['employerId'] ?? '').toString();
    final candidateId = map['candidateId']?.toString();
    final peerId = members.firstWhere(
      (id) => id != currentUid,
      orElse: () => employerId,
    );
    final mutedBy = (map['mutedBy'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final notificationsMuted = mutedBy.contains(currentUid);

    return ConversationThread(
      groupId: groupId,
      jobId: (map['jobId'] ?? '').toString(),
      jobTitle: (map['jobTitle'] ?? 'Công việc').toString(),
      employerId: employerId,
      candidateId: candidateId,
      memberIds: members,
      lastMessageText: map['lastMessageText']?.toString(),
      lastMessageAt: _parseDate(map['lastMessageAt']),
      lastSenderId: map['lastSenderId']?.toString(),
      peerId: peerId,
      peerName: peerName,
      peerAvatarUrl: peerAvatarUrl,
      chatType: (map['chatType'] ?? 'direct').toString(),
      unreadCount: notificationsMuted
          ? 0
          : _parseUnreadCount(map, currentUid),
      notificationsMuted: notificationsMuted,
      groupAvatarBase64: map['groupAvatarBase64']?.toString(),
      status: (map['status'] ?? 'active').toString(),
    );
  }

  static int _parseUnreadCount(Map<String, dynamic> map, String uid) {
    final lastMsgAt = _parseDate(map['lastMessageAt']);
    final lastReadAt = _parseUserFieldDate(map['lastReadAt'], uid);

    final raw = map['unreadCounts'];
    if (raw is Map) {
      final v = raw[uid] ?? raw[uid.toString()];
      final count = (v as num?)?.toInt() ?? 0;
      if (count <= 0) return 0;
    }

    if (lastMsgAt != null && lastReadAt != null) {
      final adjustedRead = lastReadAt.add(_kReadClockSkew);
      if (!lastMsgAt.isAfter(adjustedRead)) return 0;
    }

    if (raw is Map) {
      final v = raw[uid] ?? raw[uid.toString()];
      final count = (v as num?)?.toInt() ?? 0;
      return count < 0 ? 0 : count;
    }
    return 0;
  }

  static DateTime? _parseUserFieldDate(dynamic raw, String uid) {
    if (raw is! Map) return null;
    return _parseDate(raw[uid] ?? raw[uid.toString()]);
  }
}

class JobChatMessage {
  final String msgId;
  final String senderId;
  final String content;
  final String type;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final String? attachmentUrl;
  /// userId -> emoji
  final Map<String, String> reactions;

  const JobChatMessage({
    required this.msgId,
    required this.senderId,
    required this.content,
    required this.type,
    this.metadata,
    this.createdAt,
    this.attachmentUrl,
    this.reactions = const {},
  });

  bool isMine(String uid) => senderId == uid;

  bool get isSystem =>
      type == 'system' || senderId == 'system';

  bool get isAttendance =>
      type == 'attendance_checkin' || type == 'attendance_checkout';

  bool get isAttendanceRequest => type == 'attendance_request';

  bool get isSchedule => type == 'schedule';

  bool get isText => type == 'text';

  bool get isRecalled => type == 'recalled';

  bool get isCall => type == 'call';

  bool get isImage => type == 'image';

  bool get isAudio => type == 'audio';

  bool get isFile => type == 'file';

  bool get isLocation => type == 'location';

  String? reactionBy(String userId) => reactions[userId];

  /// emoji -> count (for display under bubble)
  Map<String, int> get reactionCounts {
    final counts = <String, int>{};
    for (final emoji in reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return counts;
  }

  factory JobChatMessage.fromMap(String msgId, Map<String, dynamic> map) {
    final meta = map['metadata'];
    final rawReactions = map['reactions'];
    final reactions = <String, String>{};
    if (rawReactions is Map) {
      rawReactions.forEach((k, v) {
        final emoji = v?.toString() ?? '';
        if (emoji.isNotEmpty) reactions[k.toString()] = emoji;
      });
    }
    return JobChatMessage(
      msgId: msgId,
      senderId: (map['senderId'] ?? '').toString(),
      content: (map['content'] ?? '').toString(),
      type: (map['type'] ?? 'text').toString(),
      metadata: meta is Map<String, dynamic>
          ? meta
          : meta is Map
              ? Map<String, dynamic>.from(meta)
              : null,
      createdAt: _parseDate(map['createdAt']),
      attachmentUrl: map['attachmentUrl']?.toString(),
      reactions: reactions,
    );
  }
}

class ChatParticipant {
  final String uid;
  final String name;
  final String? avatarUrl;
  final String role;

  const ChatParticipant({
    required this.uid,
    required this.name,
    this.avatarUrl,
    required this.role,
  });
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}
