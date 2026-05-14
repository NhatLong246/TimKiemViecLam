enum MessageRole { user, bot }

enum ChatAttachmentType { image, textFile }

class ChatAttachment {
  final String name;
  final ChatAttachmentType type;
  final String? mimeType;
  final String? base64Data;
  final String? textContent;

  const ChatAttachment({
    required this.name,
    required this.type,
    this.mimeType,
    this.base64Data,
    this.textContent,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type.name,
      'mimeType': mimeType,
      'base64Data': base64Data,
      'textContent': textContent,
    };
  }

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      name: json['name']?.toString() ?? 'Tệp đính kèm',
      type: ChatAttachmentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ChatAttachmentType.textFile,
      ),
      mimeType: json['mimeType']?.toString(),
      base64Data: json['base64Data']?.toString(),
      textContent: json['textContent']?.toString(),
    );
  }
}

class ChatMessage {
  final String text;
  final MessageRole role;
  final DateTime createdAt;
  final bool isTyping;
  final ChatAttachment? attachment;

  const ChatMessage({
    required this.text,
    required this.role,
    required this.createdAt,
    this.isTyping = false,
    this.attachment,
  });

  ChatMessage copyWith({
    String? text,
    bool? isTyping,
    ChatAttachment? attachment,
  }) {
    return ChatMessage(
      text: text ?? this.text,
      role: role,
      createdAt: createdAt,
      isTyping: isTyping ?? this.isTyping,
      attachment: attachment ?? this.attachment,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'role': role.name,
      'createdAt': createdAt.toIso8601String(),
      'isTyping': isTyping,
      'attachment': attachment?.toJson(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text']?.toString() ?? '',
      role: MessageRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => MessageRole.bot,
      ),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      isTyping: json['isTyping'] == true,
      attachment: json['attachment'] is Map
          ? ChatAttachment.fromJson(
              Map<String, dynamic>.from(json['attachment'] as Map),
            )
          : null,
    );
  }
}

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  ChatSession copyWith({
    String? title,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  }) {
    return ChatSession(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'messages': messages
          .where((message) => !message.isTyping)
          .map((message) => message.toJson())
          .toList(),
    };
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id:
          json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? 'Đoạn chat mới',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      messages: (json['messages'] as List? ?? [])
          .whereType<Map>()
          .map(
            (message) =>
                ChatMessage.fromJson(Map<String, dynamic>.from(message)),
          )
          .toList(),
    );
  }
}
