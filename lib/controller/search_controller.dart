import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../data/models/job_post_model.dart';
import '../data/services/search_service.dart';

class SearchController extends GetxController {
  final TextEditingController textController = TextEditingController();
  final SearchService _searchService = SearchService();

  // Autocomplete suggestions (mock / cache)
  final List<String> _autoCompleteDatabase = const [
    'phục vụ',
    'bốc vác',
    'bán hàng',
    'pha chế',
    'part-time',
    'full-time',
  ];

  final RxList<String> autoCompleteResults = <String>[].obs;
  final RxList<String> history = <String>[].obs;
  final RxString currentQuery = ''.obs;

  // Search Results
  final RxList<JobPostModel> searchResults = <JobPostModel>[].obs;
  final RxBool isSearching = false.obs;

  // Filters
  final RxString activeFilter =
      'Liên quan'.obs; // Liên quan, Mới nhất, Mức lương
  final Rx<double?> minSalary = Rx<double?>(null);
  final Rx<double?> maxSalary = Rx<double?>(null);
  final RxString selectedLocation = 'Tất cả'.obs;
  final RxString selectedJobType = 'Tất cả'.obs;

  @override
  void onInit() {
    super.onInit();
    // Load history từ SharedPreferences nếu cần
  }

  // Helper để loại bỏ dấu tiếng Việt
  String _removeDiacritics(String str) {
    const withDia =
        'áàảãạăắằẳẵặâấầẩẫậêếềểễệéèẻẽẹíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬÊẾỀỂỄỆÉÈẺẼẸÍÌỈĨỊÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢÚÙỦŨỤƯỨỪỬỮỰÝỲỶỸỴĐ';
    const withoutDia =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';

    String result = str;
    for (int i = 0; i < withDia.length; i++) {
      result = result.replaceAll(withDia[i], withoutDia[i]);
    }
    return result;
  }

  void updateQuery(String value) {
    currentQuery.value = value;
    if (value.trim().isEmpty) {
      autoCompleteResults.clear();
      return;
    }
    final normalizedInput = _removeDiacritics(value).toLowerCase();
    autoCompleteResults.assignAll(
      _autoCompleteDatabase
          .where(
            (item) =>
                _removeDiacritics(item).toLowerCase().contains(normalizedInput),
          )
          .toList(),
    );
  }

  void submitSearch(String value, {bool navigate = true}) {
    final keyword = value.trim();
    if (keyword.isEmpty) return;

    history.remove(keyword);
    history.insert(0, keyword);
    if (history.length > 10) {
      history.removeLast();
    }

    textController.text = keyword;
    autoCompleteResults.clear();
    currentQuery.value = keyword;

    if (navigate) {
      Get.toNamed('/search_results', arguments: keyword);
    }

    // Gọi API search
    performSearch();
  }

  Future<void> performSearch() async {
    isSearching.value = true;
    try {
      final results = await _searchService.searchJobs(
        keyword: currentQuery.value,
        minSalary: minSalary.value,
        maxSalary: maxSalary.value,
        location: selectedLocation.value,
        jobType: selectedJobType.value,
      );

      // Sắp xếp theo active filter
      if (activeFilter.value == 'Mới nhất') {
        results.sort(
          (a, b) => (b.createdAt ?? DateTime(2000)).compareTo(
            a.createdAt ?? DateTime(2000),
          ),
        );
      } else if (activeFilter.value == 'Mức lương') {
        results.sort((a, b) => b.salary.compareTo(a.salary));
      }

      searchResults.assignAll(results);
    } catch (e) {
      print('Lỗi search: $e');
      searchResults.clear();
    } finally {
      isSearching.value = false;
    }
  }

  void setFilter(String filter) {
    activeFilter.value = filter;
    performSearch(); // Tìm kiếm và sort lại
  }

  void applyAdvancedFilters(
    double? min,
    double? max,
    String location,
    String jobType,
  ) {
    minSalary.value = min;
    maxSalary.value = max;
    selectedLocation.value = location;
    selectedJobType.value = jobType;
    performSearch();
  }

  void clearHistory() => history.clear();

  @override
  void onClose() {
    textController.dispose();
    super.onClose();
  }
}
