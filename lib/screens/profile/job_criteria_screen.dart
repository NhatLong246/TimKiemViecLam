import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:viecnow/controller/update_account_controller.dart';
import 'package:viecnow/data/models/job_criteria_model.dart';
import 'job_criteria_options.dart';
import 'job_criteria_pickers.dart';

class JobCriteriaScreen extends StatefulWidget {
  const JobCriteriaScreen({super.key});

  @override
  State<JobCriteriaScreen> createState() => _JobCriteriaScreenState();
}

class _JobCriteriaScreenState extends State<JobCriteriaScreen> {
  bool _hasExperience = false;
  bool _loading = true;
  bool _saving = false;
  bool _resetting = false;

  final TextEditingController _positionController = TextEditingController();
  final List<String> _careers = [];
  final List<String> _locations = [];
  final List<String> _workTypes = [];
  double? _salaryMin;
  double? _salaryMax;
  bool _salaryNegotiable = false;
  String? _level;

  static const Color _primary = JobCriteriaOptions.primary;
  static const Color _border = Color(0xFFE4E4E4);
  static const Color _hint = Color(0xFFA9A9A9);

  static const List<String> _workTypeOptions = [
    'Toàn thời gian',
    'Bán thời gian',
    'Thực tập',
    'Làm từ xa',
    'Freelance',
  ];

  static const List<String> _levelOptions = [
    'Thực tập sinh',
    'Cộng tác viên',
    'Nhân viên',
    'Trưởng nhóm',
    'Quản lý',
  ];

  @override
  void initState() {
    super.initState();
    _loadCriteria();
  }

  @override
  void dispose() {
    _positionController.dispose();
    super.dispose();
  }

