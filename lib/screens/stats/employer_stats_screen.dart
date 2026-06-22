import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../common/styles/app_colors.dart';
import '../../controller/employer_stats_controller.dart';
import '../../data/models/employer_stats_model.dart';
import '../../common/widgets/animated_number_text.dart';

class EmployerStatsScreen extends StatelessWidget {
  const EmployerStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(EmployerStatsController());
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Obx(() => CustomScrollView(
            slivers: [
              _buildSliverHeader(ctrl),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _FilterSummaryRow(ctrl: ctrl),
                      const SizedBox(height: 16),
                      if (ctrl.isLoading.value)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 60),
                            child: CircularProgressIndicator(
                              color: AppColors.employerPrimary,
                            ),
                          ),
                        )
                      else ...[
                        _InsightCard(ctrl: ctrl),
                        const SizedBox(height: 16),
                        _SummaryGrid(ctrl: ctrl),
                        const SizedBox(height: 20),
                        _ChartCard(
                          title: 'Biểu đồ chi tiêu & Tuyển dụng',
                          subtitle: 'Cột: số người thuê  •  Đường: chi tiêu',
                          child: _SpendingHiringChart(ctrl: ctrl),
                        ),
                        const SizedBox(height: 16),
                        _ChartCard(
                          title: 'Biểu đồ nạp tiền',
                          subtitle: 'Tổng tiền nạp vào ví theo kỳ',
                          child: _DepositAreaChart(ctrl: ctrl),
                        ),
                        const SizedBox(height: 16),
                        _ChartCard(
                          title: 'Bài đăng tuyển dụng',
                          subtitle: 'Số lượng bài đăng theo kỳ',
                          child: _PostsBarChart(ctrl: ctrl),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          )),
    );
  }

  // ── Sliver header gradient ───────────────────────────────────────────
  SliverAppBar _buildSliverHeader(EmployerStatsController ctrl) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.employerPrimary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.employerGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'Thống kê hoạt động',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Obx(() => Text(
                        '${DateFormat('dd/MM/yyyy').format(ctrl.startDate.value)}'
                        ' – ${DateFormat('dd/MM/yyyy').format(ctrl.endDate.value)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      )),
                ],
              ),
            ),
          ),
        ),
        title: null,
        titlePadding: EdgeInsets.zero,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Period Tabs
// ═══════════════════════════════════════════════════════════════════════════
class _FilterSummaryRow extends StatelessWidget {
  const _FilterSummaryRow({required this.ctrl});
  final EmployerStatsController ctrl;

  String _getFilterDisplayText() {
    if (ctrl.isCustomRange.value) {
      return 'Tự chọn (${DateFormat('dd/MM/yyyy').format(ctrl.startDate.value)} - ${DateFormat('dd/MM/yyyy').format(ctrl.endDate.value)})';
    }

    final start = ctrl.startDate.value;
    final end = ctrl.endDate.value;
    final now = DateTime.now();

    switch (ctrl.period.value) {
      case StatsPeriod.day:
        final isToday = start.year == now.year && start.month == now.month && start.day == now.day;
        return isToday
            ? 'Hôm nay (${DateFormat('dd/MM').format(start)})'
            : DateFormat('dd/MM/yyyy').format(start);
      case StatsPeriod.week:
        final startOfWeekToday = now.subtract(Duration(days: now.weekday - 1));
        final isThisWeek = start.year == startOfWeekToday.year &&
            start.month == startOfWeekToday.month &&
            start.day == startOfWeekToday.day;
        final rangeStr =
            '${DateFormat('dd/MM').format(start)} - ${DateFormat('dd/MM/yyyy').format(end)}';
        return isThisWeek ? 'Tuần này ($rangeStr)' : 'Tuần ($rangeStr)';
      case StatsPeriod.month:
        final isThisMonth = start.year == now.year && start.month == now.month;
        final monthStr = 'Tháng ${start.month}/${start.year}';
        return isThisMonth ? '$monthStr (Tháng này)' : monthStr;
      case StatsPeriod.year:
        final isThisYear = start.year == now.year;
        final yearStr = 'Năm ${start.year}';
        return isThisYear ? '$yearStr (Năm này)' : yearStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      final text = _getFilterDisplayText();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đang lọc theo',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.employerPrimary,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _showFilterBottomSheet(context, ctrl),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: AppColors.employerGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.employerPrimary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.tune, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Lọc',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

void _showFilterBottomSheet(BuildContext context, EmployerStatsController ctrl) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _FilterBottomSheet(ctrl: ctrl),
  );
}

enum FilterMode { day, week, month, year, custom }

extension FilterModeExt on FilterMode {
  String get label {
    switch (this) {
      case FilterMode.day:
        return 'Ngày';
      case FilterMode.week:
        return 'Tuần';
      case FilterMode.month:
        return 'Tháng';
      case FilterMode.year:
        return 'Năm';
      case FilterMode.custom:
        return 'Tự chọn';
    }
  }
}

class _FilterBottomSheet extends StatefulWidget {
  const _FilterBottomSheet({required this.ctrl});
  final EmployerStatsController ctrl;

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late FilterMode _selectedMode;
  late DateTime _selectedDate;
  late DateTime _customStart;
  late DateTime _customEnd;

