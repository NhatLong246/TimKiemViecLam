import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:viecnow/controller/employer_reference_controller.dart';
import 'package:viecnow/data/models/market_rate_model.dart';

// ── Màu candidate (green gradient) ─────────────────────────────────────────────
const _gradientColors = [Color(0xFF2E7D32), Color(0xFF66BB6A)];
const _gradientBegin = Alignment.centerLeft;
const _gradientEnd = Alignment.centerRight;
const _bgColor = Color(0xFFF2F4F8);
const _greenPrimary = Color(0xFF2E7D32);
const _greenAccent = Color(0xFF81C784);

class MarketRateScreen extends StatelessWidget {
  const MarketRateScreen({super.key});

  // ── Category groups ────────────────────────────────────────────────────────
  static const _mainCats = ['all', 'boc_vac', 'lau_don', 'bung_be'];
  static const _subCats = ['phuc_vu', 'pha_che', 'tiep_thi', 'van_chuyen', 'bao_ve', 'other'];

  @override
  Widget build(BuildContext context) {
    final c = Get.put(EmployerReferenceController());

    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(c, context),
          _buildCategoryChips(c),
          _buildSortBar(c),
          Expanded(child: _buildBody(context, c)),
        ],
      ),
    );
  }

  // ── HEADER ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(EmployerReferenceController c, BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: _gradientBegin,
          end: _gradientEnd,
          colors: _gradientColors,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back + Title
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Giá thị trường',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Mặt bằng lương theo khu vực',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  // Refresh button
                  Obx(() => GestureDetector(
                        onTap: c.isLoading.value ? null : c.refresh,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            shape: BoxShape.circle,
                          ),
                          child: c.isLoading.value
                              ? const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh_rounded,
                                  color: Colors.white, size: 20),
                        ),
                      )),
                ],
              ),
              const SizedBox(height: 16),
              // Quick stats
              Obx(() => _buildHeaderStats(c)),
              const SizedBox(height: 16),
              // Search bar
              _buildSearchBar(c, context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStats(EmployerReferenceController c) {
    return Row(
      children: [
        _headerStat(
          Icons.category_rounded,
          '${c.totalCategories}',
          'Danh mục',
        ),
        const SizedBox(width: 10),
        _headerStat(
          Icons.work_outline_rounded,
          '${c.totalActiveJobs}',
          'Vị trí tuyển',
        ),
        const SizedBox(width: 10),
        _headerStat(
          Icons.local_fire_department_rounded,
          '${c.highDemandCount}',
          'Nhu cầu cao',
        ),
      ],
    );
  }

  Widget _headerStat(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: Colors.white.withOpacity(0.25), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(EmployerReferenceController c, BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: c.setSearchQuery,
              style: const TextStyle(fontSize: 14, color: Color(0xFF212121)),
              decoration: const InputDecoration(
                hintText: 'Tìm kiếm vị trí, công việc...',
                hintStyle: TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          // Filter button with active-filter badge
          GestureDetector(
            onTap: () => _showFilterSheet(context, c),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: _gradientBegin,
                        end: _gradientEnd,
                        colors: _gradientColors,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.tune_rounded,
                        color: Colors.white, size: 18),
                  ),
                  Obx(() => c.hasActiveFilter
                      ? Positioned(
                          top: -3,
                          right: -3,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF5252),
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : const SizedBox.shrink()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── SHOW FILTER SHEET ─────────────────────────────────────────────────────────
  void _showFilterSheet(BuildContext context, EmployerReferenceController c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterBottomSheet(controller: c),
    );
  }

  // ── CATEGORY CHIPS ────────────────────────────────────────────────────────────
  Widget _buildCategoryChips(EmployerReferenceController c) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Obx(() {
        final sel = c.selectedCategory.value;
        final isSubSelected = _subCats.contains(sel);
        final isExpanded = c.isOtherCatExpanded.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._mainCats.map((cat) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _catChip(
                          label: kCategoryLabels[cat] ?? cat,
                          isSelected: sel == cat,
                          onTap: () => c.setCategory(cat),
                        ),
                      )),
                  if (_subCats.isNotEmpty && !isExpanded)
                    _catChip(
                      label: 'Khác ▼',
                      isSelected: isSubSelected,
                      onTap: c.toggleOtherCat,
                    ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 230),
              curve: Curves.easeInOut,
              child: isExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 2),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          ..._subCats.map((cat) {
                            final icon = kCategoryIcons[cat] ?? '💼';
                            return _catChip(
                              label: '$icon ${kCategoryLabels[cat] ?? cat}',
                              isSelected: sel == cat,
                              onTap: () => c.setCategory(cat),
                            );
                          }),
                          _catChip(
                            label: '▲ Thu gọn',
                            isSelected: false,
                            onTap: c.toggleOtherCat,
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            if (sel == 'other') ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: TextField(
                  controller: c.otherCategoryTextController,
                  onChanged: (val) => c.setSearchQuery(val),
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Nhập tên công việc khác để tham khảo...',
                    prefixIcon: const Icon(Icons.edit_note_rounded, size: 20, color: _greenPrimary),
                    suffixIcon: Obx(() => c.searchQuery.value.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              c.otherCategoryTextController.clear();
                              c.setSearchQuery('');
                            },
                          )
                        : const SizedBox.shrink()),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _greenPrimary, width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
          ],
        );
      }),
    );
  }

  Widget _catChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  begin: _gradientBegin,
                  end: _gradientEnd,
                  colors: _gradientColors,
                )
              : null,
          color: isSelected ? null : const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : const Color(0xFFA5D6A7),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : _greenPrimary,
          ),
        ),
      ),
    );
  }

  // ── SORT BAR ─────────────────────────────────────────────────────────────────
  Widget _buildSortBar(EmployerReferenceController c) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          Obx(() => Text(
                '${c.filteredItems.length} kết quả',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF424242)),
              )),
          const SizedBox(width: 16),
          Obx(() => _buildSortChip(
                c,
                sort: 'demand',
                label: '🔥 Nhu cầu',
              )),
          const SizedBox(width: 6),
          Obx(() => _buildSortChip(
                c,
                sort: 'salary_desc',
                label: '↑ Lương cao',
              )),
          const SizedBox(width: 6),
          Obx(() => _buildSortChip(
                c,
                sort: 'salary_asc',
                label: '↓ Lương thấp',
              )),
        ],
      ),
    );
  }

  Widget _buildSortChip(EmployerReferenceController c,
      {required String sort, required String label}) {
    final isSelected = c.selectedSortType.value == sort;
    return GestureDetector(
      onTap: () => c.setSortType(sort),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  begin: _gradientBegin,
                  end: _gradientEnd,
                  colors: _gradientColors,
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : const Color(0xFFE0E0E0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _greenPrimary.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF757575),
          ),
        ),
      ),
    );
  }

  // ── BODY ─────────────────────────────────────────────────────────────────────
  Widget _buildBody(BuildContext context, EmployerReferenceController c) {
    return Obx(() {
      if (c.isLoading.value) {
        return const Center(child: _LoadingShimmer());
      }
      if (c.hasError.value) {
        return _buildErrorState(c);
      }
      if (c.filteredItems.isEmpty) {
        return _buildEmptyState();
      }
      return RefreshIndicator(
        onRefresh: c.refresh,
        color: _greenPrimary,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: c.filteredItems.length,
          itemBuilder: (_, i) =>
              _buildRateCard(context, c.filteredItems[i]),
        ),
      );
    });
  }

  // ── MARKET RATE CARD ─────────────────────────────────────────────────────────
  Widget _buildRateCard(BuildContext context, MarketRateItem item) {
    final demandColors = _demandStyle(item.demandLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left accent bar
            Container(
              width: 5,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _gradientColors,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category icon circle
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: _gradientBegin,
                              end: _gradientEnd,
                              colors: _gradientColors,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              kCategoryIcons[item.category] ?? '💼',
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.categoryLabel,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF212121),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined,
                                      size: 13,
                                      color: Color(0xFF9E9E9E)),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      item.locationLabel,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF757575)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Demand badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: demandColors.$1,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(demandColors.$3,
                                  style: const TextStyle(fontSize: 11)),
                              const SizedBox(width: 3),
                              Text(
                                item.demandLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: demandColors.$2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFF0F0F0)),
                    const SizedBox(height: 10),
                    // Salary range
                    Row(
                      children: [
                        const Icon(Icons.payments_outlined,
                            size: 15, color: Color(0xFF9E9E9E)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: ShaderMask(
                            shaderCallback: (bounds) =>
                                const LinearGradient(
                              colors: _gradientColors,
                              begin: _gradientBegin,
                              end: _gradientEnd,
                            ).createShader(bounds),
                            child: Text(
                              item.salaryRangeFormatted,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Bottom info row
                    Row(
                      children: [
                        _infoChip(
                          Icons.work_outline_rounded,
                          '${item.totalActiveJobs} vị trí',
                          const Color(0xFFE8F5E9),
                          _greenPrimary,
                        ),
                        const SizedBox(width: 8),
                        _infoChip(
                          Icons.people_outline_rounded,
                          '${item.totalSlots} chỗ',
                          const Color(0xFFE3F2FD),
                          const Color(0xFF1565C0),
                        ),
                        const SizedBox(width: 8),
                        _infoChip(
                          Icons.show_chart_rounded,
                          'TB: ${_fmtVnd(item.avgSalary)}${item.salaryTypeLabel}',
                          const Color(0xFFE8F5E9),
                          _greenPrimary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
                    colors: _gradientColors,
                    begin: _gradientBegin,
                    end: _gradientEnd)
                .createShader(bounds),
            child: const Icon(Icons.search_off_rounded,
                size: 64, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text('Không tìm thấy kết quả',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF424242))),
          const SizedBox(height: 6),
          const Text('Thử tìm kiếm với từ khóa khác',
              style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
        ],
      ),
    );
  }

  // ── Error State ───────────────────────────────────────────────────────────────
  Widget _buildErrorState(EmployerReferenceController c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 56, color: Color(0xFFC8E6C9)),
            const SizedBox(height: 16),
            const Text('Không thể tải dữ liệu',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF424242))),
            const SizedBox(height: 6),
            Obx(() => Text(c.errorMessage.value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF9E9E9E)))),
            const SizedBox(height: 20),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: _gradientBegin,
                  end: _gradientEnd,
                  colors: _gradientColors,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: c.refresh,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Thử lại',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Demand style helper ──────────────────────────────────────────────────────
  (Color, Color, String) _demandStyle(String level) {
    switch (level) {
      case 'high':
        return (const Color(0xFFFFF3E0), const Color(0xFFE65100), '🔥');
      case 'medium':
        return (const Color(0xFFE8F5E9), const Color(0xFF2E7D32), '✅');
      default:
        return (const Color(0xFFF5F5F5), const Color(0xFF757575), '📉');
    }
  }

  // ── VND inline formatter ─────────────────────────────────────────────────────
  String _fmtVnd(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(amount % 1000000 == 0 ? 0 : 1)}tr';
    }
    if (amount >= 1000) return '${(amount / 1000).round()}.000đ';
    return '${amount.toStringAsFixed(0)}đ';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FILTER BOTTOM SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _FilterBottomSheet extends StatefulWidget {
  final EmployerReferenceController controller;
  const _FilterBottomSheet({required this.controller});

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late String _city;
  late String _salaryType;
  late String _demand;
  late String _category;
  late RangeValues _salaryRange;

  EmployerReferenceController get c => widget.controller;

  static const kVietNamProvinces = [
    'An Giang', 'Bà Rịa - Vũng Tàu', 'Bắc Giang', 'Bắc Kạn', 'Bạc Liêu', 'Bắc Ninh',
    'Bến Tre', 'Bình Định', 'Bình Dương', 'Bình Phước', 'Bình Thuận', 'Cà Mau',
    'Cần Thơ', 'Cao Bằng', 'Đà Nẵng', 'Đắk Lắk', 'Đắk Nông', 'Điện Biên', 'Đồng Nai',
    'Đồng Tháp', 'Gia Lai', 'Hà Giang', 'Hà Nam', 'Hà Nội', 'Hà Tĩnh', 'Hải Dương',
    'Hải Phòng', 'Hậu Giang', 'Hòa Bình', 'Hưng Yên', 'Khánh Hòa', 'Kiên Giang',
    'Kon Tum', 'Lai Châu', 'Lâm Đồng', 'Lạng Sơn', 'Lào Cai', 'Long An', 'Nam Định',
    'Nghệ An', 'Ninh Bình', 'Ninh Thuận', 'Phú Thọ', 'Phú Yên', 'Quảng Bình',
    'Quảng Nam', 'Quảng Ngãi', 'Quảng Ninh', 'Quảng Trị', 'Sóc Trăng', 'Sơn La',
    'Tây Ninh', 'Thái Bình', 'Thái Nguyên', 'Thanh Hóa', 'Thừa Thiên Huế', 'Tiền Giang',
    'TP. Hồ Chí Minh', 'Trà Vinh', 'Tuyên Quang', 'Vĩnh Long', 'Vĩnh Phúc', 'Yên Bái'
  ];

  static const _salaryTypes = [
    ('all', 'Tất cả'),
    ('per_hour', '/giờ'),
    ('per_day', '/ngày'),
    ('per_month', '/tháng'),
  ];

  static const _demands = [
    ('all', 'Tất cả'),
    ('high', '🔥 Cao'),
    ('medium', '✅ Bình thường'),
    ('low', '📉 Thấp'),
  ];

  double _getMinForType(String type) {
    final list = c.allItems.where((e) => type == 'all' || e.salaryType == type).toList();
    if (list.isEmpty) {
      if (type == 'per_hour') return 10000.0;
      if (type == 'per_day') return 100000.0;
      if (type == 'per_month') return 1000000.0;
      return 0.0;
    }
    return list.fold(list.first.minSalary, (prev, e) => min(prev, e.minSalary));
  }

  double _getMaxForType(String type) {
    final list = c.allItems.where((e) => type == 'all' || e.salaryType == type).toList();
    if (list.isEmpty) {
      if (type == 'per_hour') return 200000.0;
      if (type == 'per_day') return 2000000.0;
      if (type == 'per_month') return 50000000.0;
      return 15000000.0;
    }
    return list.fold(0.0, (prev, e) => max(prev, e.maxSalary));
  }

  double get _dMin => _getMinForType(_salaryType);
  double get _dMax {
    final m = _getMaxForType(_salaryType);
    return m > _dMin ? m : _dMin + 10000.0;
  }

  bool get _hasRange => _dMax > _dMin;
  bool get _rangeAtDefault =>
      _salaryRange.start <= _dMin && _salaryRange.end >= _dMax;

  late TextEditingController _customCategoryController;

  @override
  void initState() {
    super.initState();
    _city = c.filterCity.value;
    _salaryType = c.filterSalaryType.value;
    _demand = c.filterDemand.value;
    _category = c.selectedCategory.value;
    final dMin = _getMinForType(_salaryType);
    final dMax = _getMaxForType(_salaryType);
    final currentMin = c.filterMinSalary.value;
    final currentMax = c.filterMaxSalary.value;
    _salaryRange = RangeValues(
      currentMin > 0 ? currentMin.clamp(dMin, dMax > dMin ? dMax : dMin + 10000.0) : dMin,
      currentMax > 0 ? currentMax.clamp(dMin, dMax > dMin ? dMax : dMin + 10000.0) : (dMax > dMin ? dMax : dMin + 10000.0),
    );
    _customCategoryController = TextEditingController(
      text: _category == 'other' ? c.searchQuery.value : '',
    );
  }

  @override
  void dispose() {
    _customCategoryController.dispose();
    super.dispose();
  }

  void _onSalaryTypeChanged(String type) {
    setState(() {
      _salaryType = type;
      final newMin = _getMinForType(type);
      final newMax = _getMaxForType(type);
      _salaryRange = RangeValues(newMin, newMax > newMin ? newMax : newMin + 10000.0);
    });
  }

  void _apply() {
    c.setCategory(_category);
    if (_category == 'other') {
      c.setSearchQuery(_customCategoryController.text);
    }
    c.applyAdvancedFilters(
      city: _city,
      salaryType: _salaryType,
      demand: _demand,
      minSalary: (_hasRange && _salaryRange.start > _dMin) ? _salaryRange.start : 0.0,
      maxSalary: (_hasRange && _salaryRange.end < _dMax) ? _salaryRange.end : 0.0,
    );
    Navigator.pop(context);
  }

  void _reset() {
    setState(() {
      _city = 'all';
      _salaryType = 'all';
      _demand = 'all';
      _category = 'all';
      _customCategoryController.clear();
      final dMin = _getMinForType('all');
      final dMax = _getMaxForType('all');
      _salaryRange = RangeValues(dMin, dMax > dMin ? dMax : dMin + 10000.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenH * 0.88),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: _gradientColors,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ).createShader(b),
                  child: const Text(
                    'Bộ lọc tìm kiếm',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _reset,
                  child: const Text(
                    'Xóa tất cả',
                    style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9E9E9E),
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 20, indent: 20, endIndent: 20),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Danh mục công việc ──
                  _sectionTitle(Icons.category_rounded, 'Danh mục công việc'),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _category,
                    dropdownColor: Theme.of(context).cardColor,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF212121),
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _greenPrimary, width: 1.5),
                      ),
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _greenPrimary),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(
                        value: 'all',
                        child: Text('Tất cả danh mục'),
                      ),
                      ...kCategoryLabels.entries.where((e) => e.key != 'all').map((e) {
                        final icon = kCategoryIcons[e.key] ?? '💼';
                        return DropdownMenuItem<String>(
                          value: e.key,
                          child: Text('$icon ${e.value}'),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _category = val;
                          if (val != 'other') {
                            _customCategoryController.clear();
                          }
                        });
                      }
                    },
                  ),
                  if (_category == 'other') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _customCategoryController,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        hintText: 'Nhập tên công việc khác...',
                        hintStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.normal),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _greenPrimary, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // ── Khu vực ──
                  _sectionTitle(Icons.location_on_outlined, 'Khu vực'),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _city == 'all' ? 'all' : (kVietNamProvinces.contains(_city) ? _city : 'all'),
                    dropdownColor: Theme.of(context).cardColor,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF212121),
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _greenPrimary, width: 1.5),
                      ),
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _greenPrimary),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(
                        value: 'all',
                        child: Text('Tất cả khu vực'),
                      ),
                      ...kVietNamProvinces.map((city) => DropdownMenuItem<String>(
                            value: city,
                            child: Text(city),
                          )),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _city = val);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  // ── Loại lương ──
                  _sectionTitle(Icons.payments_outlined, 'Loại lương'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _salaryTypes.map((e) => _filterChip(
                          label: e.$2,
                          isSelected: _salaryType == e.$1,
                          onTap: () => _onSalaryTypeChanged(e.$1),
                        )).toList(),
                  ),
                  const SizedBox(height: 20),
                  // ── Nhu cầu tuyển dụng ──
                  _sectionTitle(
                      Icons.local_fire_department_outlined, 'Nhu cầu tuyển dụng'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _demands.map((e) => _filterChip(
                          label: e.$2,
                          isSelected: _demand == e.$1,
                          onTap: () => setState(() => _demand = e.$1),
                        )).toList(),
                  ),
                  const SizedBox(height: 20),
                  // ── Khoảng lương ──
                  if (_hasRange) ...[
                    Row(
                      children: [
                        _sectionTitle(Icons.show_chart_rounded, 'Khoảng lương'),
                        const Spacer(),
                        if (!_rangeAtDefault)
                          GestureDetector(
                            onTap: () => setState(
                                () => _salaryRange = RangeValues(_dMin, _dMax)),
                            child: const Text('Đặt lại',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: _greenPrimary,
                                    fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _salaryLabel(_salaryRange.start),
                        const Text('—',
                            style: TextStyle(color: Color(0xFF9E9E9E))),
                        _salaryLabel(_salaryRange.end),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _greenPrimary,
                        inactiveTrackColor: const Color(0xFFC8E6C9),
                        thumbColor: _greenPrimary,
                        overlayColor: _greenPrimary.withOpacity(0.15),
                        rangeThumbShape:
                            const RoundRangeSliderThumbShape(
                                enabledThumbRadius: 10),
                        trackHeight: 4,
                      ),
                      child: RangeSlider(
                        values: _salaryRange,
                        min: _dMin,
                        max: _dMax,
                        divisions: 20,
                        onChanged: (v) => setState(() => _salaryRange = v),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          ),
          // Apply button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: _gradientColors,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ElevatedButton(
                  onPressed: _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    'Áp dụng bộ lọc',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: _greenPrimary),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF212121))),
      ],
    );
  }

  Widget _filterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: _gradientColors,
                )
              : null,
          color: isSelected ? null : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : const Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF424242),
            )),
      ),
    );
  }

  Widget _salaryLabel(double value) {
    String text;
    if (value >= 1000000) {
      text = '${(value / 1000000).toStringAsFixed(1)}tr đ';
    } else if (value >= 1000) {
      text = '${(value / 1000).round()}.000 đ';
    } else {
      text = '${value.toStringAsFixed(0)} đ';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _greenPrimary)),
    );
  }
}

// ── Loading Shimmer ─────────────────────────────────────────────────────────
class _LoadingShimmer extends StatefulWidget {
  const _LoadingShimmer();

  @override
  State<_LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<_LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        duration: const Duration(milliseconds: 1200), vsync: this)
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        itemCount: 5,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 120,
          decoration: BoxDecoration(
            color: Color.lerp(
                const Color(0xFFE8F5E9), const Color(0xFFE3F2FD), _anim.value),
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}
