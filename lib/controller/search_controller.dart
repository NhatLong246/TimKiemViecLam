import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SearchController extends GetxController {
  final TextEditingController textController = TextEditingController();

  // Mock auto-complete text database
  final List<String> _autoCompleteDatabase = const [
    'phục vụ',
    'phục vụ nhà hàng',
    'phục vụ quán cafe',
    'bốc vác',
    'bốc vác kho hàng',
    'nhân viên bán hàng',
    'nhân viên kho',
    'giao hàng nhanh',
    'pha chế',
  ];

  final RxList<String> autoCompleteResults = <String>[].obs;
  final RxList<String> history = <String>[].obs;
  final RxString currentQuery = ''.obs;

  // For search results screen
  final RxString activeFilter =
      'Liên quan'.obs; // Liên quan, Mới nhất, Mức lương

  @override
  void onInit() {
    super.onInit();
  }

  void updateQuery(String value) {
    currentQuery.value = value;
    if (value.trim().isEmpty) {
      autoCompleteResults.clear();
      return;
    }
    final lower = value.toLowerCase();
    autoCompleteResults.assignAll(
      _autoCompleteDatabase
          .where((item) => item.toLowerCase().contains(lower))
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

    if (navigate) {
      Get.toNamed('/search_results', arguments: keyword);
    }
  }

  void setFilter(String filter) {
    activeFilter.value = filter;
    // Thực tế sẽ gọi lại API/Database để sắp xếp list job
  }

  void clearHistory() => history.clear();

  @override
  void onClose() {
    textController.dispose();
    super.onClose();
  }
}
