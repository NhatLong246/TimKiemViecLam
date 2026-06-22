import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controller/search_controller.dart' as dashboard;
import '../../routes/app_routes.dart';
import '../../data/constants/job_categories.dart' as job_cats;
import '../../data/constants/language_proficiency_levels.dart';

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                color: Theme.of(context).cardColor,
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
                  color: Theme.of(context).cardColor,
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
    final List<String> provinces = [
      'Tất cả', 'Hà Nội', 'TP.HCM', 'Đà Nẵng', 'Hải Phòng', 'Cần Thơ',
      'An Giang', 'Bà Rịa - Vũng Tàu', 'Bắc Giang', 'Bắc Kạn', 'Bạc Liêu', 'Bắc Ninh',
      'Bến Tre', 'Bình Định', 'Bình Dương', 'Bình Phước', 'Bình Thuận', 'Cà Mau',
      'Cao Bằng', 'Đắk Lắk', 'Đắk Nông', 'Điện Biên', 'Đồng Nai', 'Đồng Tháp',
      'Gia Lai', 'Hà Giang', 'Hà Nam', 'Hà Tĩnh', 'Hải Dương', 'Hậu Giang',
      'Hòa Bình', 'Hưng Yên', 'Khánh Hòa', 'Kiên Giang', 'Kon Tum', 'Lai Châu',
      'Lâm Đồng', 'Lạng Sơn', 'Lào Cai', 'Long An', 'Nam Định', 'Nghệ An',
      'Ninh Bình', 'Ninh Thuận', 'Phú Thọ', 'Phú Yên', 'Quảng Bình', 'Quảng Nam',
      'Quảng Ngãi', 'Quảng Ninh', 'Quảng Trị', 'Sóc Trăng', 'Sơn La', 'Tây Ninh',
      'Thái Bình', 'Thái Nguyên', 'Thanh Hóa', 'Thừa Thiên Huế', 'Tiền Giang',
      'Trà Vinh', 'Tuyên Quang', 'Vĩnh Long', 'Vĩnh Phúc', 'Yên Bái'
    ];

    double? tempMinSalary = _controller.minSalary.value;
    double? tempMaxSalary = _controller.maxSalary.value;
    String selectedLoc = _controller.selectedLocation.value;
    String selectedJobType = _controller.selectedJobType.value;
    String selectedCategory = _controller.selectedCategory.value;
    String selectedGender = _controller.selectedGender.value;
    String selectedLanguage = _controller.selectedLanguage.value;
    String selectedLanguageLevel = _controller.selectedLanguageLevel.value;
    String selectedExperience = _controller.selectedExperience.value;

    // Convert old values from previous state
    if (selectedJobType == 'part_time') selectedJobType = 'Part-time';
    if (selectedJobType == 'full_time') selectedJobType = 'Full-time';

    final minCtrl = TextEditingController(text: tempMinSalary?.toInt().toString() ?? '');
    final maxCtrl = TextEditingController(text: tempMaxSalary?.toInt().toString() ?? '');

    Get.bottomSheet(
      isScrollControlled: true,
      StatefulBuilder(
        builder: (context, setState) {
          Widget buildChoiceChip(String label, String currentVal, Function(String) onSelect) {
            final isSelected = currentVal == label;
            return ChoiceChip(
              label: Text(
                isSelected && label == 'Tất cả' ? '✓ Tất cả' : label,
                style: TextStyle(
                  color: isSelected ? Colors.black87 : Colors.black54,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFFC8E6C9),
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF81C784) : Colors.grey.shade300,
                ),
              ),
              onSelected: (_) => onSelect(label),
            );
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bộ lọc tìm kiếm',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        GestureDetector(
                          onTap: () => Get.back(),
                          child: const Icon(Icons.expand_more, size: 28),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Khoảng mức lương (VNĐ)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'TỐI THIỂU',
                              filled: true,
                              fillColor: Colors.transparent,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.green.shade200),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.green.shade200),
                              ),
                            ),
                            onChanged: (val) => tempMinSalary = double.tryParse(val),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text('-', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          child: TextField(
                            controller: maxCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'TỐI ĐA',
                              filled: true,
                              fillColor: Colors.transparent,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.green.shade200),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.green.shade200),
                              ),
                            ),
                            onChanged: (val) => tempMaxSalary = double.tryParse(val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    const Text('Khu vực', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: provinces.contains(selectedLoc) ? selectedLoc : 'Tất cả',
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green.shade200),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_drop_down),
                      isExpanded: true,
                      items: provinces.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedLoc = val);
                      },
                    ),
                    const SizedBox(height: 24),

                    const Text('Loại công việc', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        buildChoiceChip('Tất cả', selectedJobType, (val) => setState(() => selectedJobType = val)),
                        buildChoiceChip('Part-time', selectedJobType, (val) => setState(() => selectedJobType = val)),
                        buildChoiceChip('Full-time', selectedJobType, (val) => setState(() => selectedJobType = val)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    const Text('Danh mục nghề nghiệp', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: job_cats.kCategoryLabels.containsKey(selectedCategory)
                          ? selectedCategory
                          : 'all',
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green.shade200),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_drop_down),
                      isExpanded: true,
                      items: job_cats.kCategoryLabels.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedCategory = val);
                      },
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Yêu cầu giới tính',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        buildChoiceChip(
                          'Tất cả',
                          selectedGender,
                          (val) => setState(() => selectedGender = val),
                        ),
                        buildChoiceChip(
                          'Nam',
                          selectedGender,
                          (val) => setState(() => selectedGender = val),
                        ),
                        buildChoiceChip(
                          'Nữ',
                          selectedGender,
                          (val) => setState(() => selectedGender = val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    const Text('Kinh nghiệm yêu cầu', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedExperience,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green.shade200),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_drop_down),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'Tất cả', child: Text('Tất cả')),
                        DropdownMenuItem(value: 'no_exp', child: Text('Chưa có kinh nghiệm')),
                        DropdownMenuItem(value: 'under_1', child: Text('Dưới 1 năm')),
                        DropdownMenuItem(value: '1_to_3', child: Text('1 - 3 năm')),
                        DropdownMenuItem(value: '3_to_5', child: Text('3 - 5 năm')),
                        DropdownMenuItem(value: 'over_5', child: Text('Trên 5 năm')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => selectedExperience = val);
                      },
                    ),
                    const SizedBox(height: 24),

                    const Text('Yêu cầu ngoại ngữ', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedLanguage,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green.shade200),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_drop_down),
                      isExpanded: true,
                      items: ['Tất cả', ...LanguageProficiencyLevels.languageOptions].map((lang) {
                        return DropdownMenuItem<String>(
                          value: lang,
                          child: Text(lang),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            selectedLanguage = val;
                            selectedLanguageLevel = 'Tất cả';
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    const Text('Trình độ ngoại ngữ yêu cầu', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedLanguageLevel,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green.shade200),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_drop_down),
                      isExpanded: true,
                      items: () {
                        final List<String> levels = ['Tất cả'];
                        if (selectedLanguage != 'Tất cả') {
                          if (selectedLanguage == 'Tiếng Anh') {
                            levels.addAll(['A1', 'A2', 'B1', 'B2', 'C1', 'C2', 'IELTS', 'TOEIC']);
                          } else {
                            levels.addAll(LanguageProficiencyLevels.forLanguage(selectedLanguage));
                          }
                        }
                        return levels.map((lvl) {
                          return DropdownMenuItem<String>(
                            value: lvl,
                            child: Text(lvl),
                          );
                        }).toList();
                      }(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => selectedLanguageLevel = val);
                        }
                      },
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          _controller.applyAdvancedFilters(
                            tempMinSalary,
                            tempMaxSalary,
                            selectedLoc,
                            selectedJobType,
                            selectedCategory,
                            selectedGender,
                            selectedLanguage,
                            selectedLanguageLevel,
                            selectedExperience,
                          );
                          Get.back();
                        },
                        child: const Text(
                          'Áp dụng',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
                color: Theme.of(context).cardColor,
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
                          child: _buildJobImage(item.imageUrls),
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

  Widget _buildJobImage(List<String> imageUrls) {
    if (imageUrls.isEmpty) {
      return Image.asset(
        'assets/images/banners/default_image.png',
        fit: BoxFit.cover,
      );
    }
    final img = imageUrls.first;
    if (img.startsWith('http')) {
      return Image.network(
        img,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => Image.asset(
          'assets/images/banners/default_image.png',
          fit: BoxFit.cover,
        ),
      );
    }
    try {
      var b64 = img;
      if (b64.contains(',')) b64 = b64.split(',').last;
      final sanitized = b64.replaceAll(RegExp(r'\s+'), '');
      final padded = sanitized.padRight(
        sanitized.length + (4 - sanitized.length % 4) % 4,
        '=',
      );
      return Image.memory(
        base64Decode(padded),
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => Image.asset(
          'assets/images/banners/default_image.png',
          fit: BoxFit.cover,
        ),
      );
    } catch (_) {
      return Image.asset(
        'assets/images/banners/default_image.png',
        fit: BoxFit.cover,
      );
    }
  }
}
