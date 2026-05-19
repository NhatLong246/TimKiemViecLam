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
    // Nếu màn hình này được push vào, đảm bảo rằng keyword đã được set
    if (_keyword.isNotEmpty && _controller.currentQuery.value != _keyword) {
      _controller.textController.text = _keyword;
      _controller.currentQuery.value = _keyword;
      _controller.performSearch();
    }
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
    final minCtrl = TextEditingController(
      text: _controller.minSalary.value?.toStringAsFixed(0) ?? '',
    );
    final maxCtrl = TextEditingController(
      text: _controller.maxSalary.value?.toStringAsFixed(0) ?? '',
    );
    String selectedLoc = _controller.selectedLocation.value;
    String selectedJobType = _controller.selectedJobType.value;

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setState) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Bộ lọc tìm kiếm',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
                          controller: minCtrl,
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
                          controller: maxCtrl,
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
                    'Khu vực',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children:
                        [
                          'Tất cả',
                          'Hà Nội',
                          'TP.HCM',
                          'Đà Nẵng',
                          'Bình Dương',
                        ].map((loc) {
                          return ChoiceChip(
                            label: Text(loc),
                            selected: selectedLoc == loc,
                            selectedColor: _primary.withOpacity(0.2),
                            onSelected: (val) {
                              setState(() => selectedLoc = loc);
                            },
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Loại công việc',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children:
                        [
                          {'label': 'Tất cả', 'value': 'Tất cả'},
                          {'label': 'Part-time', 'value': 'part_time'},
                          {'label': 'Full-time', 'value': 'full_time'},
                        ].map((type) {
                          return ChoiceChip(
                            label: Text(type['label']!),
                            selected: selectedJobType == type['value'],
                            selectedColor: _primary.withOpacity(0.2),
                            onSelected: (val) {
                              setState(() => selectedJobType = type['value']!);
                            },
                          );
                        }).toList(),
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
                      onPressed: () {
                        final min = double.tryParse(minCtrl.text);
                        final max = double.tryParse(maxCtrl.text);
                        _controller.applyAdvancedFilters(
                          min,
                          max,
                          selectedLoc,
                          selectedJobType,
                        );
                        Get.back();
                      },
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
        },
      ),
    );
  }

  Widget _buildResultsList() {
    return Obx(() {
      if (_controller.isSearching.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final results = _controller.searchResults;

      if (results.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Không tìm thấy công việc nào phù hợp.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        );
      }

      return GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final item = results[index];
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
                          child: Image.asset(
                            'assets/images/banners/default_image.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (item.jobType == 'part_time')
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
                                'PART-TIME',
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
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.salaryDisplay,
                                style: TextStyle(
                                  color: _primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
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
                                item.locationDisplay,
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
    });
  }
}