  @override
  void initState() {
    super.initState();
    if (widget.ctrl.isCustomRange.value) {
      _selectedMode = FilterMode.custom;
      _selectedDate = DateTime.now();
      _customStart = widget.ctrl.startDate.value;
      _customEnd = widget.ctrl.endDate.value;
    } else {
      switch (widget.ctrl.period.value) {
        case StatsPeriod.day:
          _selectedMode = FilterMode.day;
          break;
        case StatsPeriod.week:
          _selectedMode = FilterMode.week;
          break;
        case StatsPeriod.month:
          _selectedMode = FilterMode.month;
          break;
        case StatsPeriod.year:
          _selectedMode = FilterMode.year;
          break;
      }
      _selectedDate = widget.ctrl.startDate.value;
      _customStart = DateTime.now().subtract(const Duration(days: 7));
      _customEnd = DateTime.now();
    }
  }

  void _onPeriodChanged(FilterMode mode) {
    setState(() {
      _selectedMode = mode;
      
      final now = DateTime.now();
      _selectedDate = now;
      if (mode == FilterMode.custom) {
        _customStart = now.subtract(const Duration(days: 7));
        _customEnd = now;
      }
    });
  }

  DateTime _getStartOfPeriod(DateTime date, StatsPeriod period) {
    switch (period) {
      case StatsPeriod.day:
        return DateTime(date.year, date.month, date.day);
      case StatsPeriod.week:
        return date.subtract(Duration(days: date.weekday - 1));
      case StatsPeriod.month:
        return DateTime(date.year, date.month, 1);
      case StatsPeriod.year:
        return DateTime(date.year, 1, 1);
    }
  }

  DateTime _getEndOfPeriod(DateTime date, StatsPeriod period) {
    switch (period) {
      case StatsPeriod.day:
        return DateTime(date.year, date.month, date.day, 23, 59, 59);
      case StatsPeriod.week:
        final start = date.subtract(Duration(days: date.weekday - 1));
        return start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      case StatsPeriod.month:
        return DateTime(date.year, date.month + 1, 0, 23, 59, 59);
      case StatsPeriod.year:
        return DateTime(date.year, 12, 31, 23, 59, 59);
    }
  }

