import 'package:cloud_firestore/cloud_firestore.dart';

class GroupChatModel {
  final String groupId;
  final String jobId;
  final String jobTitle;
  final String employerId;
  final List<String> memberIds;
  final DateTime createdAt;
  final String? groupAvatarBase64;       // ảnh đại diện nhóm (Base64)
  final Map<String, String> nicknames;   // userId → biệt danh
  final List<String> mutedBy;            // danh sách userId đã tắt thông báo

  const GroupChatModel({
    required this.groupId,
    required this.jobId,
    required this.jobTitle,
    required this.employerId,
    required this.memberIds,
    required this.createdAt,
    this.groupAvatarBase64,
    this.nicknames = const {},
    this.mutedBy = const [],
  });

  factory GroupChatModel.fromMap(Map<String, dynamic> map, String docId) {
    final rawNick = map['nicknames'] as Map? ?? {};
    return GroupChatModel(
      groupId: docId,
      jobId: map['jobId'] as String? ?? '',
      jobTitle: map['jobTitle'] as String? ?? '',
      employerId: map['employerId'] as String? ?? '',
      memberIds: List<String>.from(map['memberIds'] as List? ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      groupAvatarBase64: map['groupAvatarBase64'] as String?,
      nicknames: Map<String, String>.from(rawNick),
      mutedBy: List<String>.from(map['mutedBy'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
        'groupId': groupId,
        'jobId': jobId,
        'jobTitle': jobTitle,
        'employerId': employerId,
        'memberIds': memberIds,
        'createdAt': FieldValue.serverTimestamp(),
        if (groupAvatarBase64 != null) 'groupAvatarBase64': groupAvatarBase64,
        'nicknames': nicknames,
      };
}
