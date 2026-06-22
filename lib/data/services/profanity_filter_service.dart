import 'dart:core';

class ProfanityFilterService {
  // Bộ từ điển các từ ngữ thô tục, vi phạm thuần phong mỹ tục (tiếng Việt)
  static final List<String> _badWords = [
    'đụ', 'đù', 'đm', 'dkm', 'đkm', 'vcl', 'vl', 'vãi', 'lồn', 'cặc', 'địt', 
    'đĩ', 'phò', 'ca-ve', 'cave', 'chó đẻ', 'mẹ mày', 'cha mày', 'con đĩ',
    'thằng chó', 'đồ lợn', 'ngu như', 'cứt', 'đớp', 'liếm', 'bú', 'sủa',
    'đmm', 'đcm', 'dcm', 'vkl', 'đệch', 'đậu xanh', 'rau má', 'đệt', 'đếch',
    'đéo', 'deo', 'đíu', 'đếk', 'đék', 'cc', 'cl', 'clgt', 'cđm', 'cdm'
  ];

  static bool containsProfanity(String text) {
    if (text.isEmpty) return false;

    // Chuyển về chữ thường để kiểm tra
    final lowerText = text.toLowerCase();
    
    // Tách từ để tránh nhận diện sai (ví dụ: "vải vóc" không phải là "vãi lồn")
    // Thay thế các ký tự đặc biệt bằng khoảng trắng để dễ kiểm tra
    final normalizedText = lowerText.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');
    final words = normalizedText.split(RegExp(r'\s+'));

    for (final word in words) {
      if (_badWords.contains(word)) {
        return true;
      }
    }

    // Kiểm tra các cụm từ dính liền phổ biến (ví dụ: đm, vcl)
    for (final badWord in _badWords) {
      // Chỉ check substring nếu từ khóa >= 3 ký tự (để tránh false positive như 'vl' trong 'vlog')
      if (badWord.length >= 3 && lowerText.contains(badWord)) {
        // Cần loại trừ một số trường hợp dễ sai
        if (_isFalsePositive(lowerText, badWord)) continue;
        return true;
      }
    }

    return false;
  }

  static bool _isFalsePositive(String text, String badWord) {
    // Thêm các luật loại trừ nếu cần thiết
    return false;
  }

  static String censor(String text) {
    String censored = text;
    final lowerText = text.toLowerCase();
    
    for (final badWord in _badWords) {
      if (lowerText.contains(badWord)) {
        // Tạo chuỗi *** có độ dài tương ứng
        final stars = List.filled(badWord.length, '*').join('');
        // Dùng Regex ignore case để replace
        censored = censored.replaceAll(RegExp(badWord, caseSensitive: false), stars);
      }
    }
    return censored;
  }
}
