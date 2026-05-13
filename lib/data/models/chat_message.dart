enum MessageRole { user, bot }

class ChatMessage {
  final String text;
  final MessageRole role;
  final DateTime createdAt;
  final bool isTyping;

  const ChatMessage({
    required this.text,
    required this.role,
    required this.createdAt,
    this.isTyping = false,
  });

  ChatMessage copyWith({String? text, bool? isTyping}) {
    return ChatMessage(
      text: text ?? this.text,
      role: role,
      createdAt: createdAt,
      isTyping: isTyping ?? this.isTyping,
    );
  }
}
