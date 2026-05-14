import 'package:flutter/material.dart';
import 'package:viecnow/data/models/weather_model.dart';
import 'package:viecnow/data/services/weather_service.dart';
import 'package:viecnow/screens/weather/weather_detail_screen.dart';

class WeatherWidget extends StatefulWidget {
  const WeatherWidget({super.key});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  final _service = WeatherService();
  WeatherModel? _weather;
  bool _loading = true;
  bool _hasError = false;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final w = await _service.fetchWeather();
      if (mounted) {
        setState(() {
          _weather = w;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[Weather] Lỗi: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = true;
          _errorMsg = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_weather != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WeatherDetailScreen(weather: _weather!),
            ),
          );
        } else if (_hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ $_errorMsg'),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Thử lại',
                textColor: Colors.white,
                onPressed: _load,
              ),
            ),
          );
        } else {
          _load();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : _hasError
            ? const Icon(
                Icons.wb_sunny_outlined,
                color: Colors.white70,
                size: 18,
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_weather!.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Text(
                    _weather!.tempDisplay,
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
  }
}
