import 'dart:math';
import 'package:get/get.dart';
import 'package:viecnow/data/models/market_rate_model.dart';
import 'package:viecnow/data/services/market_rate_service.dart';

// ── Category groups ────────────────────────────────────────────────────────────
const kMainCats = ['all', 'boc_vac', 'lau_don', 'bung_be'];
const kSubCats = ['phuc_vu', 'pha_che', 'tiep_thi', 'van_chuyen', 'bao_ve', 'other'];

/// Controller: EmployerReferenceController
/// Quản lý state cho màn hình Tham khảo giá (E16).
class EmployerReferenceController extends GetxController {
  // ── State ──────────────────────────────────────────────────────────────────
  final isLoading = true.obs;
  final hasError = false.obs;
  final errorMessage = ''.obs;

  final searchQuery = ''.obs;
  final selectedCategory = 'all'.obs;
  final selectedSortType = 'demand'.obs; // "demand" | "salary_asc" | "salary_desc"

  // ── Advanced filters (filter bottom sheet) ─────────────────────────────────
  final filterCity = 'all'.obs;
  final filterSalaryType = 'all'.obs;   // "all" | "per_hour" | "per_day" | "per_month"
  final filterDemand = 'all'.obs;       // "all" | "high" | "medium" | "low"
  final filterMinSalary = 0.0.obs;      // 0.0 = no limit
  final filterMaxSalary = 0.0.obs;      // 0.0 = no limit

  // ── UI state ───────────────────────────────────────────────────────────────
  final isOtherCatExpanded = false.obs;

  final _allItems = <MarketRateItem>[].obs;
  final filteredItems = <MarketRateItem>[].obs;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    loadMarketRates();
    ever(searchQuery, (_) => _applyFilter());
    ever(selectedCategory, (_) => _applyFilter());
    ever(selectedSortType, (_) => _applyFilter());
    ever(filterCity, (_) => _applyFilter());
    ever(filterSalaryType, (_) => _applyFilter());
    ever(filterDemand, (_) => _applyFilter());
    ever(filterMinSalary, (_) => _applyFilter());
    ever(filterMaxSalary, (_) => _applyFilter());
  }

  // ── Load dữ liệu ───────────────────────────────────────────────────────────
  Future<void> loadMarketRates() async {
    isLoading.value = true;
    hasError.value = false;
    try {
      final items = await MarketRateService.fetchMarketRates();
      _allItems.assignAll(items);
      _applyFilter();
    } catch (e) {
      hasError.value = true;
      errorMessage.value = 'Không thể tải dữ liệu. Vui lòng thử lại.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refresh() => loadMarketRates();

  // ── Derived getters ────────────────────────────────────────────────────────
  bool get hasActiveFilter =>
      selectedCategory.value != 'all' ||
      filterCity.value != 'all' ||
      filterSalaryType.value != 'all' ||
      filterDemand.value != 'all' ||
      filterMinSalary.value > 0 ||
      filterMaxSalary.value > 0;

  List<String> get availableCities {
    final cities = _allItems.map((e) => e.city).toSet().toList()..sort();
    return ['all', ...cities];
  }

  double get dataMinSalary {
    if (_allItems.isEmpty) return 0;
    return _allItems.fold(
        _allItems.first.minSalary, (prev, e) => min(prev, e.minSalary));
  }

  double get dataMaxSalary {
    if (_allItems.isEmpty) return 1000000;
    return _allItems.fold(0.0, (prev, e) => max(prev, e.maxSalary));
  }

  int get totalCategories => _allItems.map((e) => e.category).toSet().length;
  int get totalActiveJobs => _allItems.fold(0, (sum, e) => sum + e.totalActiveJobs);
  int get highDemandCount => _allItems.where((e) => e.demandLevel == 'high').length;

  // ── Filter & Sort ──────────────────────────────────────────────────────────
  void _applyFilter() {
    var result = MarketRateService.filterItems(
      items: _allItems,
      query: searchQuery.value,
      category: selectedCategory.value,
    );

    if (filterCity.value != 'all') {
      result = result.where((e) => e.city == filterCity.value).toList();
    }
    if (filterSalaryType.value != 'all') {
      result = result.where((e) => e.salaryType == filterSalaryType.value).toList();
    }
    if (filterDemand.value != 'all') {
      result = result.where((e) => e.demandLevel == filterDemand.value).toList();
    }
    if (filterMinSalary.value > 0) {
      result = result.where((e) => e.maxSalary >= filterMinSalary.value).toList();
    }
    if (filterMaxSalary.value > 0) {
      result = result.where((e) => e.minSalary <= filterMaxSalary.value).toList();
    }

    switch (selectedSortType.value) {
      case 'salary_asc':
        result.sort((a, b) => a.avgSalary.compareTo(b.avgSalary));
        break;
      case 'salary_desc':
        result.sort((a, b) => b.avgSalary.compareTo(a.avgSalary));
        break;
      default:
        result.sort((a, b) => b.totalActiveJobs.compareTo(a.totalActiveJobs));
    }
    filteredItems.assignAll(result);
  }

  // ── Public mutators ────────────────────────────────────────────────────────
  void setCategory(String cat) => selectedCategory.value = cat;
  void setSearchQuery(String q) => searchQuery.value = q;
  void setSortType(String sort) => selectedSortType.value = sort;
  void toggleOtherCat() => isOtherCatExpanded.value = !isOtherCatExpanded.value;

  void applyAdvancedFilters({
    required String city,
    required String salaryType,
    required String demand,
    required double minSalary,
    required double maxSalary,
  }) {
    filterCity.value = city;
    filterSalaryType.value = salaryType;
    filterDemand.value = demand;
    filterMinSalary.value = minSalary;
    filterMaxSalary.value = maxSalary;
  }

  void resetAllFilters() {
    filterCity.value = 'all';
    filterSalaryType.value = 'all';
    filterDemand.value = 'all';
    filterMinSalary.value = 0.0;
    filterMaxSalary.value = 0.0;
    selectedCategory.value = 'all';
    isOtherCatExpanded.value = false;
  }
}