  String _getSelectionLabel() {
    if (_selectedMode == FilterMode.custom) {
      return '${DateFormat('dd/MM/yyyy').format(_customStart)} - ${DateFormat('dd/MM/yyyy').format(_customEnd)}';
    }

    final statsPeriod = _selectedMode == FilterMode.day
        ? StatsPeriod.day
        : _selectedMode == FilterMode.week
            ? StatsPeriod.week
            : _selectedMode == FilterMode.month
                ? StatsPeriod.month
                : StatsPeriod.year;

    final start = _getStartOfPeriod(_selectedDate, statsPeriod);
    final end = _getEndOfPeriod(_selectedDate, statsPeriod);
    final now = DateTime.now();

    switch (statsPeriod) {
      case StatsPeriod.day:
        final isToday = start.year == now.year && start.month == now.month && start.day == now.day;
        return isToday 
            ? 'Hôm nay (${DateFormat('dd/MM/yyyy').format(start)})' 
            : DateFormat('dd/MM/yyyy').format(start);
      case StatsPeriod.week:
        final startOfWeekToday = now.subtract(Duration(days: now.weekday - 1));
        final isThisWeek = start.year == startOfWeekToday.year &&
            start.month == startOfWeekToday.month &&
            start.day == startOfWeekToday.day;
        final rangeStr = '${DateFormat('dd/MM').format(start)} - ${DateFormat('dd/MM/yyyy').format(end)}';
        return isThisWeek ? 'Tuần này ($rangeStr)' : 'Tuần ($rangeStr)';
      case StatsPeriod.month:
        final isThisMonth = start.year == now.year && start.month == now.month;
        final monthStr = 'Tháng ${start.month}/${start.year}';
        return isThisMonth ? '$monthStr (Tháng này)' : monthStr;
      case StatsPeriod.year:
        final isThisYear = start.year == now.year;
        final yearStr = 'Năm ${start.year}';
        return isThisYear ? '$yearStr (Năm này)' : yearStr;
    }
  }

  Future<void> _pickDate() async {
    if (_selectedMode == FilterMode.day) {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate.isAfter(now) ? now : _selectedDate,
        firstDate: DateTime(2020),
        lastDate: now,
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.employerPrimary,
                onPrimary: Colors.white,
                onSurface: Colors.black87,
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) {
        setState(() {
          _selectedDate = picked;
        });
      }
    } else if (_selectedMode == FilterMode.week) {
      _pickWeek();
    } else if (_selectedMode == FilterMode.month) {
      _pickMonth();
    } else if (_selectedMode == FilterMode.year) {
      _pickYear();
    }
  }

