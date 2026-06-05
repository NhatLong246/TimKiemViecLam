import 'package:flutter/material.dart';
import 'package:viecnow/data/models/weather_model.dart';
import 'package:viecnow/data/services/weather_service.dart';

class WeatherDetailScreen extends StatefulWidget {
  final WeatherModel weather;
  const WeatherDetailScreen({super.key, required this.weather});

  @override
  State<WeatherDetailScreen> createState() => _WeatherDetailScreenState();
}

class _WeatherDetailScreenState extends State<WeatherDetailScreen> {
  final _service = WeatherService();
  late WeatherModel _weather;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _weather = widget.weather;
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final w = await _service.fetchWeather();
      if (mounted) {
        setState(() {
          _weather = w;
          _refreshing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Color get _bgColor {
    final code = _weather.conditionCode;
    if (code == 800) return const Color(0xFF1E88E5);
    if (code < 300) return const Color(0xFF546E7A);
    if (code < 600) return const Color(0xFF37474F);
    return const Color(0xFF42A5F5);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgColor, _bgColor.withValues(alpha: 0.75)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Column(
                      children: [
                        _buildMainCard(),
                        const SizedBox(height: 20),
                        _buildDetailsGrid(),
                        const SizedBox(height: 20),
                        _buildHint(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Dự báo thời tiết',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _refreshing
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _refresh,
                ),
        ],
      ),
    );
  }

  Widget _buildMainCard() {
    return Column(
      children: [
        Text(_weather.emoji, style: const TextStyle(fontSize: 80)),
        const SizedBox(height: 8),
        Text(
          _weather.tempDisplay,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 72,
            fontWeight: FontWeight.w200,
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _weather.description.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on, color: Colors.white70, size: 16),
            const SizedBox(width: 4),
            Text(
              _weather.cityName,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailsGrid() {
    final items = [
      _DetailItem(
        Icons.thermostat_outlined,
        'Cảm giác như',
        '${_weather.feelsLike.round()}°C',
      ),
      _DetailItem(Icons.water_drop_outlined, 'Độ ẩm', '${_weather.humidity}%'),
      _DetailItem(Icons.air, 'Gió', '${_weather.windSpeed} m/s'),
      _DetailItem(Icons.location_city_outlined, 'Thành phố', _weather.cityName),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.8,
        children: items.map(_buildDetailTile).toList(),
      ),
    );
  }

  Widget _buildDetailTile(_DetailItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(item.icon, color: Colors.white70, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHint() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.white60, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Kéo xuống để làm mới dữ liệu thời tiết',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailItem {
  final IconData icon;
  final String label;
  final String value;
  const _DetailItem(this.icon, this.label, this.value);
}
