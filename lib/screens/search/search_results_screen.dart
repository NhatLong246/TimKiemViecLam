import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controller/search_controller.dart' as dashboard;
import '../../routes/app_routes.dart';

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({super.key});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final dashboard.SearchController _controller =
      Get.find<dashboard.SearchController>();
  final Color _primary = const Color(0xFF2E7D32); // Xanh lá Home

  late String _keyword;

  @override
  void initState() {
    super.initState();
    _keyword = Get.arguments as String? ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildFilterTabs(),
            Expanded(child: _buildResultsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                size: 18,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => Get.back(),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _primary, width: 1.2),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _keyword,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _showFilterBottomSheet,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.filter_alt_outlined, color: _primary, size: 24),
                Text(
                  'Lọc',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    final filters = ['Liên quan', 'Mới nhất', 'Mức lương'];
    return Container(
      color: Colors.white,
      height: 44,
      child: Obx(() {
        return Row(
          children: filters.map((filter) {
            final isActive = _controller.activeFilter.value == filter;
            return Expanded(
              child: GestureDetector(
                onTap: () => _controller.setFilter(filter),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isActive ? _primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        filter,
                        style: TextStyle(
                          color: isActive ? _primary : Colors.black87,
                          fontWeight: isActive
                              ? FontWeight.w500
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                      if (filter == 'Mức lương') ...[
                        const SizedBox(width: 2),
                        Icon(
                          Icons.unfold_more,
                          size: 14,
                          color: isActive ? _primary : Colors.black87,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      }),
    );
  }

  void _showFilterBottomSheet() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bộ lọc tìm kiếm',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Khoảng mức lương (VNĐ)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'TỐI THIỂU',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('-'),
                ),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'TỐI ĐA',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Khoảng cách',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Gần tôi (< 5km)'),
                  selected: false,
                  onSelected: (val) {},
                ),
                ChoiceChip(
                  label: const Text('Trong thành phố'),
                  selected: true,
                  selectedColor: _primary.withOpacity(0.2),
                  onSelected: (val) {},
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Get.back(),
                child: const Text(
                  'Áp dụng',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    // Giả lập danh sách kết quả cho keyword
    final List<Map<String, dynamic>> mockResults = [
      {
        'title': 'Nhân viên phục vụ nhà hàng',
        'salary': '250.000đ/ngày',
        'sold': '10+ đã ứng tuyển',
        'location': 'Thành phố Hồ Chí Minh',
        'type': 'Part-time',
        'image': 'assets/images/banners/default_image.png',
        'isHot': false,
        'discount': 'Tuyển gấp',
      },
      {
        'title': 'Pha chế quán Cafe',
        'salary': '300.000đ/ngày',
        'sold': '5+ đã ứng tuyển',
        'location': 'Hà Nội',
        'type': 'Full-time',
        'image': 'assets/images/banners/default_image.png',
        'isHot': true,
        'discount': '',
      },
      {
        'title': 'Bốc vác kho hàng',
        'salary': '500.000đ/ngày',
        'sold': '2+ đã ứng tuyển',
        'location': 'Bình Dương',
        'type': 'Thời vụ',
        'image': 'assets/images/banners/default_image.png',
        'isHot': false,
        'discount': 'Hỗ trợ ăn trưa',
      },
      {
        'title': 'Nhân viên bán hàng thời trang',
        'salary': '200.000đ/ngày',
        'sold': '15+ đã ứng tuyển',
        'location': 'Đà Nẵng',
        'type': 'Part-time',
        'image': 'assets/images/banners/default_image.png',
        'isHot': true,
        'discount': 'Thưởng doanh số',
      },
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: mockResults.length,
      itemBuilder: (context, index) {
        final item = mockResults[index];
        return GestureDetector(
          onTap: () {
            // Chuyển hướng sang màn hình chi tiết công việc
            Get.toNamed(AppRoutes.jobDetail, arguments: item);
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image placeholder
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        color: Colors.grey.shade200,
                        child: Image.asset(item['image'], fit: BoxFit.cover),
                      ),
                      if (item['isHot'])
                        Positioned(
                          top: 0,
                          left: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF57F17),
                              borderRadius: BorderRadius.only(
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'HOT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (item['discount'].isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEECEE),
                                border: Border.all(
                                  color: _primary.withOpacity(0.5),
                                ),
                              ),
                              margin: const EdgeInsets.only(right: 6),
                              child: Text(
                                item['discount'],
                                style: TextStyle(color: _primary, fontSize: 9),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item['salary'],
                              style: TextStyle(
                                color: _primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item['sold'],
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              item['location'],
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
