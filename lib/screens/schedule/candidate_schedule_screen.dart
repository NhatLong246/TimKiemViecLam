import 'package:flutter/material.dart';

class CandidateScheduleScreen extends StatefulWidget {
  const CandidateScheduleScreen({super.key});

  @override
  State<CandidateScheduleScreen> createState() =>
      _CandidateScheduleScreenState();
}

class _CandidateScheduleScreenState extends State<CandidateScheduleScreen> {
  final Color _primary = const Color(0xFF2E7D32);
  late DateTime _selectedDate;
  late List<DateTime> _weekDates;
  late Map<String, List<Map<String, dynamic>>> _mockShifts;
  int _weekOffset = 0;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _selectedDate = DateTime(today.year, today.month, today.day);

    _generateWeekDates();

    // Dữ liệu giả lập
    _mockShifts = {
      _formatDateKey(_selectedDate): [
        {
          'time': '08:00 - 12:00',
          'title': 'Nhân viên phục vụ nhà hàng',
          'employer': 'Nhà hàng Biển Đông',
          'location': '123 Nguyễn Văn Linh, Quận 7, TP.HCM',
          'status': 'Sắp tới',
          'color': Colors.blue,
        },
        {
          'time': '14:00 - 18:00',
          'title': 'Giao hàng nhanh',
          'employer': 'Shopee Express',
          'location': 'Kho Quận 4, TP.HCM',
          'status': 'Đang diễn ra',
          'color': Colors.orange,
        },
      ],
      _formatDateKey(_selectedDate.add(const Duration(days: 1))): [
        {
          'time': '09:00 - 17:00',
          'title': 'Bốc vác kho hàng',
          'employer': 'Kho Giao Hàng Tiết Kiệm',
          'location': 'KCN Tân Bình, Bình Dương',
          'status': 'Chờ xác nhận',
          'color': Colors.amber,
        },
      ],
      _formatDateKey(_selectedDate.subtract(const Duration(days: 1))): [
        {
          'time': '18:00 - 22:00',
          'title': 'Pha chế quán Cafe',
          'employer': 'The Coffee House',
          'location': 'Quận 1, TP.HCM',
          'status': 'Đã hoàn thành',
          'color': Colors.grey,
        },
      ],
    };
  }

  void _generateWeekDates() {
    final today = DateTime.now();
    // Tìm ngày Thứ 2 của tuần hiện tại
    final monday = today
        .subtract(Duration(days: today.weekday - 1))
        .add(Duration(days: _weekOffset * 7));
    _weekDates = List.generate(7, (index) {
      final d = monday.add(Duration(days: index));
      return DateTime(d.year, d.month, d.day);
    });
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _getWeekdayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'T2';
      case 2:
        return 'T3';
      case 3:
        return 'T4';
      case 4:
        return 'T5';
      case 5:
        return 'T6';
      case 6:
        return 'T7';
      case 7:
        return 'CN';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: const Text(
          'Lịch làm việc',
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
          _buildDateSelector(),
          Expanded(child: _buildShiftsList()),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    // Lấy tên đầy đủ của thứ
    String fullWeekdayName = 'Chủ nhật';
    if (_selectedDate.weekday != 7) {
      fullWeekdayName = 'Thứ ${_selectedDate.weekday + 1}';
    }

    return Column(
      children: [
        // Hiển thị ngày tháng năm đầy đủ khi bấm vào
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '$fullWeekdayName, ${_selectedDate.day} tháng ${_selectedDate.month}, ${_selectedDate.year}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Container(
          color: Colors.white,
          height: 80,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.black54),
                onPressed: () {
                  setState(() {
                    _weekOffset--;
                    _generateWeekDates();
                  });
                },
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _weekDates.map((date) {
                    final isSelected = date.isAtSameMomentAs(_selectedDate);
                    final now = DateTime.now();
                    final isToday = date.isAtSameMomentAs(
                      DateTime(now.year, now.month, now.day),
                    );

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDate = date;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? _primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? _primary
                                  : Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _getWeekdayName(date.weekday),
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${date.day}',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isToday)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white : _primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.black54),
                onPressed: () {
                  setState(() {
                    _weekOffset++;
                    _generateWeekDates();
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShiftsList() {
    final shifts = _mockShifts[_formatDateKey(_selectedDate)] ?? [];

    if (shifts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Không có ca làm việc nào',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: shifts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final shift = shifts[index];
        final Color statusColor = shift['color'];

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thanh màu bên trái hiển thị trạng thái
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              shift['time'],
                              style: TextStyle(
                                color: _primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                shift['status'],
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          shift['title'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.storefront_outlined,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                shift['employer'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                shift['location'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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
      },
    );
  }
}
