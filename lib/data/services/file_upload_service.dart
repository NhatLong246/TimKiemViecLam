import 'dart:io';
import 'package:http/http.dart' as http;

class FileUploadService {
  /// Uploads a file to an anonymous storage service (catbox.moe)
  /// and returns the public URL. This is a temporary workaround 
  /// since Firebase Storage is not available on the free tier.
  static Future<String> uploadAnonymous(File file) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('https://catbox.moe/user/api.php'));
      request.fields['reqtype'] = 'fileupload';
      request.files.add(await http.MultipartFile.fromPath('fileToUpload', file.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        final url = await response.stream.bytesToString();
        return url.trim();
      }
      throw Exception('Lỗi khi tải file lên máy chủ tạm: ${response.statusCode}');
    } catch (e) {
      throw Exception('Không thể tải file lên. Vui lòng kiểm tra kết nối mạng. Chi tiết: $e');
    }
  }
}