  Future<void> _loadCriteria() async {
    try {
      final snap = await Get.put(UpdateAccountController()).getUserData().first;
      if (!mounted) return;

      final data = snap.exists
          ? snap.data() as Map<String, dynamic>
          : <String, dynamic>{};
      JobCriteriaModel? criteria = JobCriteriaModel.fromUserData(data);
      if (criteria == null && data['jobCriteria'] is Map) {
        criteria = JobCriteriaModel.fromMap(
          Map<String, dynamic>.from(data['jobCriteria'] as Map),
        );
      }

      if (criteria != null && criteria.hasData) {
        _hasExperience = criteria.hasExperience;
        _positionController.text = criteria.position;
        _careers
          ..clear()
          ..addAll(criteria.careers);
        _locations
          ..clear()
          ..addAll(criteria.locations);
        _workTypes
          ..clear()
          ..addAll(criteria.workTypes);
        _salaryMin = criteria.salaryMin;
        _salaryMax = criteria.salaryMax;
        _salaryNegotiable = criteria.salaryNegotiable;
        _level = criteria.level;
      }
    } catch (_) {
      // Giữ form trống nếu không tải được
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_positionController.text.trim().isEmpty) {
      _showMessage('Vui lòng nhập vị trí công việc', isError: true);
      return;
    }
    if (_locations.isEmpty) {
      _showMessage('Vui lòng chọn ít nhất một địa điểm', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final criteria = JobCriteriaModel(
        hasExperience: _hasExperience,
        position: _positionController.text,
        careers: List<String>.from(_careers),
        locations: List<String>.from(_locations),
        salaryMin: _salaryMin,
        salaryMax: _salaryMax,
        salaryNegotiable: _salaryNegotiable,
        workTypes: List<String>.from(_workTypes),
        level: _level,
      );
      await Get.find<UpdateAccountController>().saveJobCriteria(criteria);
      if (!mounted) return;
      _showMessage('Đã lưu tiêu chí tìm việc');
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        _showMessage('Không thể lưu. Vui lòng thử lại.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.redAccent : _primary,
      ),
    );
  }

  void _clearFormState() {
    _positionController.clear();
    _hasExperience = false;
    _careers.clear();
    _locations.clear();
    _workTypes.clear();
    _salaryMin = null;
    _salaryMax = null;
    _salaryNegotiable = false;
    _level = null;
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đặt lại tiêu chí'),
        content: const Text(
          'Bạn có chắc muốn xóa toàn bộ tiêu chí tìm việc đã nhập?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Đặt lại',
              style: TextStyle(color: Color(0xFFE64A4A)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _resetting = true);
    try {
      await Get.find<UpdateAccountController>().clearJobCriteria();
      _clearFormState();
      if (!mounted) return;
      setState(() {});
      _showMessage('Đã đặt lại tất cả tiêu chí tìm việc');
    } catch (_) {
      if (mounted) {
        _showMessage('Không thể đặt lại. Vui lòng thử lại.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  String get _salarySummary {
    final model = JobCriteriaModel(
      salaryMin: _salaryMin,
      salaryMax: _salaryMax,
      salaryNegotiable: _salaryNegotiable,
    );
    return model.salaryDisplay ?? '';
  }

  Future<void> _openCareerPicker() async {
    final result = await showJobCriteriaCheckboxSheet(
      context: context,
      title: 'Chọn ngành nghề',
      searchHint: 'Tìm kiếm ngành nghề',
      primaryButtonLabel: 'Xong',
      options: JobCriteriaOptions.careers,
      initialSelected: _careers,
      maxItems: 3,
    );
    if (result != null) {
      setState(() {
        _careers
          ..clear()
          ..addAll(result);
      });
    }
  }

  Future<void> _openLocationPicker() async {
    final result = await showJobCriteriaCheckboxSheet(
      context: context,
      title: 'Bạn muốn làm việc ở đâu?',
      searchHint: 'Tìm kiếm địa điểm làm việc',
      primaryButtonLabel: 'Lưu thông tin',
      options: JobCriteriaOptions.locations,
      initialSelected: _locations,
      maxItems: 5,
    );
    if (result != null) {
      setState(() {
        _locations
          ..clear()
          ..addAll(result);
      });
    }
  }

  Future<void> _openSalaryPicker() async {
    final result = await showSalaryPickerSheet(
      context: context,
      initialMin: _salaryMin,
      initialMax: _salaryMax,
      initialNegotiable: _salaryNegotiable,
    );
    if (result != null) {
      setState(() {
        _salaryMin = result.min;
        _salaryMax = result.max;
        _salaryNegotiable = result.negotiable;
      });
    }
  }

  Future<void> _openWorkTypePicker() async {
    final result = await showJobCriteriaCheckboxSheet(
      context: context,
      title: 'Chọn hình thức làm việc',
      searchHint: 'Tìm kiếm hình thức',
      primaryButtonLabel: 'Xong',
      options: _workTypeOptions,
      initialSelected: _workTypes,
      maxItems: 3,
    );
    if (result != null) {
      setState(() {
        _workTypes
          ..clear()
          ..addAll(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
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
                                  onTap: () =>
                                      setState(() => _hasExperience = false),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildExperienceChip(
                                  title: 'Đã có kinh nghiệ...',
                                  selected: _hasExperience,
                                  onTap: () =>
                                      setState(() => _hasExperience = true),
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
                          _buildPickerField(
                            label: 'Ngành nghề (tối đa 3 ngành nghề)',
                            hint: 'Chọn ngành nghề',
                            selected: _careers,
                            onTap: _openCareerPicker,
                          ),
                          const SizedBox(height: 24),
                          _buildPickerField(
                            label: 'Địa điểm tìm việc (tối đa 5 địa điểm)',
                            hint: 'Chọn địa điểm làm việc',
                            selected: _locations,
                            onTap: _openLocationPicker,
                            required: true,
                          ),
                          const SizedBox(height: 24),
                          _buildPickerField(
                            label: 'Mức lương mong muốn (Triệu/Tháng)',
                            hint: 'Chọn mức lương',
                            displayText: _salarySummary,
                            onTap: _openSalaryPicker,
                          ),
                          const SizedBox(height: 24),
                          _buildPickerField(
                            label: 'Hình thức làm việc',
                            hint: 'Chọn hình thức làm việc',
                            selected: _workTypes,
                            onTap: _openWorkTypePicker,
                          ),
                          const SizedBox(height: 24),
                          _buildLabel('Cấp bậc hiện tại'),
                          const SizedBox(height: 10),
                          _buildDropdownField(
                            value: _level,
                            hintText: 'Chọn cấp bậc hiện tại',
                            items: _levelOptions,
                            onChanged: (value) => setState(() => _level = value),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 58,
                            child: OutlinedButton(
                              onPressed: _saving || _resetting
                                  ? null
                                  : _confirmReset,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF666666),
                                side: const BorderSide(color: _border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _resetting
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'Đặt lại',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 58,
                            child: ElevatedButton(
                              onPressed: _saving || _resetting ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: _saving
                                  ? const SizedBox(
                                      width: 26,
                                      height: 26,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Lưu thông tin',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPickerField({
    required String label,
    required String hint,
    required VoidCallback onTap,
    List<String> selected = const [],
    String displayText = '',
    bool required = false,
  }) {
    final hasChips = selected.isNotEmpty;
    final hasSalaryText = displayText.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        required ? _buildRequiredLabel(label) : _buildLabel(label),
        const SizedBox(height: 10),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasSalaryText
                        ? displayText
                        : hasChips
                        ? 'Đã chọn ${selected.length}'
                        : hint,
                    style: TextStyle(
                      fontSize: 18,
                      color: hasChips || hasSalaryText
                          ? const Color(0xFF333333)
                          : _hint,
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: Color(0xFFC8C8C8),
                ),
              ],
            ),
          ),
        ),
        if (hasChips) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: selected
                .map(
                  (item) => _buildPinnedChip(
                    item,
                    onRemove: () => setState(() => selected.remove(item)),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildPinnedChip(String label, {required VoidCallback onRemove}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _primary, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _primary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 17, color: _primary),
          ),
        ],
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
          border: Border.all(
            color: selected ? _primary : _border,
            width: selected ? 1.2 : 1,
          ),
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
      value: value,
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
