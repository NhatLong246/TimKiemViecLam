import 'package:flutter/material.dart';

class WorkExperienceScreen extends StatefulWidget {
  const WorkExperienceScreen({super.key});

  @override
  State<WorkExperienceScreen> createState() => _WorkExperienceScreenState();
}

class _WorkExperienceScreenState extends State<WorkExperienceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _positionController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _currentlyWorking = false;
  String _startDate = '';
  String _endDate = '';

  static const Color _primary = Color(0xFF5E35B1);
  static const Color _required = Color(0xFFE64A4A);
  static const Color _border = Color(0xFFD0D0D0);
  static const Color _hintColor = Color(0xFFB0B0B0);

  @override
  void dispose() {
    _companyController.dispose();
    _positionController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickMonthYear(bool isStart) async {
    final now = DateTime.now();
    DateTime selected = DateTime(now.year, now.month);

    final result = await showDialog<DateTime>(
      context: context,
      builder: (ctx) {
        return _MonthYearPickerDialog(initial: selected);
      },
    );

    if (result != null) {
      final formatted =
          '${result.month.toString().padLeft(2, '0')}/${result.year}';
      setState(() {
        if (isStart) {
          _startDate = formatted;
        } else {
          _endDate = formatted;
        }
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate.isEmpty) {
      _showError('Vui lòng chọn ngày bắt đầu');
      return;
    }
    if (!_currentlyWorking && _endDate.isEmpty) {
      _showError('Vui lòng chọn ngày kết thúc');
      return;
    }
    Navigator.pop(context);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF666666)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Kinh nghiệm làm việc',
          style: TextStyle(
            color: Color(0xFF222222),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Tên công ty'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _companyController,
                hint: 'Nhập tên công ty',
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Vui lòng nhập tên công ty' : null,
              ),
              const SizedBox(height: 20),
              _buildLabel('Vị trí công việc'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _positionController,
                hint: 'Nhập vị trí công việc',
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Vui lòng nhập vị trí công việc' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: _currentlyWorking,
                      activeColor: _primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (v) {
                        setState(() {
                          _currentlyWorking = v ?? false;
                          if (_currentlyWorking) _endDate = '';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Tôi đang làm việc ở đây',
                    style: TextStyle(fontSize: 15, color: Color(0xFF333333)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Ngày bắt đầu'),
                        const SizedBox(height: 8),
                        _buildDateField(
                          value: _startDate,
                          onTap: () => _pickMonthYear(true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Ngày kết thúc'),
                        const SizedBox(height: 8),
                        _buildDateField(
                          value: _currentlyWorking ? '' : _endDate,
                          onTap: _currentlyWorking ? null : () => _pickMonthYear(false),
                          disabled: _currentlyWorking,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildLabel('Mô tả kinh nghiệm'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                minLines: 4,
                maxLines: 8,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Vui lòng nhập mô tả' : null,
                decoration: InputDecoration(
                  hintText: 'Nhập mô tả kinh nghiệm',
                  hintStyle: const TextStyle(color: _hintColor, fontSize: 15),
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '✨ Gợi ý:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3A3A3A),
                      ),
                    ),
                    SizedBox(height: 6),
                    _BulletText('Mô tả 3 - 5 công việc hằng ngày của bạn'),
                    _BulletText('Bạn làm việc với phòng ban nào?'),
                    _BulletText('Bạn báo cáo tiến độ công việc cho ai?'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Lưu thông tin',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF222222),
        ),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: _required),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _hintColor, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _required),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String value,
    VoidCallback? onTap,
    bool disabled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: disabled ? const Color(0xFFF5F5F5) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value.isEmpty ? 'MM/YYYY' : value,
                style: TextStyle(
                  fontSize: 15,
                  color: value.isEmpty
                      ? (disabled ? const Color(0xFFCCCCCC) : _hintColor)
                      : const Color(0xFF222222),
                ),
              ),
            ),
            Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: disabled ? const Color(0xFFCCCCCC) : const Color(0xFF888888),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletText extends StatelessWidget {
  final String text;
  const _BulletText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 13, color: Color(0xFF555555))),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthYearPickerDialog extends StatefulWidget {
  final DateTime initial;
  const _MonthYearPickerDialog({required this.initial});

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int _year;
  late int _month;

  static const Color _primary = Color(0xFF5E35B1);

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
    _month = widget.initial.month;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _year--),
          ),
          Text(
            '$_year',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => _year++),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: List.generate(12, (i) {
            final m = i + 1;
            final selected = m == _month;
            return GestureDetector(
              onTap: () => setState(() => _month = m),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? _primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? _primary : const Color(0xFFD0D0D0),
                  ),
                ),
                child: Text(
                  'T$m',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : const Color(0xFF333333),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy', style: TextStyle(color: Color(0xFF888888))),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, DateTime(_year, _month)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Chọn'),
        ),
      ],
    );
  }
}
