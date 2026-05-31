import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../data/constants/full_time_policy.dart';
import '../../data/constants/job_categories.dart';
import '../../controller/job_post_controller.dart';
import '../../data/models/full_time_job_details.dart';
import '../../data/models/job_post_model.dart';
import '../../routes/app_routes.dart';
import '../../utils/theme_colors.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key, this.initialJobType = 'part_time'});

  /// `part_time` — màn tạo Part-time; `full_time` — màn tạo Full-time.
  final String initialJobType;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const _gradientColors = [Color(0xFF7B1FA2), Color(0xFF1565C0)];
  static const _gradientBegin = Alignment.centerLeft;
  static const _gradientEnd = Alignment.centerRight;

  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  final _slotsCtrl = TextEditingController(text: '1');
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _requirementsCtrl = TextEditingController();
  final _workHoursCtrl = TextEditingController();
  final _startTimeCtrl = TextEditingController();
  final _benefitsCtrl = TextEditingController();
  final _probationCtrl = TextEditingController();

  // State
  String _jobType = 'part_time';
  String _category = 'phuc_vu';
  String _salaryType = 'per_day';
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime? _endDate;
  bool _isSubmitting = false;
  bool _requiresCv = true;
  bool _interviewRequired = true;
  int _payDayOfMonth = 5;
  String _workShift = 'flexible';
  String _minEducation = 'none';
  String _minExperience = 'none';
  final Set<String> _workingDays = {'mon', 'tue', 'wed', 'thu', 'fri'};
  final List<String> _imageBase64s = [];
  JobPostModel? _editing;

  bool get _isEdit => _editing != null;
  bool get _isFullTimeScreen => widget.initialJobType == 'full_time';

  List<Map<String, String>> get _categories => categoryOptionsFor(
        isFullTime: _isFullTimeScreen,
        selected: _category,
      );

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is JobPostModel) {
      _editing = args;
      if (args.jobType == 'full_time' && !_isFullTimeScreen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.offNamed(AppRoutes.createFulltimePost, arguments: args);
        });
        return;
      }
      if (args.jobType == 'part_time' && _isFullTimeScreen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.offNamed(AppRoutes.createPost, arguments: args);
        });
        return;
      }
      _loadFromPost(args);
      return;
    }
    _jobType = widget.initialJobType;
    if (_isFullTimeScreen) {
      _category = 'ban_hang';
      _salaryType = 'per_month';
      _workHoursCtrl.text = '8';
      _startTimeCtrl.text = '08:00';
    }
  }

  void _onJobTypeTap(String v) {
    if (v == _jobType) return;
    if (_isEdit) {
      Get.snackbar(
        'Không đổi loại',
        'Không thể đổi loại công việc khi đang sửa bài đăng',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (v == 'full_time') {
      Get.offNamed(AppRoutes.createFulltimePost);
    } else {
      Get.offNamed(AppRoutes.createPost);
    }
  }

  void _loadFromPost(JobPostModel p) {
    _titleCtrl.text = p.title;
    _descCtrl.text = p.description;
    _salaryCtrl.text = p.salary.toInt().toString();
    _slotsCtrl.text = p.slots.toString();
    _addressCtrl.text = p.location['address'] as String? ?? '';
    _cityCtrl.text = p.location['city'] as String? ?? '';
    _districtCtrl.text = p.location['district'] as String? ?? '';
    _requirementsCtrl.text = p.requirements ?? '';
    _workHoursCtrl.text =
        p.workHoursPerDay != null ? p.workHoursPerDay.toString() : '';
    _startTimeCtrl.text = p.startTime ?? '';
    _jobType = p.jobType;
    _category = p.category;
    _salaryType = p.salaryType;
    if (p.jobType == 'full_time' &&
        _salaryType != 'per_month' &&
        _salaryType != 'per_hour') {
      _salaryType = 'per_month';
    }
    _startDate = p.startDate;
    _endDate = p.endDate;
    _imageBase64s
      ..clear()
      ..addAll(p.imageUrls);
    final ft = p.fullTimeDetails;
    if (ft != null) {
      _requiresCv = ft.requiresCv;
      _interviewRequired = ft.interviewRequired;
      _payDayOfMonth = ft.payDayOfMonth;
      _workShift = ft.workShift;
      _minEducation = ft.minEducation ?? 'none';
      _minExperience = ft.minExperience ?? 'none';
      _benefitsCtrl.text = ft.benefits ?? '';
      _probationCtrl.text =
          ft.probationDays != null ? ft.probationDays.toString() : '';
      _workingDays
        ..clear()
        ..addAll(ft.workingDays);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _salaryCtrl.dispose();
    _slotsCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _districtCtrl.dispose();
    _requirementsCtrl.dispose();
    _workHoursCtrl.dispose();
    _startTimeCtrl.dispose();
    _benefitsCtrl.dispose();
    _probationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? _startDate),
      firstDate: isStart ? now : _startDate,
      lastDate: DateTime(now.year + 2),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: const Color(0xFF7B1FA2),
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  static final _timePattern = RegExp(r'^([01]?\d|2[0-3]):[0-5]\d$');

  Future<void> _pickPostImage() async {
    if (_imageBase64s.length >= 5) {
      Get.snackbar('Giới hạn', 'Tối đa 5 ảnh minh họa');
      return;
    }
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 55,
      maxWidth: 900,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.length > 900 * 1024) {
      Get.snackbar('Ảnh quá lớn', 'Chọn ảnh nhỏ hơn 900KB');
      return;
    }
    setState(() => _imageBase64s.add(base64Encode(bytes)));
  }

  String? _validateBeforeSubmit() {
    if (_jobType == 'part_time' && _endDate == null) {
      return 'Part-time cần chọn ngày kết thúc (số ngày làm việc)';
    }
    if (_endDate != null && _endDate!.isBefore(_startDate)) {
      return 'Ngày kết thúc phải sau ngày bắt đầu';
    }
    if (_cityCtrl.text.trim().isEmpty) {
      return 'Vui lòng nhập Tỉnh/Thành phố';
    }
    final st = _startTimeCtrl.text.trim();
    if (_isFullTimeScreen) {
      if (st.isEmpty) return 'Full-time cần nhập giờ bắt đầu làm việc';
      if (_workingDays.isEmpty) {
        return 'Chọn ít nhất một ngày làm trong tuần';
      }
      if (_payDayOfMonth < 1 || _payDayOfMonth > 28) {
        return 'Ngày trả lương phải từ 1 đến 28';
      }
      final wh = _workHoursCtrl.text.trim();
      if (wh.isEmpty) return 'Full-time cần nhập số giờ làm/ngày';
    }
    if (st.isNotEmpty && !_timePattern.hasMatch(st)) {
      return 'Giờ bắt đầu định dạng HH:mm (vd: 08:00)';
    }
    final wh = _workHoursCtrl.text.trim();
    if (wh.isNotEmpty) {
      final h = double.tryParse(wh.replaceAll(',', '.'));
      if (h == null || h <= 0 || h > 24) {
        return 'Giờ làm/ngày từ 1 đến 24';
      }
    }
    final slots = int.tryParse(_slotsCtrl.text.trim()) ?? 0;
    if (_editing != null && slots < _editing!.filledSlots) {
      return 'Số lượng tuyển không được nhỏ hơn số ứng viên đã nhận (${_editing!.filledSlots})';
    }
    if (_descCtrl.text.trim().length < 20) {
      return 'Mô tả công việc tối thiểu 20 ký tự';
    }
    return null;
  }

  Future<void> _submit({required bool isDraft}) async {
    if (!_formKey.currentState!.validate()) return;
    final extraErr = _validateBeforeSubmit();
    if (extraErr != null) {
      Get.snackbar('Thiếu thông tin', extraErr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    setState(() => _isSubmitting = true);

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final salary = double.tryParse(
            _salaryCtrl.text.replaceAll('.', '').replaceAll(',', '')) ??
        0;
    final slots = int.tryParse(_slotsCtrl.text) ?? 1;

    final newStatus = isDraft
        ? 'draft'
        : (_editing?.status == 'rejected' || _editing?.status == 'draft'
            ? 'pending'
            : (_editing?.status ?? 'pending'));

    final post = JobPostModel(
      jobId: _editing?.jobId ?? '',
      employerId: uid,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      category: _category,
      jobType: _jobType,
      location: {
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'district': _districtCtrl.text.trim(),
        'lat': _editing?.location['lat'] ?? 0.0,
        'lng': _editing?.location['lng'] ?? 0.0,
      },
      salary: salary,
      salaryType: _salaryType,
      slots: slots,
      filledSlots: _editing?.filledSlots ?? 0,
      startDate: _startDate,
      endDate: _isFullTimeScreen ? null : _endDate,
      workHoursPerDay:
          double.tryParse(_workHoursCtrl.text.trim().replaceAll(',', '.')),
      startTime: _startTimeCtrl.text.trim().isEmpty
          ? null
          : _startTimeCtrl.text.trim(),
      requirements: _requirementsCtrl.text.trim().isEmpty
          ? null
          : _requirementsCtrl.text.trim(),
      status: _isEdit ? newStatus : (isDraft ? 'draft' : 'pending'),
      totalBudget: salary * slots,
      imageUrls: List.from(_imageBase64s),
      fullTimeDetails: _isFullTimeScreen ? _buildFullTimeDetails() : null,
      groupChatId: _editing?.groupChatId,
      createdAt: _editing?.createdAt,
    );

    final controller = Get.isRegistered<JobPostController>()
        ? Get.find<JobPostController>()
        : Get.put(JobPostController());

    final success = _isEdit
        ? await controller.updatePost(post)
        : await controller.createPost(post);
    setState(() => _isSubmitting = false);

    if (success) {
      Get.back();
      Get.snackbar(
        _isEdit
            ? (isDraft ? 'Đã cập nhật nháp' : 'Đã cập nhật')
            : (isDraft ? 'Đã lưu nháp' : 'Đã gửi duyệt'),
        _isEdit
            ? 'Bài đăng đã được lưu'
            : (isDraft
                ? 'Bài đăng đã được lưu bản nháp'
                : 'Bài đăng đang chờ admin duyệt'),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Theme.of(context).colorScheme.primary,
        colorText: Theme.of(context).colorScheme.onPrimary,
      );
    }
  }

  FullTimeJobDetails _buildFullTimeDetails() {
    final probation = int.tryParse(_probationCtrl.text.trim());
    return FullTimeJobDetails(
      requiresCv: _requiresCv,
      interviewRequired: _interviewRequired,
      payDayOfMonth: _payDayOfMonth,
      workingDays: _workingDays.toList()..sort(),
      workShift: _workShift,
      probationDays: probation,
      minEducation: _minEducation == 'none' ? null : _minEducation,
      minExperience: _minExperience == 'none' ? null : _minExperience,
      benefits: _benefitsCtrl.text.trim().isEmpty
          ? null
          : _benefitsCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (_isFullTimeScreen) ...[
                    _buildFullTimeBanner(),
                    const SizedBox(height: 16),
                  ],
                  _buildSection('Thông tin cơ bản', [
                    _buildSegmentedControl(
                      label: 'Loại công việc',
                      options: const [
                        {'value': 'part_time', 'label': 'Part-time'},
                        {'value': 'full_time', 'label': 'Full-time'},
                      ],
                      selected: _jobType,
                      onTap: _onJobTypeTap,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _titleCtrl,
                      label: 'Tiêu đề bài đăng *',
                      hint: 'Ví dụ: Nhân viên phục vụ nhà hàng',
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Vui lòng nhập tiêu đề'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _buildDropdown(
                      label: 'Danh mục công việc *',
                      value: _category,
                      items: _categories
                          .map((c) => DropdownMenuItem(
                              value: c['value'], child: Text(c['label']!)))
                          .toList(),
                      onChanged: (v) => setState(() => _category = v!),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _descCtrl,
                      label: 'Mô tả công việc *',
                      hint: 'Mô tả chi tiết về công việc...',
                      maxLines: 4,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Vui lòng nhập mô tả'
                          : null,
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _buildSection('Địa điểm làm việc', [
                    _buildTextField(
                      controller: _addressCtrl,
                      label: 'Địa chỉ cụ thể *',
                      hint: 'Số nhà, tên đường...',
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Vui lòng nhập địa chỉ'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _districtCtrl,
                            label: 'Quận/Huyện',
                            hint: 'Quận 1',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _cityCtrl,
                            label: 'Tỉnh/Thành phố *',
                            hint: 'TP.HCM',
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Nhập tỉnh/thành'
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _buildSection('Mức lương & Số lượng', [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildTextField(
                            controller: _salaryCtrl,
                            label: 'Mức lương *',
                            hint: _isFullTimeScreen ? '8000000' : '250000',
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Nhập lương';
                              if ((double.tryParse(v) ?? 0) <= 0) return 'Lương > 0';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _buildDropdown(
                            label: 'Đơn vị',
                            value: _salaryType,
                            items: _isFullTimeScreen
                                ? const [
                                    DropdownMenuItem(
                                        value: 'per_month', child: Text('/tháng')),
                                    DropdownMenuItem(
                                        value: 'per_hour', child: Text('/giờ')),
                                  ]
                                : const [
                                    DropdownMenuItem(
                                        value: 'per_day', child: Text('/ngày')),
                                    DropdownMenuItem(
                                        value: 'per_hour', child: Text('/giờ')),
                                    DropdownMenuItem(
                                        value: 'per_month', child: Text('/tháng')),
                                    DropdownMenuItem(
                                        value: 'fixed', child: Text('Cố định')),
                                  ],
                            onChanged: (v) => setState(() => _salaryType = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _slotsCtrl,
                      label: 'Số lượng cần tuyển *',
                      hint: '1',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Nhập số lượng';
                        if ((int.tryParse(v) ?? 0) <= 0) return 'Số lượng > 0';
                        return null;
                      },
                    ),
                  ]),
                  const SizedBox(height: 16),
                  if (_isFullTimeScreen) ...[
                    _buildFullTimeScheduleSection(),
                    const SizedBox(height: 16),
                    _buildFullTimePayrollSection(),
                    const SizedBox(height: 16),
                    _buildFullTimeRequirementsSection(),
                    const SizedBox(height: 16),
                    _buildFullTimeBenefitsSection(),
                  ] else ...[
                    _buildSection('Thời gian làm việc', [
                      Row(
                        children: [
                          Expanded(
                            child: _buildDatePicker(
                              label: 'Ngày bắt đầu *',
                              date: _startDate,
                              onTap: () => _pickDate(isStart: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDatePicker(
                              label: 'Ngày kết thúc *',
                              date: _endDate,
                              onTap: () => _pickDate(isStart: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _startTimeCtrl,
                              label: 'Giờ bắt đầu',
                              hint: '08:00',
                              keyboardType: TextInputType.datetime,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _workHoursCtrl,
                              label: 'Giờ làm/ngày',
                              hint: '8',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d{0,2}([.,]\d{0,1})?$'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('Yêu cầu ứng viên (tùy chọn)', [
                      _buildTextField(
                        controller: _requirementsCtrl,
                        label: 'Yêu cầu',
                        hint: 'Ví dụ: Có kinh nghiệm, biết tiếng Anh...',
                        maxLines: 3,
                      ),
                    ]),
                  ],
                  const SizedBox(height: 16),
                  _buildSection('Hình ảnh minh họa', [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._imageBase64s.asMap().entries.map((e) => Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.memory(
                                    base64Decode(e.value),
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: GestureDetector(
                                    onTap: () => setState(
                                        () => _imageBase64s.removeAt(e.key)),
                                    child: const CircleAvatar(
                                      radius: 10,
                                      backgroundColor: Colors.black54,
                                      child: Icon(Icons.close,
                                          size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            )),
                        OutlinedButton.icon(
                          onPressed: _pickPostImage,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('Thêm ảnh'),
                        ),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── FULL-TIME SECTIONS ─────────────────────────────────────────────────────
  Widget _buildFullTimeBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.work_history_outlined,
              color: Color(0xFF1565C0), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              kFullTimeEmployerNotice,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: context.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullTimeScheduleSection() {
    return _buildSection('Lịch & ca làm việc', [
      Text('Ngày làm trong tuần *',
          style: TextStyle(color: context.textSecondary, fontSize: 13)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: FullTimeJobDetails.weekdayOptions.map((opt) {
          final value = opt['value']!;
          final selected = _workingDays.contains(value);
          return FilterChip(
            label: Text(opt['label']!),
            selected: selected,
            onSelected: (on) {
              setState(() {
                if (on) {
                  _workingDays.add(value);
                } else {
                  _workingDays.remove(value);
                }
              });
            },
            selectedColor: const Color(0xFF7B1FA2).withValues(alpha: 0.15),
            checkmarkColor: const Color(0xFF7B1FA2),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? const Color(0xFF7B1FA2) : context.textSecondary,
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 12),
      _buildDropdown(
        label: 'Ca làm việc *',
        value: _workShift,
        items: FullTimeJobDetails.shiftOptions
            .map((s) => DropdownMenuItem(
                  value: s['value'],
                  child: Text(s['label']!),
                ))
            .toList(),
        onChanged: (v) => setState(() => _workShift = v!),
      ),
      const SizedBox(height: 12),
      _buildDatePicker(
        label: 'Ngày bắt đầu làm việc *',
        date: _startDate,
        onTap: () => _pickDate(isStart: true),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _buildTextField(
              controller: _startTimeCtrl,
              label: 'Giờ bắt đầu *',
              hint: '08:00',
              keyboardType: TextInputType.datetime,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildTextField(
              controller: _workHoursCtrl,
              label: 'Giờ làm/ngày *',
              hint: '8',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d{0,2}([.,]\d{0,1})?$'),
                ),
              ],
            ),
          ),
        ],
      ),
    ]);
  }

  Widget _buildFullTimePayrollSection() {
    return _buildSection('Thông tin lương (tham khảo)', [
      _buildDropdown(
        label: 'Ngày trả lương dự kiến *',
        value: _payDayOfMonth,
        items: List.generate(
          28,
          (i) => DropdownMenuItem(
            value: i + 1,
            child: Text('Ngày ${i + 1}'),
          ),
        ),
        onChanged: (v) => setState(() => _payDayOfMonth = v!),
      ),
      const SizedBox(height: 8),
      Text(
        'Chỉ để ứng viên tham khảo. NTD tự thỏa thuận và chi trả lương — ViecNow không can thiệp.',
        style: TextStyle(fontSize: 12, color: context.textSecondary),
      ),
    ]);
  }

  Widget _buildFullTimeRequirementsSection() {
    return _buildSection('Yêu cầu ứng viên', [
      _buildDropdown(
        label: 'Học vấn tối thiểu',
        value: _minEducation,
        items: FullTimeJobDetails.educationOptions
            .map((e) => DropdownMenuItem(
                  value: e['value'],
                  child: Text(e['label']!),
                ))
            .toList(),
        onChanged: (v) => setState(() => _minEducation = v!),
      ),
      const SizedBox(height: 12),
      _buildDropdown(
        label: 'Kinh nghiệm',
        value: _minExperience,
        items: FullTimeJobDetails.experienceOptions
            .map((e) => DropdownMenuItem(
                  value: e['value'],
                  child: Text(e['label']!),
                ))
            .toList(),
        onChanged: (v) => setState(() => _minExperience = v!),
      ),
      const SizedBox(height: 12),
      _buildTextField(
        controller: _requirementsCtrl,
        label: 'Yêu cầu khác',
        hint: 'Kỹ năng, chứng chỉ, ngoại ngữ...',
        maxLines: 3,
      ),
      const SizedBox(height: 4),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Bắt buộc nộp CV',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text('Ứng viên phải đính kèm CV khi ứng tuyển',
            style: TextStyle(fontSize: 12, color: context.textSecondary)),
        value: _requiresCv,
        activeThumbColor: const Color(0xFF7B1FA2),
        onChanged: (v) => setState(() => _requiresCv = v),
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Phỏng vấn trực tiếp',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text('NTD sẽ liên hệ phỏng vấn trước khi nhận việc',
            style: TextStyle(fontSize: 12, color: context.textSecondary)),
        value: _interviewRequired,
        activeThumbColor: const Color(0xFF7B1FA2),
        onChanged: (v) => setState(() => _interviewRequired = v),
      ),
    ]);
  }

  Widget _buildFullTimeBenefitsSection() {
    return _buildSection('Phúc lợi & thử việc', [
      _buildTextField(
        controller: _probationCtrl,
        label: 'Thời gian thử việc (ngày)',
        hint: '60',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
      const SizedBox(height: 12),
      _buildTextField(
        controller: _benefitsCtrl,
        label: 'Quyền lợi',
        hint: 'Bảo hiểm, thưởng, ăn trưa, nghỉ phép...',
        maxLines: 3,
      ),
    ]);
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: _gradientBegin,
          end: _gradientEnd,
          colors: _gradientColors,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
              ),
              Expanded(
                child: Text(
                  _isEdit
                      ? 'Sửa bài đăng'
                      : (_isFullTimeScreen
                          ? 'Tạo bài đăng Full-time'
                          : 'Tạo bài đăng Part-time'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SECTION ────────────────────────────────────────────────────────────────
  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF7B1FA2)),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // ── TEXT FIELD ─────────────────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: context.textSecondary, fontSize: 13),
        labelStyle: TextStyle(color: context.textSecondary, fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor:
            Theme.of(context).inputDecorationTheme.fillColor ?? context.elevatedSurface,
      ),
    );
  }

  // ── DROPDOWN ───────────────────────────────────────────────────────────────
  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.textSecondary, fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor:
            Theme.of(context).inputDecorationTheme.fillColor ?? context.elevatedSurface,
      ),
      style: TextStyle(fontSize: 13.5, color: context.textPrimary),
      dropdownColor: Theme.of(context).cardColor,
    );
  }

  // ── SEGMENTED CONTROL ──────────────────────────────────────────────────────
  Widget _buildSegmentedControl({
    required String label,
    required List<Map<String, String>> options,
    required String selected,
    required void Function(String) onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(color: context.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          children: options.map((opt) {
            final isSelected = opt['value'] == selected;
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(opt['value']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(
                      right: opt == options.last ? 0 : 8),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            begin: _gradientBegin,
                            end: _gradientEnd,
                            colors: _gradientColors,
                          )
                        : null,
                    color: isSelected ? null : context.elevatedSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : context.borderColor,
                    ),
                  ),
                  child: Text(
                    opt['label']!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : context.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── DATE PICKER ────────────────────────────────────────────────────────────
  Widget _buildDatePicker({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    bool isOptional = false,
  }) {
    final dateStr = date != null
        ? DateFormat('dd/MM/yyyy').format(date)
        : (isOptional ? 'Không xác định' : 'Chọn ngày');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:
              Theme.of(context).inputDecorationTheme.fillColor ?? context.elevatedSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(color: context.textSecondary, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(dateStr,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: date != null
                              ? context.textPrimary
                              : context.textSecondary.withValues(alpha: 0.7))),
                ],
              ),
            ),
            const Icon(Icons.calendar_today_rounded,
                size: 18, color: Color(0xFF7B1FA2)),
          ],
        ),
      ),
    );
  }

  // ── BUTTONS ────────────────────────────────────────────────────────────────
  Widget _buildActionButtons() {
    return Row(
      children: [
        // Lưu nháp
        Expanded(
          child: OutlinedButton(
            onPressed: _isSubmitting ? null : () => _submit(isDraft: true),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              side: const BorderSide(color: Color(0xFF7B1FA2), width: 1.5),
            ),
            child: const Text(
              'Lưu nháp',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7B1FA2)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Đăng bài
        Expanded(
          flex: 2,
          child: _isSubmitting
              ? const Center(child: CircularProgressIndicator())
              : GestureDetector(
                  onTap: () => _submit(isDraft: false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: _gradientBegin,
                        end: _gradientEnd,
                        colors: _gradientColors,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7B1FA2).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Gửi duyệt',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
