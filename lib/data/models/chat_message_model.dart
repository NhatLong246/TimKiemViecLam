import 'package:cloud_firestore/cloud_firestore.dart';

/// type: 'text' | 'image' | 'audio' | 'file' | 'location' | 'poll' | 'schedule' | 'system' | 'recalled'
class ChatMessageModel {
  final String msgId;
  final String senderId;
  final String senderName;
  final String content;
  final String type;
  final String? attachmentUrl;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final bool edited; // true nếu đã được sửa

  const ChatMessageModel({
    required this.msgId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.type,
    this.attachmentUrl,
    this.metadata,
    required this.createdAt,
    this.edited = false,
  });

  factory ChatMessageModel.fromMap(Map<String, dynamic> map, String docId) {
    return ChatMessageModel(
      msgId: docId,
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? '',
      content: map['content'] as String? ?? '',
      type: map['type'] as String? ?? 'text',
      attachmentUrl: map['attachmentUrl'] as String?,
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : null,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      edited: map['edited'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'senderName': senderName,
        'content': content,
        'type': type,
        if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
        if (metadata != null) 'metadata': metadata,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
