import 'package:flutter/material.dart';

class JobCriteriaScreen extends StatefulWidget {
  const JobCriteriaScreen({super.key});

  @override
  State<JobCriteriaScreen> createState() => _JobCriteriaScreenState();
}

class _JobCriteriaScreenState extends State<JobCriteriaScreen> {
  bool _hasExperience = false;

  final TextEditingController _positionController = TextEditingController();
  String? _career;
  String? _location;
  String? _salary;
  String? _workType;
  String? _level;

  static const Color _primary = Color(0xFF2E7D32);
  static const Color _border = Color(0xFFE4E4E4);
  static const Color _hint = Color(0xFFA9A9A9);

  @override
  void dispose() {
    _positionController.dispose();
    super.dispose();
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
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF555555)),
        ),
        title: const Text(
          'Tiêu chí tìm việc',
          style: TextStyle(
            color: Color(0xFF222222),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Kinh nghiệm làm việc'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildExperienceChip(
                            title: 'Chưa có kinh nghiệ...',
                            selected: !_hasExperience,
                            onTap: () => setState(() => _hasExperience = false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildExperienceChip(
                            title: 'Đã có kinh nghiệ...',
                            selected: _hasExperience,
                            onTap: () => setState(() => _hasExperience = true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildRequiredLabel('Vị trí công việc'),
                    const SizedBox(height: 10),
                    _buildTextField(
                      controller: _positionController,
                      hintText: 'Nhập vị trí công việc',
                    ),
                    const SizedBox(height: 24),
                    _buildLabel('Ngành nghề (tối đa 3 ngành nghề)'),
                    const SizedBox(height: 10),
                    _buildDropdownField(
                      value: _career,
                      hintText: 'Chọn ngành nghề',
                      items: const [
                        'IT Phần mềm',
                        'Marketing',
                        'Kế toán',
                        'Nhân sự',
                        'Bán hàng',
                      ],
                      onChanged: (value) => setState(() => _career = value),
                    ),
                    const SizedBox(height: 24),
                    _buildRequiredLabel(
                      'Địa điểm tìm việc (tối đa 5 địa điểm)',
                    ),
                    const SizedBox(height: 10),
                    _buildDropdownField(
                      value: _location,
                      hintText: 'Chọn địa điểm làm việc',
                      items: const [
                        'TP.HCM',
                        'Hà Nội',
                        'Đà Nẵng',
                        'Cần Thơ',
                        'Bình Dương',
                      ],
                      onChanged: (value) => setState(() => _location = value),
                    ),
                    const SizedBox(height: 24),
                    _buildLabel('Mức lương mong muốn'),
                    const SizedBox(height: 10),
                    _buildDropdownField(
                      value: _salary,
                      hintText: 'Chọn mức lương',
                      items: const [
                        'Dưới 5 triệu',
                        '5 - 10 triệu',
                        '10 - 15 triệu',
                        '15 - 20 triệu',
                        'Trên 20 triệu',
                      ],
                      onChanged: (value) => setState(() => _salary = value),
                    ),
                    const SizedBox(height: 24),
                    _buildLabel('Hình thức làm việc'),
                    const SizedBox(height: 10),
                    _buildDropdownField(
                      value: _workType,
                      hintText: 'Chọn hình thức làm việc',
                      items: const [
                        'Toàn thời gian',
                        'Bán thời gian',
                        'Thực tập',
                        'Làm từ xa',
                        'Freelance',
                      ],
                      onChanged: (value) => setState(() => _workType = value),
                    ),
                    const SizedBox(height: 24),
                    _buildLabel('Cấp bậc hiện tại'),
                    const SizedBox(height: 10),
                    _buildDropdownField(
                      value: _level,
                      hintText: 'Chọn cấp bậc hiện tại',
                      items: const [
                        'Thực tập sinh',
                        'Cộng tác viên',
                        'Nhân viên',
                        'Trưởng nhóm',
                        'Quản lý',
                      ],
                      onChanged: (value) => setState(() => _level = value),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Lưu thông tin',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF333333),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildRequiredLabel(String text) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF333333),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceChip({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 38,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? _primary.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: selected ? _primary : _border),
        ),
        child: Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? _primary : const Color(0xFF333333),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 18, color: Color(0xFF333333)),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: _hint, fontSize: 18),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primary),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String hintText,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFC8C8C8)),
      hint: Text(hintText, style: const TextStyle(color: _hint, fontSize: 18)),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 17,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primary),
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: const TextStyle(fontSize: 16)),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
