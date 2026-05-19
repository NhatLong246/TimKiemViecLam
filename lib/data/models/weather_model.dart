class WeatherModel {
  final double temperature;
  final double feelsLike;
  final int humidity;
  final String description;
  final int conditionCode;
  final String cityName;
  final String locationName;
  final double windSpeed;

  const WeatherModel({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.description,
    required this.conditionCode,
    required this.cityName,
    required this.locationName,
    required this.windSpeed,
  });

  factory WeatherModel.fromJson(
    Map<String, dynamic> json, {
    String? locationName,
  }) {
    final cityName = json['name'] as String;
    return WeatherModel(
      temperature: (json['main']['temp'] as num).toDouble(),
      feelsLike: (json['main']['feels_like'] as num).toDouble(),
      humidity: json['main']['humidity'] as int,
      description: json['weather'][0]['description'] as String,
      conditionCode: json['weather'][0]['id'] as int,
      cityName: cityName,
      locationName: locationName?.isNotEmpty == true ? locationName! : cityName,
      windSpeed: (json['wind']['speed'] as num).toDouble(),
    );
  }

  String get emoji {
    if (conditionCode >= 200 && conditionCode < 300) return '⛈️';
    if (conditionCode >= 300 && conditionCode < 400) return '🌦️';
    if (conditionCode >= 500 && conditionCode < 600) return '🌧️';
    if (conditionCode >= 600 && conditionCode < 700) return '❄️';
    if (conditionCode >= 700 && conditionCode < 800) return '🌫️';
    if (conditionCode == 800) return '☀️';
    if (conditionCode == 801) return '🌤️';
    if (conditionCode == 802) return '⛅';
    return '☁️';
  }

  String get tempDisplay => '${temperature.round()}°C';
}
