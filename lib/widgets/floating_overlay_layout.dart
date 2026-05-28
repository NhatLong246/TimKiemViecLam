import 'dart:ui';

/// Vị trí mặc định bong bóng tin nhắn + chatbot (cột phải, tin nhắn nằm trên chatbot).
class FloatingOverlayLayout {
  FloatingOverlayLayout._();

  /// Mép phải avatar / chatbot cách cạnh màn hình (px).
  static const double rightMargin = 8;
  static const double chatbotSize = 56;
  /// `left` chatbot = `width - chatbotAnchorLeft` (= width - margin - chatbotSize).
  static const double chatbotAnchorLeft = rightMargin + chatbotSize;

  /// Cùng kích thước chatbot để xếp dọc thẳng cột.
  static const double messageHeadSize = 56;
  static const double messagePreviewMaxWidth = 160;
  static const double messagePreviewGap = 8;
  static const double gapMessageAboveChatbot = 10;

  /// Đỉnh nút chatbot (không tính tooltip) — khớp mockup / ảnh mẫu.
  static const double chatbotTopFactor = 0.65;

  static double chatbotTop(Size size) => size.height * chatbotTopFactor;

  static double chatbotLeft(Size size) => size.width - chatbotAnchorLeft;

  static double messageBubbleWidth({required bool hasPreview}) =>
      hasPreview
          ? messageHeadSize + messagePreviewGap + messagePreviewMaxWidth
          : messageHeadSize;

  /// Đáy avatar cách đỉnh chatbot đúng `gapMessageAboveChatbot`.
  static double messageTop(Size size) =>
      chatbotTop(size) - messageHeadSize - gapMessageAboveChatbot;

  /// Mép phải avatar trùng mép phải chatbot; preview mở sang trái.
  static double messageLeft(Size size, {required bool hasPreview}) {
    final w = messageBubbleWidth(hasPreview: hasPreview);
    return size.width - rightMargin - w;
  }
}
