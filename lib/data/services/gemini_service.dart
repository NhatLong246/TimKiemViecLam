import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';

class GeminiService {
  // Lấy API key miễn phí tại https://openrouter.ai/keys
  static const String _apiKey = '';
  static const String _model = 'z-ai/glm-4.5-air:free';
  static const String _baseUrl =
      'https://openrouter.ai/api/v1/chat/completions';

  static const String _systemPrompt = '''
Bạn là trợ lý tư vấn việc làm thông minh của ứng dụng ViecNow - nền tảng tìm kiếm việc làm hàng đầu Việt Nam.

NHIỆM VỤ CỦA BẠN:
- Tư vấn nghề nghiệp và định hướng việc làm phù hợp
- Hướng dẫn viết CV/hồ sơ xin việc chuyên nghiệp
- Chuẩn bị phỏng vấn: câu hỏi thường gặp, cách trả lời ấn tượng
- Thông tin thị trường lao động Việt Nam (ngành hot, xu hướng tuyển dụng)
- Mức lương tham khảo theo ngành, kinh nghiệm và địa phương
- Kỹ năng mềm & cứng cần thiết cho từng vị trí
- Hướng dẫn tìm việc hiệu quả trên ViecNow
- Tư vấn phát triển sự nghiệp dài hạn
- Hỗ trợ người lao động phổ thông, sinh viên mới ra trường, người đổi nghề

PHONG CÁCH TRẢ LỜI:
- Dùng tiếng Việt, thân thiện, gần gũi, chuyên nghiệp
- Câu trả lời ngắn gọn, súc tích, dễ hiểu
- Dùng emoji phù hợp để tăng tính thân thiện 
- Khi phù hợp, dùng danh sách gạch đầu dòng cho dễ đọc
- Luôn khuyến khích và tạo động lực cho người dùng

GIỚI HẠN:
- Chỉ tư vấn trong lĩnh vực việc làm, nghề nghiệp, sự nghiệp
- Nếu câu hỏi không liên quan, nhẹ nhàng chuyển hướng về chủ đề việc làm
- Không đưa ra cam kết tuyệt đối về mức lương hay cơ hội việc làm
''';

  Future<String> sendMessage(
    List<ChatMessage> history,
    String newMessage, {
    ChatAttachment? attachment,
  }) async {
    final uri = Uri.parse(_baseUrl);

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _systemPrompt},
    ];

    final firstUserIdx = history.indexWhere(
      (m) => !m.isTyping && m.role == MessageRole.user,
    );
    if (firstUserIdx >= 0) {
      for (final msg in history.sublist(firstUserIdx)) {
        if (msg.isTyping) continue;
        messages.add(_buildMessagePayload(msg));
      }
    }

    messages.add(_buildUserPayload(newMessage, attachment));

    final body = jsonEncode({
      'model': _model,
      'messages': messages,
      'temperature': 0.7,
      'max_tokens': 1024,
      'top_p': 0.9,
    });

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
        'HTTP-Referer': 'https://viecnow.app',
        'X-Title': 'ViecNow',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List;
      if (choices.isNotEmpty) {
        final message = choices[0]['message'] as Map<String, dynamic>;
        return message['content'] as String;
      }
      throw Exception('Không nhận được phản hồi từ AI');
    } else if (response.statusCode == 400) {
      String detail = '';
      try {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        detail =
            (err['error'] as Map?)?['message']?.toString() ?? response.body;
      } catch (_) {
        detail = response.body;
      }
      throw Exception('Lỗi 400: $detail');
    } else if (response.statusCode == 403 || response.statusCode == 401) {
      String detail = '';
      try {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        detail =
            (err['error'] as Map?)?['message']?.toString() ?? response.body;
      } catch (_) {
        detail = response.body;
      }
      throw Exception('API key OpenRouter chưa hợp lệ. $detail');
    } else if (response.statusCode == 429) {
      String detail = '';
      try {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        detail = (err['error'] as Map?)?['message']?.toString() ?? '';
      } catch (_) {}
      throw Exception('Đã đạt giới hạn yêu cầu. $detail');
    } else {
      String detail = '';
      try {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        detail = (err['error'] as Map?)?['message']?.toString() ?? '';
      } catch (_) {}
      throw Exception('Lỗi kết nối (${response.statusCode}). $detail');
    }
  }

  Map<String, dynamic> _buildMessagePayload(ChatMessage msg) {
    if (msg.role == MessageRole.bot || msg.attachment == null) {
      return {
        'role': msg.role == MessageRole.user ? 'user' : 'assistant',
        'content': msg.text,
      };
    }

    return _buildUserPayload(msg.text, msg.attachment);
  }

  Map<String, dynamic> _buildUserPayload(
    String text,
    ChatAttachment? attachment,
  ) {
    if (attachment == null) {
      return {'role': 'user', 'content': text};
    }

    if (attachment.type == ChatAttachmentType.image &&
        attachment.base64Data != null) {
      return {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': text},
          {
            'type': 'image_url',
            'image_url': {
              'url':
                  'data:${attachment.mimeType ?? 'image/jpeg'};base64,${attachment.base64Data}',
            },
          },
        ],
      };
    }

    final fileText = attachment.textContent ?? '';
    return {
      'role': 'user',
      'content':
          '$text\n\nNội dung file "${attachment.name}":\n```\n$fileText\n```',
    };
  }
}
