import 'package:cloud_firestore/cloud_firestore.dart';

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
  });

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
    );
  }
}

class JobChatMessage {
  final String msgId;
  final String senderId;
  final String content;
  final String type;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;

  const JobChatMessage({
    required this.msgId,
    required this.senderId,
    required this.content,
    required this.type,
    this.metadata,
    this.createdAt,
  });

  bool isMine(String uid) => senderId == uid;

  bool get isSystem =>
      type == 'system' || senderId == 'system';

  bool get isAttendance =>
      type == 'attendance_checkin' || type == 'attendance_checkout';

  bool get isSchedule => type == 'schedule';

  factory JobChatMessage.fromMap(String msgId, Map<String, dynamic> map) {
    final meta = map['metadata'];
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
