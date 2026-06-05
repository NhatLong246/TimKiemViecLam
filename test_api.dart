import 'package:http/http.dart' as http;

void main() async {
  var response = await http.post(
    Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
    headers: {
      'Authorization': '',
      'Content-Type': 'application/json'
    },
    body: '{"model":"z-ai/glm-4.5-air:free","messages":[{"role":"user","content":"hello"}]}'
  );
  print('Status code: ${response.statusCode}');
  print('Response body: ${response.body}');
}
