import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather_model.dart';



class WeatherService {

  // ⚠️ Thay YOUR_API_KEY bằng API key của bạn từ https://openweathermap.org/api

  static const String _apiKey = '';

  static const String _baseUrl =

      'https://api.openweathermap.org/data/2.5/weather';

  static const String _geoUrl = 'https://nominatim.openstreetmap.org/reverse';



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

      final locationName = await _fetchLocationName(lat: lat, lon: lon);

      return WeatherModel.fromJson(

        jsonDecode(response.body) as Map<String, dynamic>,

        locationName: locationName,

      );

    } else if (response.statusCode == 401) {

      throw Exception('API key không hợp lệ. Kiểm tra lại YOUR_API_KEY.');

    } else {

      throw Exception(

        'Không thể tải dữ liệu thời tiết (${response.statusCode})',

      );

    }

  }



  Future<String?> _fetchLocationName({

    required double lat,

    required double lon,

  }) async {

    final uri = Uri.parse(

      '$_geoUrl?format=jsonv2&lat=$lat&lon=$lon&accept-language=vi',

    );

    final response = await http.get(

      uri,

      headers: const {'User-Agent': 'ViecNow/1.0 weather feature'},

    );

    if (response.statusCode != 200) return null;



    final data = jsonDecode(response.body);

    if (data is! Map || data['address'] is! Map) return null;



    final address = Map<String, dynamic>.from(data['address'] as Map);

    final ward =

        address['quarter']?.toString() ??

        address['suburb']?.toString() ??

        address['neighbourhood']?.toString();

    final district =

        address['city_district']?.toString() ??

        address['district']?.toString() ??

        address['county']?.toString();

    final city =

        address['city']?.toString() ??

        address['state']?.toString() ??

        address['province']?.toString();



    if (district != null && !district.toLowerCase().contains('quận')) {

      return [

        ward,

        'Quận $district',

        city,

      ].where((part) => part != null && part.trim().isNotEmpty).join(', ');

    }

    return [

      ward,

      district,

      city,

    ].where((part) => part != null && part.trim().isNotEmpty).join(', ');

  }

}


