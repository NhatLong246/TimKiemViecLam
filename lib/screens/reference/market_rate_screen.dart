import 'package:flutter/material.dart';

class MarketRateScreen extends StatefulWidget {
  const MarketRateScreen({super.key});

  @override
  State<MarketRateScreen> createState() => _MarketRateScreenState();
}

class _MarketRateScreenState extends State<MarketRateScreen> {
  final Color _primary = const Color(0xFF2E7D32);
  String _selectedLocation = 'TP. Hồ Chí Minh';
  String _searchQuery = '';

  final List<Map<String, dynamic>> _mockRates = [
    {
      'title': 'Nhân viên phục vụ',
      'category': 'Nhà hàng / Khách sạn',
      'avg': '22.000đ',
      'min': '18.000đ',
      'max': '30.000đ',
      'unit': '/ giờ',
      'trend': 1.5, // Tăng 1.5%
    },
    {
      'title': 'Pha chế (Barista)',
      'category': 'Nhà hàng / Khách sạn',
      'avg': '25.000đ',
      'min': '20.000đ',
      'max': '35.000đ',
      'unit': '/ giờ',
      'trend': 2.0,
    },
    {
      'title': 'Bốc vác kho hàng',
      'category': 'Lao động phổ thông',
      'avg': '350.000đ',
      'min': '250.000đ',
      'max': '500.000đ',
      'unit': '/ ngày',
      'trend': 0.0,
    },
    {
      'title': 'Giao hàng (Shipper)',
      'category': 'Vận tải / Giao nhận',
      'avg': '8.000đ',
      'min': '5.000đ',
      'max': '15.000đ',
      'unit': '/ đơn',
      'trend': -0.5, // Giảm 0.5%
    },
    {
      'title': 'Tạp vụ / Giúp việc',
      'category': 'Lao động phổ thông',
      'avg': '50.000đ',
      'min': '40.000đ',
      'max': '70.000đ',
      'unit': '/ giờ',
      'trend': 1.2,
    },
    {
      'title': 'Bảo vệ',
      'category': 'An ninh / Bảo vệ',
      'avg': '20.000đ',
      'min': '17.000đ',
      'max': '25.000đ',
      'unit': '/ giờ',
      'trend': 0.8,
    },
  ];

  List<Map<String, dynamic>> get _filteredRates {
    if (_searchQuery.isEmpty) return _mockRates;
    return _mockRates.where((rate) {
      final title = rate['title'].toString().toLowerCase();
      final cat = rate['category'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return title.contains(query) || cat.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Giá thị trường',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          Expanded(child: _buildRatesList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Khu vực:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedLocation,
                isDense: true,
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                items: ['Toàn quốc', 'TP. Hồ Chí Minh', 'Hà Nội', 'Đà Nẵng']
                    .map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    })
                    .toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedLocation = newValue;
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Tìm kiếm công việc...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildRatesList() {
    final rates = _filteredRates;
    if (rates.isEmpty) {
      return Center(
        child: Text(
          'Không tìm thấy công việc nào',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rates.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final rate = rates[index];
        final trend = rate['trend'] as double;
        final isUp = trend > 0;
        final isDown = trend < 0;

        Color trendColor = Colors.grey.shade600;
        IconData trendIcon = Icons.remove;

        if (isUp) {
          trendColor = Colors.green;
          trendIcon = Icons.trending_up;
        } else if (isDown) {
          trendColor = Colors.red;
          trendIcon = Icons.trending_down;
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rate['title'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rate['category'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: trendColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(trendIcon, size: 14, color: trendColor),
                        if (trend != 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '${trend.abs()}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: trendColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thấp nhất',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rate['min'],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Trung bình',
                        style: TextStyle(
                          fontSize: 12,
                          color: _primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            rate['avg'],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _primary,
                            ),
                          ),
                          Text(
                            rate['unit'],
                            style: TextStyle(
                              fontSize: 12,
                              color: _primary.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Cao nhất',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rate['max'],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
