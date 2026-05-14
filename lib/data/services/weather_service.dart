import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_model.dart';

class WeatherService {
  // ⚠️ Thay YOUR_API_KEY bằng API key của bạn từ https://openweathermap.org/api
  static const String _apiKey = String.fromEnvironment('OPENWEATHER_API_KEY');
  static const String _baseUrl =
      'https://api.openweathermap.org/data/2.5/weather';

  // Tọa độ TP.HCM mặc định
  static const double _defaultLat = 10.7769;
  static const double _defaultLon = 106.7009;

  Future<WeatherModel> fetchWeather({
    double lat = _defaultLat,
    double lon = _defaultLon,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl?lat=$lat&lon=$lon&appid=$_apiKey&units=metric&lang=vi',
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return WeatherModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else if (response.statusCode == 401) {
      throw Exception('API key không hợp lệ. Kiểm tra lại YOUR_API_KEY.');
    } else {
      throw Exception(
        'Không thể tải dữ liệu thời tiết (${response.statusCode})',
      );
    }
  }
}
