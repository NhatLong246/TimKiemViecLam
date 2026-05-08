import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationService {
  Future<List<dynamic>> fetchCities() async {
    final response = await http.get(
      Uri.parse('https://provinces.open-api.vn/api/v2/?depth=2'),
    );
    return jsonDecode(response.body);
  }
}