  void _pickYear() {
    final currentYear = DateTime.now().year;
    final years = List.generate(currentYear - 2020 + 1, (index) => currentYear - index);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Chọn năm', style: TextStyle(fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SizedBox(
            width: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: years.length,
              itemBuilder: (context, index) {
                final y = years[index];
                final selected = _selectedDate.year == y;
                return ListTile(
                  title: Text('Năm $y', style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                  trailing: selected ? const Icon(Icons.check, color: AppColors.employerPrimary) : null,
                  onTap: () {
                    setState(() {
                      _selectedDate = DateTime(y, 1, 1);
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _pickMonth() {
    showDialog(
      context: context,
      builder: (context) {
        int dialogYear = _selectedDate.year;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Chọn tháng', style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: dialogYear > 2020 ? () {
                          setDialogState(() {
                            dialogYear--;
                          });
                        } : null,
                      ),
                      Text('$dialogYear', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: dialogYear < DateTime.now().year ? () {
                          setDialogState(() {
                            dialogYear++;
                          });
                        } : null,
                      ),
                    ],
                  ),
                ],
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SizedBox(
                width: 300,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final m = index + 1;
                    final isFuture = dialogYear == DateTime.now().year && m > DateTime.now().month;
                    final selected = _selectedDate.year == dialogYear && _selectedDate.month == m;
                    
                    return GestureDetector(
                      onTap: isFuture ? null : () {
                        setState(() {
                          _selectedDate = DateTime(dialogYear, m, 1);
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.employerPrimary
                              : (isFuture ? Colors.grey.shade100 : Colors.grey.shade50),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected ? AppColors.employerPrimary : Colors.grey.shade300,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'T$m',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: selected
                                ? Colors.white
                                : (isFuture ? Colors.grey.shade400 : Colors.black87),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _pickWeek() {
    showDialog(
      context: context,
      builder: (context) {
        int dialogYear = _selectedDate.year;
        int dialogMonth = _selectedDate.month;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final weeks = _getWeeksOfMonth(dialogYear, dialogMonth);
            return AlertDialog(
              title: const Text('Chọn tuần', style: TextStyle(fontWeight: FontWeight.bold)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        DropdownButton<int>(
                          value: dialogMonth,
                          items: List.generate(12, (index) => index + 1).map((m) {
                            return DropdownMenuItem<int>(
                              value: m,
                              child: Text('Tháng $m'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                dialogMonth = val;
                              });
                            }
                          },
                        ),
                        DropdownButton<int>(
                          value: dialogYear,
                          items: List.generate(DateTime.now().year - 2020 + 1, (index) => DateTime.now().year - index).map((y) {
                            return DropdownMenuItem<int>(
                              value: y,
                              child: Text('Năm $y'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                dialogYear = val;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: weeks.length,
                        itemBuilder: (context, index) {
                          final w = weeks[index];
                          final startOfWeekSel = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
                          final selected = startOfWeekSel.year == w.start.year &&
                              startOfWeekSel.month == w.start.month &&
                              startOfWeekSel.day == w.start.day;
                              
                          return ListTile(
                            title: Text(w.label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                            trailing: selected ? const Icon(Icons.check, color: AppColors.employerPrimary) : null,
                            onTap: () {
                              setState(() {
                                _selectedDate = w.start;
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickCustomDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _customStart : _customEnd,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.employerPrimary,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _customStart = picked;
          if (_customStart.isAfter(_customEnd)) {
            _customEnd = _customStart;
          }
        } else {
          _customEnd = picked;
          if (_customEnd.isBefore(_customStart)) {
            _customStart = _customEnd;
          }
        }
      });
    }
  }

  Widget _buildCustomDateButton({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey.shade400 : Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd/MM/yyyy').format(date),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: AppColors.employerPrimary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
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
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bộ lọc thống kê',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Chọn loại thời gian',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade300 : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          // Custom segmented control for periods
          Container(
            height: 46,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: FilterMode.values.map((p) {
                final selected = _selectedMode == p;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onPeriodChanged(p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        gradient: selected ? AppColors.employerGradient : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        p.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.black54),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (_selectedMode == FilterMode.custom) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildCustomDateButton(
                    label: 'Từ ngày',
                    date: _customStart,
                    onTap: () => _pickCustomDate(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCustomDateButton(
                    label: 'Đến ngày',
                    date: _customEnd,
                    onTap: () => _pickCustomDate(false),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          // Selected Value card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Khoảng thời gian đang chọn',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _getSelectionLabel(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (_selectedMode != FilterMode.custom)
                      TextButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.employerPrimary),
                        label: Text(
                          _selectedMode == FilterMode.day
                              ? 'Chọn ngày khác'
                              : _selectedMode == FilterMode.week
                                  ? 'Chọn tuần khác'
                                  : _selectedMode == FilterMode.month
                                      ? 'Chọn tháng khác'
                                      : 'Chọn năm khác',
                          style: const TextStyle(
                            color: AppColors.employerPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.employerGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: FilledButton(
                onPressed: () {
                  if (_selectedMode == FilterMode.custom) {
                    widget.ctrl.applyCustomRange(_customStart, _customEnd);
                  } else {
                    final statsPeriod = _selectedMode == FilterMode.day
                        ? StatsPeriod.day
                        : _selectedMode == FilterMode.week
                            ? StatsPeriod.week
                            : _selectedMode == FilterMode.month
                                ? StatsPeriod.month
                                : StatsPeriod.year;
                    widget.ctrl.applyFilter(statsPeriod, _selectedDate);
                  }
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Áp dụng bộ lọc',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekRange {
  final DateTime start;
  final DateTime end;
  final String label;

  _WeekRange(this.start, this.end, this.label);
}

List<_WeekRange> _getWeeksOfMonth(int year, int month) {
  List<_WeekRange> weeks = [];
  DateTime firstDay = DateTime(year, month, 1);
  DateTime lastDay = DateTime(year, month + 1, 1).subtract(const Duration(days: 1));

  // Find the first Monday on or before firstDay
  DateTime current = firstDay.subtract(Duration(days: firstDay.weekday - 1));

  int weekNum = 1;
  while (current.isBefore(lastDay)) {
    DateTime weekEnd = current.add(const Duration(days: 6));
    weeks.add(_WeekRange(
      DateTime(current.year, current.month, current.day),
      DateTime(weekEnd.year, weekEnd.month, weekEnd.day, 23, 59, 59),
      'Tuần $weekNum (${DateFormat('dd/MM').format(current)} - ${DateFormat('dd/MM').format(weekEnd)})',
    ));
    current = current.add(const Duration(days: 7));
    weekNum++;
  }
  return weeks;
}

// ═══════════════════════════════════════════════════════════════════════════
// Summary Grid 2x3
// ═══════════════════════════════════════════════════════════════════════════
class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.ctrl});
  final EmployerStatsController ctrl;

  @override
  Widget build(BuildContext context) {
    final s = ctrl.summary.value;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.check_circle_outline,
                iconColor: const Color(0xFF4CAF50),
                iconBg: const Color(0xFFE8F5E9),
                label: 'Bài đăng đã duyệt',
                value: s.approvedPosts.toDouble(),
                format: (v) => v.toInt().toString(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.access_time_filled,
                iconColor: const Color(0xFFF44336),
                iconBg: const Color(0xFFFFEBEE),
                label: 'Bài đăng quá hạn',
                value: s.cancelledPosts.toDouble(),
                format: (v) => v.toInt().toString(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.group_outlined,
                iconColor: AppColors.employerPrimary,
                iconBg: const Color(0xFFF3E5F5),
                label: 'Số người đã thuê',
                value: s.totalHired.toDouble(),
                format: (v) => v.toInt().toString(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.wallet_outlined,
                iconColor: AppColors.employerSecondary,
                iconBg: const Color(0xFFE3F2FD),
                label: 'Tổng tiền đã chi',
                value: s.totalSpent,
                format: (v) => ctrl.formatVnd(v),
                valueSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.add_card_outlined,
                iconColor: const Color(0xFF009688),
                iconBg: const Color(0xFFE0F2F1),
                label: 'Tổng tiền đã nạp',
                value: s.totalDeposited,
                format: (v) => ctrl.formatVnd(v),
                valueSize: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.trending_up,
                iconColor: const Color(0xFFFF9800),
                iconBg: const Color(0xFFFFF3E0),
                label: 'Hiệu suất chi',
                value: s.totalDeposited > 0 ? (s.totalSpent / s.totalDeposited * 100) : 0,
                format: (v) => s.totalDeposited > 0 ? '${v.toStringAsFixed(0)}%' : '—',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.ctrl});
  final EmployerStatsController ctrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade100, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.purple.shade200.withOpacity(0.4), blurRadius: 8),
              ],
            ),
            child: Icon(Icons.auto_awesome, color: Colors.purple.shade400, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đánh giá thông minh',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ctrl.insightMessage.value,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.format,
    this.valueSize = 22,
  });
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final double value;
  final String Function(double) format;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.grey,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 4),
                AnimatedNumberText(
                  value,
                  format: format,
                  style: TextStyle(
                    fontSize: valueSize,
                    fontWeight: FontWeight.bold,
                    color: AppColors.dark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Chart Card wrapper
// ═══════════════════════════════════════════════════════════════════════════
class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.grey),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Chart 1: Bar (hired) + Line (spent) overlay
// ═══════════════════════════════════════════════════════════════════════════
class _SpendingHiringChart extends StatelessWidget {
  const _SpendingHiringChart({required this.ctrl});
  final EmployerStatsController ctrl;

  @override
  Widget build(BuildContext context) {
    final data = ctrl.chartData;
    if (data.isEmpty) return _emptyChart();

    final maxHired = data.map((e) => e.hired.toDouble()).reduce((a, b) => a > b ? a : b);
    final maxSpent = data.map((e) => e.spent).reduce((a, b) => a > b ? a : b);
    final spentScale = maxHired > 0 && maxSpent > 0 ? maxHired / maxSpent : 1.0;

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxHired * 1.3).clamp(5, double.infinity),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.dark.withOpacity(0.85),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final pt = data[groupIndex];
                if (rodIndex == 0) {
                  return BarTooltipItem(
                    '${pt.label}\nThuê: ${pt.hired} người\nChi: ${ctrl.formatVnd(pt.spent)}',
                    const TextStyle(color: Colors.white, fontSize: 11),
                  );
                }
                return null;
              },
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: _xInterval(data.length),
                getTitlesWidget: (val, meta) {
                  final i = val.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  
                  final interval = _xInterval(data.length).toInt();
                  if (i % interval != 0) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      data[i].label,
                      style: const TextStyle(fontSize: 9, color: AppColors.grey),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (val, meta) => Text(
                  val.toInt().toString(),
                  style: const TextStyle(fontSize: 9, color: AppColors.grey),
                ),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.withOpacity(0.12),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(data.length, (i) {
            final pt = data[i];
            final spentBar = maxSpent > 0 ? pt.spent * spentScale : 0.0;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: pt.hired.toDouble(),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF42A5F5), Color(0xFF1565C0)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 12,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                BarChartRodData(
                  toY: spentBar,
                  color: AppColors.employerPrimary.withOpacity(0.2),
                  width: 6,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Chart 2: Area (deposited)
// ═══════════════════════════════════════════════════════════════════════════
class _DepositAreaChart extends StatelessWidget {
  const _DepositAreaChart({required this.ctrl});
  final EmployerStatsController ctrl;

  @override
  Widget build(BuildContext context) {
    final data = ctrl.chartData;
    if (data.isEmpty) return _emptyChart();

    final maxVal = data.map((e) => e.deposited).reduce((a, b) => a > b ? a : b);

    final spots = List.generate(
      data.length,
      (i) => FlSpot(i.toDouble(), data[i].deposited),
    );

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          minY: 0,
          maxY: maxVal > 0 ? maxVal * 1.3 : 500000,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.dark.withOpacity(0.85),
              getTooltipItems: (spots) => spots.map((s) {
                final i = s.x.toInt();
                final pt = data[i];
                return LineTooltipItem(
                  '${pt.label}\n${ctrl.formatVnd(pt.deposited)}',
                  const TextStyle(color: Colors.white, fontSize: 11),
                );
              }).toList(),
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: _xInterval(data.length),
                getTitlesWidget: (val, meta) {
                  final i = val.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  
                  final interval = _xInterval(data.length).toInt();
                  if (i % interval != 0) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      data[i].label,
                      style: const TextStyle(fontSize: 9, color: AppColors.grey),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (val, meta) => Text(
                  _shortNum(val),
                  style: const TextStyle(fontSize: 9, color: AppColors.grey),
                ),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.withOpacity(0.12),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              gradient: const LinearGradient(
                colors: [AppColors.employerPrimary, AppColors.employerSecondary],
              ),
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.employerPrimary,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.employerPrimary.withOpacity(0.3),
                    AppColors.employerPrimary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Chart 3: Posts bar chart
// ═══════════════════════════════════════════════════════════════════════════
class _PostsBarChart extends StatelessWidget {
  const _PostsBarChart({required this.ctrl});
  final EmployerStatsController ctrl;

  @override
  Widget build(BuildContext context) {
    final data = ctrl.chartData;
    if (data.isEmpty) return _emptyChart();

    final maxVal = data.map((e) => e.posts.toDouble()).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxVal * 1.4).clamp(5, double.infinity),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.dark.withOpacity(0.85),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final pt = data[groupIndex];
                return BarTooltipItem(
                  '${pt.label}: ${pt.posts} bài',
                  const TextStyle(color: Colors.white, fontSize: 11),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: _xInterval(data.length),
                getTitlesWidget: (val, meta) {
                  final i = val.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  
                  final interval = _xInterval(data.length).toInt();
                  if (i % interval != 0) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      data[i].label,
                      style: const TextStyle(fontSize: 9, color: AppColors.grey),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (val, meta) => Text(
                  val.toInt().toString(),
                  style: const TextStyle(fontSize: 9, color: AppColors.grey),
                ),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.withOpacity(0.12),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(data.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: data[i].posts.toDouble(),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.employerPrimaryLight.withOpacity(0.7),
                      AppColors.employerPrimary,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared helpers
// ═══════════════════════════════════════════════════════════════════════════
Widget _emptyChart() => const SizedBox(
      height: 120,
      child: Center(
        child: Text(
          'Không có dữ liệu trong khoảng thời gian này',
          style: TextStyle(color: AppColors.grey, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ),
    );

double _xInterval(int count) {
  if (count <= 7) return 1;
  if (count <= 14) return 2;
  if (count <= 31) return 5;
  return (count / 6).ceilToDouble();
}

String _shortNum(double val) {
  if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(0)}M';
  if (val >= 1000) return '${(val / 1000).toStringAsFixed(0)}K';
  return val.toStringAsFixed(0);
}
