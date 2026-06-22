import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:viecnow/controller/home_controller.dart';
import 'package:viecnow/screens/weather/weather_detail_screen.dart';

class WeatherWidget extends StatelessWidget {
  const WeatherWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final homeController = Get.find<HomeController>();

    return Obx(() {
      final weather = homeController.weather.value;
      final loading = homeController.isLoadingWeather.value;
      final errorMsg = homeController.weatherError.value;
      final hasError = errorMsg.isNotEmpty;

      return GestureDetector(
        onTap: () {
          if (weather != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WeatherDetailScreen(weather: weather),
              ),
            );
          } else if (hasError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ $errorMsg'),
                backgroundColor: Colors.redAccent,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Thử lại',
                  textColor: Colors.white,
                  onPressed: homeController.fetchWeather,
                ),
              ),
            );
          } else {
            homeController.fetchWeather();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
          ),
          child: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : hasError
              ? const Icon(
                  Icons.wb_sunny_outlined,
                  color: Colors.white70,
                  size: 18,
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(weather!.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 4),
                    Text(
                      weather.tempDisplay,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      );
    });
  }
}

