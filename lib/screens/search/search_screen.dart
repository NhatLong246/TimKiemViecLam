import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controller/search_controller.dart' as dashboard;

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final dashboard.SearchController _controller;
  final Color _primary = const Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _controller = Get.put(dashboard.SearchController());
  }

  @override
  void dispose() {
    if (Get.isRegistered<dashboard.SearchController>()) {
      Get.delete<dashboard.SearchController>();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(context),
              const SizedBox(height: 16),
              _buildHistorySection(),
              const SizedBox(height: 16),
              _buildSuggestionHeader(),
              const SizedBox(height: 12),
              _buildSuggestionGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
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
                  child: TextField(
                    controller: _controller.textController,
                    autofocus: true,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Bạn muốn tìm công việc gì?',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                      border: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                      ),
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (value) {
                      _controller.updateQuery(value);
                    },
                    onSubmitted: (value) {
                      _controller.submitSearch(value);
                    },
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _controller.submitSearch(_controller.textController.text);
                  },
                  child: Container(
                    width: 40,
                    height: 36,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.search,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    return Obx(() {
      if (_controller.history.isEmpty) {
        return Text(
          'Bắt đầu bằng cách nhập từ khóa ở trên. Các tìm kiếm gần đây sẽ xuất hiện tại đây.',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Tìm kiếm gần đây',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton(
                onPressed: _controller.clearHistory,
                child: const Text(
                  'Xóa',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _controller.history
                .map(
                  (keyword) => GestureDetector(
                    onTap: () {
                      _controller.textController.text = keyword;
                      _controller.updateQuery(keyword);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(keyword, style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 4),
                          const Icon(Icons.close, size: 14, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      );
    });
  }

  Widget _buildSuggestionHeader() {
    return Obx(() {
      if (_controller.currentQuery.value.trim().isEmpty) {
        return const SizedBox.shrink();
      }
      return const SizedBox.shrink();
    });
  }

  Widget _buildSuggestionGrid() {
    return Obx(() {
      if (_controller.currentQuery.value.trim().isEmpty) {
        return const SizedBox.shrink();
      }

      final results = _controller.autoCompleteResults;

      if (results.isEmpty) {
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Center(
            child: Text(
              'Không tìm thấy gợi ý nào',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ),
        );
      }

      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: results.length,
        separatorBuilder: (context, index) =>
            Divider(color: Colors.grey.shade200, height: 1),
        itemBuilder: (context, index) {
          final suggestion = results[index];
          final keyword = _controller.currentQuery.value;

          int matchIndex = suggestion.toLowerCase().indexOf(
            keyword.toLowerCase(),
          );

          return InkWell(
            onTap: () {
              _controller.submitSearch(suggestion);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: matchIndex >= 0
                        ? RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                              children: [
                                TextSpan(
                                  text: suggestion.substring(0, matchIndex),
                                ),
                                TextSpan(
                                  text: suggestion.substring(
                                    matchIndex,
                                    matchIndex + keyword.length,
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: suggestion.substring(
                                    matchIndex + keyword.length,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Text(
                            suggestion,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                  ),
                  Icon(Icons.north_west, size: 16, color: Colors.grey.shade400),
                ],
              ),
            ),
          );
        },
      );
    });
  }
}
