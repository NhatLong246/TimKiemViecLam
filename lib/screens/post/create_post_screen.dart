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
import '../../data/services/job_pricing_service.dart';
import '../../routes/app_routes.dart';
import '../../utils/theme_colors.dart';
import '../../data/constants/language_proficiency_levels.dart';

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
  final _customCategoryCtrl = TextEditingController();
  final _requirementsCtrl = TextEditingController();
  final _requiredSkillsCtrl = TextEditingController();
  final _requiredCertificatesCtrl = TextEditingController();
  final _languageScoreCtrl = TextEditingController();
  final _workHoursCtrl = TextEditingController();
  final _startHourCtrl = TextEditingController();
  final _startMinCtrl = TextEditingController();
  final _benefitsCtrl = TextEditingController();
  final _probationCtrl = TextEditingController();
  final _deadlineHourCtrl = TextEditingController();
  final _deadlineMinCtrl = TextEditingController();

  // State
  String _jobType = 'part_time';
  String _category = 'phuc_vu';
  String _salaryType = 'per_day';
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _applicationDeadline = DateTime.now();
  DateTime? _endDate;
  bool _isSubmitting = false;
  bool _requiresCv = true;
  bool _interviewRequired = true;
  int _payDayOfMonth = 5;
  String _workShift = 'flexible';
  String _minEducation = 'none';
  final Set<String> _workingDays = {'mon', 'tue', 'wed', 'thu', 'fri'};
  final List<String> _imageBase64s = [];
  JobPostModel? _editing;

  String _requiredLanguage = 'Tất cả';
  String _requiredLanguageLevel = 'Tất cả';
  String _requiredExperience = 'Tất cả';
  String _requiredGender = 'any';
  String _englishLevelType = 'CEFR';
  final Set<String> _selectedRequirementTypes = {};

  static const _requirementOptions = [
    {
      'type': 'skills',
      'profileField': 'skills',
      'label': 'Kỹ năng',
      'description': 'Đối chiếu với mục Kỹ năng trong hồ sơ',
      'icon': Icons.psychology_outlined,
    },
    {
      'type': 'certificates',
      'profileField': 'certificates',
      'label': 'Chứng chỉ',
      'description': 'Đối chiếu với mục Chứng chỉ trong hồ sơ',
      'icon': Icons.workspace_premium_outlined,
    },
    {
      'type': 'languages',
      'profileField': 'languages',
      'label': 'Ngoại ngữ',
      'description': 'Chọn ngôn ngữ và trình độ tối thiểu',
      'icon': Icons.translate_rounded,
    },
    {
      'type': 'gender',
      'profileField': 'gender',
      'label': 'Giới tính',
      'description': 'Đối chiếu với thông tin cá nhân',
      'icon': Icons.wc_outlined,
    },
    {
      'type': 'education',
      'profileField': 'educations',
      'label': 'Học vấn',
      'description': 'Đối chiếu với mục Học vấn trong hồ sơ',
      'icon': Icons.school_outlined,
    },
    {
      'type': 'experience',
      'profileField': 'workExperiences',
      'label': 'Kinh nghiệm',
      'description': 'Đối chiếu với mục Kinh nghiệm làm việc',
      'icon': Icons.work_history_outlined,
    },
  ];

  static const List<String> _vietnamProvinces = [
    'An Giang', 'Bà Rịa - Vũng Tàu', 'Bắc Giang', 'Bắc Kạn', 'Bạc Liêu', 'Bắc Ninh', 
    'Bến Tre', 'Bình Định', 'Bình Dương', 'Bình Phước', 'Bình Thuận', 'Cà Mau', 
    'Cần Thơ', 'Cao Bằng', 'Đà Nẵng', 'Đắk Lắk', 'Đắk Nông', 'Điện Biên', 'Đồng Nai', 
    'Đồng Tháp', 'Gia Lai', 'Hà Giang', 'Hà Nam', 'Hà Nội', 'Hà Tĩnh', 'Hải Dương', 
    'Hải Phòng', 'Hậu Giang', 'Hòa Bình', 'Hưng Yên', 'Khánh Hòa', 'Kiên Giang', 
    'Kon Tum', 'Lai Châu', 'Lâm Đồng', 'Lạng Sơn', 'Lào Cai', 'Long An', 'Nam Định', 
    'Nghệ An', 'Ninh Bình', 'Ninh Thuận', 'Phú Thọ', 'Phú Yên', 'Quảng Bình', 
    'Quảng Nam', 'Quảng Ngãi', 'Quảng Ninh', 'Quảng Trị', 'Sóc Trăng', 'Sơn La', 
    'Tây Ninh', 'Thái Bình', 'Thái Nguyên', 'Thanh Hóa', 'Thừa Thiên Huế', 'Tiền Giang', 
    'TP.HCM', 'Trà Vinh', 'Tuyên Quang', 'Vĩnh Long', 'Vĩnh Phúc', 'Yên Bái'
  ];

  bool get _isEdit => _editing != null;
  bool get _isFullTimeScreen => widget.initialJobType == 'full_time';

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  List<Map<String, String>> get _categories =>
      categoryOptionsFor(isFullTime: _isFullTimeScreen, selected: _category);

  @override
  void initState() {
    super.initState();
    _startDate = _dateOnly(_startDate);
    _applicationDeadline = _dateOnly(_applicationDeadline);
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
      _startHourCtrl.text = '08';
      _startMinCtrl.text = '00';
    }
    if (!_isEdit) {
      _startHourCtrl.text = '08';
      _startMinCtrl.text = '00';
      _deadlineHourCtrl.text = '23';
      _deadlineMinCtrl.text = '59';
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
    _customCategoryCtrl.text = p.customCategory ?? '';
    _workHoursCtrl.text = p.workHoursPerDay != null
        ? p.workHoursPerDay.toString()
        : '';
    if (p.startTime != null && p.startTime!.isNotEmpty) {
      final parts = p.startTime!.split(':');
      if (parts.length == 2) {
        _startHourCtrl.text = parts[0];
        _startMinCtrl.text = parts[1];
      }
    }
    _jobType = p.jobType;
    _category = p.category;
    _salaryType = p.salaryType;
    if (p.jobType == 'full_time' &&
        _salaryType != 'per_month' &&
        _salaryType != 'per_hour') {
      _salaryType = 'per_month';
    }
    _startDate = _dateOnly(p.startDate);
    _endDate = p.endDate == null ? null : _dateOnly(p.endDate!);
    if (p.applicationDeadline != null) {
      _applicationDeadline = _dateOnly(p.applicationDeadline!);
      _deadlineHourCtrl.text = DateFormat('HH').format(p.applicationDeadline!);
      _deadlineMinCtrl.text = DateFormat('mm').format(p.applicationDeadline!);
    } else {
      _applicationDeadline = _dateOnly(p.startDate);
      _deadlineHourCtrl.text = '23';
      _deadlineMinCtrl.text = '59';
    }
    _endDate = p.endDate == null ? null : _dateOnly(p.endDate!);
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
      _benefitsCtrl.text = ft.benefits ?? '';
      _probationCtrl.text = ft.probationDays != null
          ? ft.probationDays.toString()
          : '';
      _workingDays
        ..clear()
        ..addAll(ft.workingDays);
    }
    _requiredLanguage = p.requiredLanguage ?? 'Tất cả';
    _requiredLanguageLevel = p.requiredLanguageLevel ?? 'Tất cả';
    _requiredExperience =
        p.requiredExperience ??
        switch (ft?.minExperience) {
          'under_1' => 'under_1',
          '1_2' => '1_to_3',
          '2_5' => '3_to_5',
          'over_5' => 'over_5',
          _ => 'Tất cả',
        };
    _loadCandidateRequirements(p);
  }

  void _loadCandidateRequirements(JobPostModel post) {
    final saved = post.candidateRequirements;
    if (saved.isEmpty) {
      _requirementsCtrl.text = _legacyCustomRequirements(post.requirements);
      if (_requiredLanguage != 'Tất cả') {
        _selectedRequirementTypes.add('languages');
        if (_requiredLanguage == 'Tiếng Anh') {
          final level = _requiredLanguageLevel.trim();
          if (level.toUpperCase().startsWith('TOEIC')) {
            _englishLevelType = 'TOEIC';
            _languageScoreCtrl.text = level
                .replaceFirst(RegExp('TOEIC', caseSensitive: false), '')
                .trim();
          } else if (level.toUpperCase().startsWith('IELTS')) {
            _englishLevelType = 'IELTS';
            _languageScoreCtrl.text = level
                .replaceFirst(RegExp('IELTS', caseSensitive: false), '')
                .trim();
          }
        }
      }
      if (_requiredExperience != 'Tất cả') {
        _selectedRequirementTypes.add('experience');
      }
      if (_minEducation != 'none') {
        _selectedRequirementTypes.add('education');
      }
      return;
    }

    for (final requirement in saved) {
      final type = requirement['type']?.toString() ?? '';
      if (type == 'other') {
        _requirementsCtrl.text = requirement['text']?.toString() ?? '';
        continue;
      }
      if (type.isEmpty) continue;
      _selectedRequirementTypes.add(type);
      switch (type) {
        case 'skills':
          _requiredSkillsCtrl.text = _stringList(
            requirement['values'],
          ).join(', ');
          break;
        case 'certificates':
          _requiredCertificatesCtrl.text = _stringList(
            requirement['values'],
          ).join(', ');
          break;
        case 'languages':
          _requiredLanguage = requirement['language']?.toString() ?? 'Tất cả';
          _englishLevelType = requirement['levelType']?.toString() ?? 'CEFR';
          final minimum = requirement['minimum']?.toString() ?? 'Tất cả';
          if (_englishLevelType == 'TOEIC' || _englishLevelType == 'IELTS') {
            _languageScoreCtrl.text = minimum;
            _requiredLanguageLevel = _englishLevelType;
          } else {
            _requiredLanguageLevel = minimum;
          }
          break;
        case 'gender':
          _requiredGender = requirement['value']?.toString() ?? 'any';
          break;
        case 'education':
          _minEducation = requirement['minimum']?.toString() ?? 'none';
          break;
        case 'experience':
          _requiredExperience = requirement['minimum']?.toString() ?? 'Tất cả';
          break;
      }
    }
  }

  String _legacyCustomRequirements(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    return raw
        .split('\n')
        .where((line) {
          final normalized = line.trim().toLowerCase();
          return !normalized.startsWith('kinh nghiệm:') &&
              !normalized.startsWith('yêu cầu ngoại ngữ:') &&
              !normalized.startsWith('ngoại ngữ:');
        })
        .join('\n')
        .trim();
  }

  List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
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
    _customCategoryCtrl.dispose();
    _requirementsCtrl.dispose();
    _requiredSkillsCtrl.dispose();
    _requiredCertificatesCtrl.dispose();
    _languageScoreCtrl.dispose();
    _workHoursCtrl.dispose();
    _startHourCtrl.dispose();
    _startMinCtrl.dispose();
    _benefitsCtrl.dispose();
    _probationCtrl.dispose();
    _deadlineHourCtrl.dispose();
    _deadlineMinCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = _dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _dateOnly(_startDate) : (_endDate ?? _startDate),
      firstDate: isStart ? now : _dateOnly(_startDate),
      lastDate: DateTime(now.year + 2),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(
            ctx,
          ).colorScheme.copyWith(primary: const Color(0xFF7B1FA2)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final pickedDay = _dateOnly(picked);
      setState(() {
        if (isStart) {
          _startDate = pickedDay;
          if (_endDate != null &&
              _dateOnly(_endDate!).isBefore(_dateOnly(_startDate))) {
            _endDate = null;
          }
        } else {
          _endDate = pickedDay;
        }
      });
    }
  }

  Future<void> _pickDeadlineDate() async {
    final now = _dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOnly(_applicationDeadline),
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(
            ctx,
          ).colorScheme.copyWith(primary: const Color(0xFF7B1FA2)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _applicationDeadline = _dateOnly(picked);
      });
    }
  }

  Future<void> _pickPostImage() async {
    if (_imageBase64s.length >= 5) {
      _showFormNotice('Giới hạn', 'Tối đa 5 ảnh minh họa');
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
      _showFormNotice('Ảnh quá lớn', 'Chọn ảnh nhỏ hơn 900KB');
      return;
    }
    setState(() => _imageBase64s.add(base64Encode(bytes)));
  }

  String? _validateBeforeSubmit() {
    _normalizeAllTimeFields();

    final dhStr = _deadlineHourCtrl.text.trim();
    final dmStr = _deadlineMinCtrl.text.trim();
    if (dhStr.isEmpty || dmStr.isEmpty) {
      return 'Vui lòng nhập đủ giờ và phút hạn ứng tuyển';
    }
    final dh = int.tryParse(dhStr);
    final dm = int.tryParse(dmStr);
    if (dh == null || dh < 0 || dh > 23 || dm == null || dm < 0 || dm > 59) {
      return 'Giờ ứng tuyển không hợp lệ (00:00 - 23:59)';
    }
    final fullDeadline = DateTime(
      _applicationDeadline.year,
      _applicationDeadline.month,
      _applicationDeadline.day,
      dh,
      dm,
    );

    final shStr = _startHourCtrl.text.trim();
    final smStr = _startMinCtrl.text.trim();
    final startActionText = _isFullTimeScreen ? 'hẹn phỏng vấn' : 'bắt đầu';
    final startTargetText = _isFullTimeScreen
        ? 'hẹn phỏng vấn'
        : 'bắt đầu làm việc';
    if (shStr.isEmpty || smStr.isEmpty) {
      return 'Vui lòng nhập đủ giờ và phút $startActionText';
    }

    int? sh, sm;
    sh = int.tryParse(shStr);
    sm = int.tryParse(smStr);
    if (sh == null || sh < 0 || sh > 23 || sm == null || sm < 0 || sm > 59) {
      return 'Giờ $startActionText không hợp lệ (00:00 - 23:59)';
    }

    final fullStart = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      sh,
      sm,
    );

    final sameDate =
        _applicationDeadline.year == _startDate.year &&
        _applicationDeadline.month == _startDate.month &&
        _applicationDeadline.day == _startDate.day;

    final now = DateTime.now();
    final isStartToday =
        _startDate.year == now.year &&
        _startDate.month == now.month &&
        _startDate.day == now.day;
    if (!_isEdit && isStartToday) {
      final startDateTime = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        sh,
        sm,
      );
      if (startDateTime.difference(now).inMinutes < 60) {
        return _isFullTimeScreen
            ? 'Nếu hẹn phỏng vấn hôm nay, giờ hẹn phải cách hiện tại ít nhất 1 giờ'
            : 'Nếu làm việc hôm nay, giờ bắt đầu phải cách hiện tại ít nhất 1 giờ';
      }
    }

    if (sameDate && !fullDeadline.isBefore(fullStart)) {
      return 'Khi trùng ngày, giờ hạn ứng tuyển phải nhỏ hơn giờ $startActionText';
    }
    if (!fullDeadline.isBefore(fullStart)) {
      return 'Hạn ứng tuyển phải trước ngày/giờ $startTargetText';
    }
    if (!_isEdit && fullDeadline.isBefore(now)) {
      return 'Hạn ứng tuyển không được nằm trong quá khứ';
    }

    if (_jobType == 'part_time' && _endDate == null) {
      return 'Part-time cần chọn ngày kết thúc (số ngày làm việc)';
    }
    if (_endDate != null &&
        _dateOnly(_endDate!).isBefore(_dateOnly(_startDate))) {
      return 'Ngày kết thúc không được trước ngày bắt đầu';
    }
    if (_cityCtrl.text.trim().isEmpty) {
      return 'Vui lòng nhập Tỉnh/Thành phố';
    }
    if (_isFullTimeScreen) {
      if (_workingDays.isEmpty) {
        return 'Chọn ít nhất một ngày làm trong tuần';
      }
      if (_payDayOfMonth < 1 || _payDayOfMonth > 28) {
        return 'Ngày trả lương phải từ 1 đến 28';
      }
    }
    final wh = _workHoursCtrl.text.trim();
    if (_jobType == 'part_time' && _salaryType == 'per_hour' && wh.isEmpty) {
      return 'Việc trả theo giờ cần nhập số giờ làm mỗi ngày';
    }
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
    if (_category == 'other' && _customCategoryCtrl.text.trim().isEmpty) {
      return 'Vui lòng nhập tên danh mục công việc khác';
    }
    if (_selectedRequirementTypes.contains('skills') &&
        _splitRequirementValues(_requiredSkillsCtrl.text).isEmpty) {
      return 'Vui lòng nhập ít nhất một kỹ năng yêu cầu';
    }
    if (_selectedRequirementTypes.contains('certificates') &&
        _splitRequirementValues(_requiredCertificatesCtrl.text).isEmpty) {
      return 'Vui lòng nhập ít nhất một chứng chỉ yêu cầu';
    }
    if (_selectedRequirementTypes.contains('languages')) {
      if (_requiredLanguage == 'Tất cả') {
        return 'Vui lòng chọn ngoại ngữ yêu cầu';
      }
      if (_requiredLanguage == 'Tiếng Anh' &&
          (_englishLevelType == 'TOEIC' || _englishLevelType == 'IELTS')) {
        final score = double.tryParse(
          _languageScoreCtrl.text.trim().replaceAll(',', '.'),
        );
        if (score == null) return 'Vui lòng nhập điểm $_englishLevelType';
        if (_englishLevelType == 'TOEIC' &&
            (score < 10 || score > 990 || score % 5 != 0)) {
          return 'Điểm TOEIC phải từ 10 đến 990 và là bội số của 5';
        }
        if (_englishLevelType == 'IELTS' &&
            (score < 0 || score > 9 || (score * 2) % 1 != 0)) {
          return 'Điểm IELTS phải từ 0 đến 9, theo bước 0.5';
        }
      } else if (_requiredLanguageLevel == 'Tất cả') {
        return 'Vui lòng chọn trình độ ngoại ngữ tối thiểu';
      }
    }
    if (_selectedRequirementTypes.contains('gender') &&
        _requiredGender == 'any') {
      return 'Vui lòng chọn giới tính yêu cầu';
    }
    if (_selectedRequirementTypes.contains('education') &&
        _minEducation == 'none') {
      return 'Vui lòng chọn học vấn tối thiểu';
    }
    if (_selectedRequirementTypes.contains('experience') &&
        _requiredExperience == 'Tất cả') {
      return 'Vui lòng chọn mức kinh nghiệm yêu cầu';
    }
    return null;
  }

  List<String> _splitRequirementValues(String value) {
    return value
        .split(RegExp(r'[,;\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  String _money(double value) {
    return '${NumberFormat('#,###', 'vi_VN').format(value.ceil())}đ';
  }

  String _number(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  String _depositFormula(JobPostModel post, JobDepositQuote quote) {
    if (quote.calculationUnit == 'full_time_referral_fee') {
      return '${_money(JobPricingService.fullTimeReferralFeePerSlot)}/slot x ${post.slots} slot = ${_money(quote.depositAmount)}';
    }

    final salary = _money(post.salary);
    final slots = post.slots;
    final days = quote.workDays;
    return switch (post.salaryType) {
      'per_hour' =>
        '$salary/giờ x ${_number(post.workHoursPerDay ?? 0)} giờ/ngày x $days ngày x $slots người = ${_money(quote.depositAmount)}',
      'per_day' =>
        '$salary/ngày x $days ngày x $slots người = ${_money(quote.depositAmount)}',
      'per_month' =>
        '$salary/tháng / 30 ngày x $days ngày x $slots người = ${_money(quote.depositAmount)}',
      'fixed' =>
        '$salary/người x $slots người = ${_money(quote.depositAmount)}',
      _ => _money(quote.depositAmount),
    };
  }

  Future<bool> _confirmDepositBeforeSubmit(JobPostModel post) async {
    late final JobDepositQuote quote;
    try {
      quote = JobPricingService.quote(post);
    } catch (e) {
      _showFormNotice(
        'Thiếu thông tin',
        e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
    if (!quote.requiresDeposit) return true;
    final isFullTimeReferralQuote =
        quote.calculationUnit == 'full_time_referral_fee';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            isFullTimeReferralQuote
                ? 'Xác nhận phí giới thiệu'
                : 'Xác nhận tiền ứng',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFullTimeReferralQuote
                      ? 'Số tiền cần tạm giữ cho phí giới thiệu Full-time:'
                      : 'Số tiền cần ứng trước cho bài đăng này:',
                ),
                const SizedBox(height: 10),
                Text(
                  _money(quote.depositAmount),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF7B1FA2),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Công thức tính:',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(_depositFormula(post, quote)),
                const SizedBox(height: 12),
                Text(
                  isFullTimeReferralQuote
                      ? 'Tiền sẽ được tạm giữ trong ví. Khi hết hạn ứng tuyển, ViecNow thu 100.000đ cho mỗi ứng viên đã được duyệt và hoàn phần còn lại.'
                      : 'Tiền sẽ được trừ từ tiền app và tạm giữ khi bạn gửi duyệt.',
                  style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Gửi duyệt'),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _submit({required bool isDraft}) async {
    if (!_formKey.currentState!.validate()) return;
    final extraErr = _validateBeforeSubmit();
    if (extraErr != null) {
      _showFormNotice('Thiếu thông tin', extraErr);
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final salary =
        double.tryParse(
          _salaryCtrl.text.replaceAll('.', '').replaceAll(',', ''),
        ) ??
        0;
    final slots = int.tryParse(_slotsCtrl.text) ?? 1;

    final newStatus = isDraft
        ? 'draft'
        : (_editing?.status == 'rejected' || _editing?.status == 'draft'
              ? 'pending'
              : (_editing?.status ?? 'pending'));
    final candidateRequirements = _buildCandidateRequirementData();
    final requirementsText = _buildRequirementsText(candidateRequirements);

    final post = JobPostModel(
      jobId: _editing?.jobId ?? '',
      employerId: uid,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      category: _category,
      customCategory: _category == 'other'
          ? _customCategoryCtrl.text.trim()
          : null,
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
      applicationDeadline: () {
        final dh = int.tryParse(_deadlineHourCtrl.text.trim()) ?? 23;
        final dm = int.tryParse(_deadlineMinCtrl.text.trim()) ?? 59;
        return DateTime(
          _applicationDeadline.year,
          _applicationDeadline.month,
          _applicationDeadline.day,
          dh,
          dm,
        );
      }(),
      startDate: _dateOnly(_startDate),
      endDate: _isFullTimeScreen || _endDate == null
          ? null
          : _dateOnly(_endDate!),
      workHoursPerDay: double.tryParse(
        _workHoursCtrl.text.trim().replaceAll(',', '.'),
      ),
      startTime:
          _startHourCtrl.text.trim().isEmpty ||
              _startMinCtrl.text.trim().isEmpty
          ? null
          : '${_startHourCtrl.text.trim().padLeft(2, '0')}:${_startMinCtrl.text.trim().padLeft(2, '0')}',
      requirements: requirementsText,
      candidateRequirements: candidateRequirements,
      status: _isEdit ? newStatus : (isDraft ? 'draft' : 'pending'),
      totalBudget: salary * slots,
      imageUrls: List.from(_imageBase64s),
      fullTimeDetails: _isFullTimeScreen ? _buildFullTimeDetails() : null,
      requiredLanguage: _selectedRequirementTypes.contains('languages')
          ? _requiredLanguage
          : 'Tất cả',
      requiredLanguageLevel: _selectedRequirementTypes.contains('languages')
          ? _languageMinimumValue
          : 'Tất cả',
      requiredExperience: _selectedRequirementTypes.contains('experience')
          ? _requiredExperience
          : 'Tất cả',
      groupChatId: _editing?.groupChatId,
      createdAt: _editing?.createdAt,
    );

    if (!isDraft) {
      final confirmed = await _confirmDepositBeforeSubmit(post);
      if (!confirmed || !mounted) return;
    }

    setState(() => _isSubmitting = true);

    final controller = Get.isRegistered<JobPostController>()
        ? Get.find<JobPostController>()
        : Get.put(JobPostController());
    final successBg = Theme.of(context).colorScheme.primary;
    final successFg = Theme.of(context).colorScheme.onPrimary;

    final success = _isEdit
        ? await controller.updatePost(post)
        : await controller.createPost(post);
    if (!mounted) return;
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
        backgroundColor: successBg,
        colorText: successFg,
      );
    }
  }

  String get _languageMinimumValue {
    if (_requiredLanguage == 'Tiếng Anh' &&
        (_englishLevelType == 'TOEIC' || _englishLevelType == 'IELTS')) {
      return _languageScoreCtrl.text.trim().replaceAll(',', '.');
    }
    return _requiredLanguageLevel;
  }

  List<Map<String, dynamic>> _buildCandidateRequirementData() {
    final result = <Map<String, dynamic>>[];
    for (final option in _requirementOptions) {
      final type = option['type']! as String;
      if (!_selectedRequirementTypes.contains(type)) continue;
      final base = <String, dynamic>{
        'type': type,
        'profileField': option['profileField'],
        'label': option['label'],
      };
      switch (type) {
        case 'skills':
          base['values'] = _splitRequirementValues(_requiredSkillsCtrl.text);
          base['matchMode'] = 'all';
          break;
        case 'certificates':
          base['values'] = _splitRequirementValues(
            _requiredCertificatesCtrl.text,
          );
          base['matchMode'] = 'all';
          break;
        case 'languages':
          base.addAll({
            'language': _requiredLanguage,
            'levelType': _requiredLanguage == 'Tiếng Anh'
                ? _englishLevelType
                : 'certificate',
            'minimum': _languageMinimumValue,
            'operator': 'gte',
          });
          break;
        case 'gender':
          base['value'] = _requiredGender;
          base['operator'] = 'equals';
          break;
        case 'education':
          base['minimum'] = _minEducation;
          base['operator'] = 'gte';
          break;
        case 'experience':
          base['minimum'] = _requiredExperience;
          base['operator'] = 'gte';
          break;
      }
      result.add(base);
    }
    final other = _requirementsCtrl.text.trim();
    if (other.isNotEmpty) {
      result.add({'type': 'other', 'label': 'Yêu cầu khác', 'text': other});
    }
    return result;
  }

  String? _buildRequirementsText(List<Map<String, dynamic>> requirements) {
    final lines = <String>[];
    for (final requirement in requirements) {
      final type = requirement['type']?.toString();
      switch (type) {
        case 'skills':
          lines.add(
            'Kỹ năng: ${_stringList(requirement['values']).join(', ')}',
          );
          break;
        case 'certificates':
          lines.add(
            'Chứng chỉ: ${_stringList(requirement['values']).join(', ')}',
          );
          break;
        case 'languages':
          final language = requirement['language'];
          final levelType = requirement['levelType'];
          final minimum = requirement['minimum'];
          final level = levelType == 'TOEIC' || levelType == 'IELTS'
              ? '$levelType từ $minimum'
              : '$minimum trở lên';
          lines.add('Ngoại ngữ: $language - $level');
          break;
        case 'gender':
          lines.add('Giới tính: ${_genderLabel(requirement['value'])}');
          break;
        case 'education':
          lines.add(
            'Học vấn: ${FullTimeJobDetails.educationLabel(requirement['minimum']?.toString())}',
          );
          break;
        case 'experience':
          lines.add(
            'Kinh nghiệm: ${_experienceLabel(requirement['minimum']?.toString())}',
          );
          break;
        case 'other':
          final text = requirement['text']?.toString().trim() ?? '';
          if (text.isNotEmpty) lines.add(text);
          break;
      }
    }
    return lines.isEmpty ? null : lines.join('\n');
  }

  String _genderLabel(dynamic value) => switch (value?.toString()) {
    'male' => 'Nam',
    'female' => 'Nữ',
    'other' => 'Khác',
    _ => 'Không yêu cầu',
  };

  String _experienceLabel(String? value) => switch (value) {
    'no_exp' => 'Không yêu cầu, chấp nhận người mới',
    'under_1' => 'Dưới 1 năm',
    '1_to_3' => '1 - 3 năm',
    '3_to_5' => '3 - 5 năm',
    'over_5' => 'Trên 5 năm',
    _ => 'Không yêu cầu',
  };

  FullTimeJobDetails _buildFullTimeDetails() {
    final probation = int.tryParse(_probationCtrl.text.trim());
    final fullTimeExperience = switch (_requiredExperience) {
      'under_1' => 'under_1',
      '1_to_3' => '1_2',
      '3_to_5' => '2_5',
      'over_5' => 'over_5',
      _ => 'none',
    };
    return FullTimeJobDetails(
      requiresCv: _requiresCv,
      interviewRequired: _interviewRequired,
      payDayOfMonth: _payDayOfMonth,
      workingDays: _workingDays.toList()..sort(),
      workShift: _workShift,
      probationDays: probation,
      minEducation: _selectedRequirementTypes.contains('education')
          ? _minEducation
          : null,
      minExperience: _selectedRequirementTypes.contains('experience')
          ? fullTimeExperience
          : null,
      benefits: _benefitsCtrl.text.trim().isEmpty
          ? null
          : _benefitsCtrl.text.trim(),
    );
  }

  void _showFormNotice(String title, String message) {
    Get.closeCurrentSnackbar();
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      borderRadius: 12,
      borderWidth: 1,
      borderColor: const Color(0xFFFFB300),
      backgroundColor: const Color(0xFFFFF8E1),
      colorText: const Color(0xFF2A1B00),
      barBlur: 0,
      overlayBlur: 0,
      icon: const Icon(Icons.info_outline_rounded, color: Color(0xFFE65100)),
      duration: const Duration(seconds: 3),
    );
  }

  void _normalizeAllTimeFields() {
    _normalizeTimePart(_startHourCtrl, 23);
    _normalizeTimePart(_startMinCtrl, 59);
    _normalizeTimePart(_deadlineHourCtrl, 23);
    _normalizeTimePart(_deadlineMinCtrl, 59);
  }

  void _normalizeTimePart(TextEditingController controller, int maxValue) {
    final raw = controller.text.trim();
    if (raw.isEmpty) return;
    final parsed = int.tryParse(raw);
    if (parsed == null) {
      controller.clear();
      return;
    }
    final normalized = parsed.clamp(0, maxValue).toString().padLeft(2, '0');
    if (controller.text == normalized) return;
    controller.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF7F7FB),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Form(
              key: _formKey,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                    children: [
                      _buildFormIntroduction(),
                      const SizedBox(height: 16),
                      if (_isFullTimeScreen) ...[
                        _buildFullTimeBanner(),
                        const SizedBox(height: 16),
                      ],
                      _buildSection(
                        'Thông tin cơ bản',
                        [
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
                            prefixIcon: Icons.edit_note_rounded,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Vui lòng nhập tiêu đề'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          _buildDropdown(
                            label: 'Danh mục công việc *',
                            value: _category,
                            prefixIcon: Icons.category_outlined,
                            items: _categories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c['value'],
                                    child: Text(c['label']!),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _category = v!),
                          ),
                          if (_category == 'other') ...[
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _customCategoryCtrl,
                              label: 'Tên danh mục công việc *',
                              hint:
                                  'Ví dụ: Chăm sóc thú cưng, tổ chức sự kiện...',
                              prefixIcon: Icons.add_business_outlined,
                              validator: (value) {
                                if (_category == 'other' &&
                                    (value == null || value.trim().isEmpty)) {
                                  return 'Vui lòng nhập tên danh mục';
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _descCtrl,
                            label: 'Mô tả công việc *',
                            hint: 'Mô tả chi tiết về công việc...',
                            prefixIcon: Icons.subject_rounded,
                            maxLines: 4,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Vui lòng nhập mô tả'
                                : null,
                          ),
                        ],
                        icon: Icons.work_outline_rounded,
                        subtitle:
                            'Giúp ứng viên hiểu nhanh vị trí bạn đang tuyển',
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        'Địa điểm làm việc',
                        [
                          _buildTextField(
                            controller: _addressCtrl,
                            label: 'Địa chỉ cụ thể *',
                            hint: 'Số nhà, tên đường...',
                            prefixIcon: Icons.place_outlined,
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
                                  prefixIcon: Icons.map_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildDropdown<String>(
                                  label: 'Tỉnh/Thành phố *',
                                  value: _vietnamProvinces.contains(_cityCtrl.text.trim())
                                      ? _cityCtrl.text.trim()
                                      : null,
                                  prefixIcon: Icons.location_city_outlined,
                                  items: _vietnamProvinces.map((p) {
                                    return DropdownMenuItem<String>(
                                      value: p,
                                      child: Text(
                                        p,
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      _cityCtrl.text = v;
                                    }
                                  },
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? 'Chọn tỉnh/thành'
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                        icon: Icons.location_on_outlined,
                        subtitle:
                            'Thông tin chính xác giúp ứng viên chủ động di chuyển',
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        'Mức lương & Số lượng',
                        [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final salaryField = _buildTextField(
                                controller: _salaryCtrl,
                                label: 'Mức lương *',
                                hint: _isFullTimeScreen ? '8000000' : '250000',
                                prefixIcon: Icons.payments_outlined,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Nhập lương';
                                  }
                                  if ((double.tryParse(v) ?? 0) <= 0) {
                                    return 'Lương > 0';
                                  }
                                  return null;
                                },
                              );
                              final salaryUnitField = _buildDropdown(
                                label: 'Đơn vị',
                                value: _salaryType,
                                prefixIcon: Icons.sell_outlined,
                                items: _isFullTimeScreen
                                    ? const [
                                        DropdownMenuItem(
                                          value: 'per_month',
                                          child: Text('/tháng'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'per_hour',
                                          child: Text('/giờ'),
                                        ),
                                      ]
                                    : const [
                                        DropdownMenuItem(
                                          value: 'per_day',
                                          child: Text('/ngày'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'per_hour',
                                          child: Text('/giờ'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'per_month',
                                          child: Text('/tháng'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'fixed',
                                          child: Text('Cố định'),
                                        ),
                                      ],
                                onChanged: (v) =>
                                    setState(() => _salaryType = v!),
                              );

                              if (constraints.maxWidth < 420) {
                                return Column(
                                  children: [
                                    salaryField,
                                    const SizedBox(height: 12),
                                    salaryUnitField,
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(flex: 3, child: salaryField),
                                  const SizedBox(width: 12),
                                  Expanded(flex: 2, child: salaryUnitField),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _slotsCtrl,
                            label: 'Số lượng cần tuyển *',
                            hint: '1',
                            prefixIcon: Icons.groups_2_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Nhập số lượng';
                              }
                              if ((int.tryParse(v) ?? 0) <= 0) {
                                return 'Số lượng > 0';
                              }
                              return null;
                            },
                          ),
                        ],
                        icon: Icons.account_balance_wallet_outlined,
                        subtitle: 'Minh bạch thu nhập và quy mô tuyển dụng',
                      ),
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
                        _buildSection(
                          'Thời gian làm việc',
                          [
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
                                  child: _buildTimeBox(
                                    label: 'Giờ bắt đầu',
                                    hourCtrl: _startHourCtrl,
                                    minCtrl: _startMinCtrl,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 58,
                                    child: _buildTextField(
                                      controller: _workHoursCtrl,
                                      label: 'Giờ làm/ngày',
                                      hint: '8',
                                      prefixIcon: Icons.timelapse_rounded,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'^\d{0,2}([.,]\d{0,1})?$'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          icon: Icons.schedule_rounded,
                          subtitle:
                              'Thiết lập lịch làm việc rõ ràng cho ứng viên',
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          'Yêu cầu ứng viên',
                          [..._buildCandidateRequirementsEditor()],
                          icon: Icons.fact_check_outlined,
                          subtitle: 'Tùy chọn các tiêu chí phù hợp với vị trí',
                          optional: true,
                        ),
                      ],
                      const SizedBox(height: 16),
                      _buildApplicationDeadlineBox(),
                      const SizedBox(height: 16),
                      _buildSection(
                        'Hình ảnh minh họa',
                        [_buildImageGallery()],
                        icon: Icons.photo_library_outlined,
                        subtitle:
                            'Hình ảnh thực tế giúp bài đăng đáng tin cậy hơn',
                        optional: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildActionButtons(),
    );
  }

  // ── FULL-TIME SECTIONS ─────────────────────────────────────────────────────
  Widget _buildFullTimeBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1565C0).withValues(alpha: 0.11),
            const Color(0xFF7B1FA2).withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF1565C0).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF1565C0),
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lưu ý với bài đăng Full-time',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  kFullTimeEmployerNotice,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullTimeScheduleSection() {
    return _buildSection(
      'Lịch phỏng vấn & ca làm việc',
      [
        Text(
          'Ngày làm trong tuần *',
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
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
                color: selected
                    ? const Color(0xFF7B1FA2)
                    : context.textSecondary,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        _buildDropdown(
          label: 'Ca làm việc *',
          value: _workShift,
          prefixIcon: Icons.schedule_outlined,
          items: FullTimeJobDetails.shiftOptions
              .map(
                (s) => DropdownMenuItem(
                  value: s['value'],
                  child: Text(s['label']!),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _workShift = v!),
        ),
        const SizedBox(height: 12),
        _buildDatePicker(
          label: 'Ngày hẹn phỏng vấn *',
          date: _startDate,
          onTap: () => _pickDate(isStart: true),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTimeBox(
                label: 'Giờ hẹn phỏng vấn *',
                hourCtrl: _startHourCtrl,
                minCtrl: _startMinCtrl,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 58,
                child: _buildTextField(
                  controller: _workHoursCtrl,
                  label: 'Giờ làm/ngày *',
                  hint: '8',
                  prefixIcon: Icons.timelapse_rounded,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d{0,2}([.,]\d{0,1})?$'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
      icon: Icons.calendar_month_outlined,
      subtitle: 'Thiết lập lịch phỏng vấn và khung thời gian làm việc',
    );
  }

  Widget _buildFullTimePayrollSection() {
    return _buildSection(
      'Thông tin lương (tham khảo)',
      [
        _buildDropdown(
          label: 'Ngày trả lương dự kiến *',
          value: _payDayOfMonth,
          prefixIcon: Icons.event_repeat_outlined,
          items: List.generate(
            28,
            (i) => DropdownMenuItem(value: i + 1, child: Text('Ngày ${i + 1}')),
          ),
          onChanged: (v) => setState(() => _payDayOfMonth = v!),
        ),
        const SizedBox(height: 8),
        Text(
          'Chỉ để ứng viên tham khảo. NTD tự thỏa thuận và chi trả lương — ViecNow không can thiệp.',
          style: TextStyle(fontSize: 12, color: context.textSecondary),
        ),
      ],
      icon: Icons.price_check_outlined,
      subtitle: 'Thông tin tham khảo để ứng viên chủ động kế hoạch tài chính',
    );
  }

  Future<void> _showRequirementPicker() async {
    final draft = Set<String>.from(_selectedRequirementTypes);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return FractionallySizedBox(
              heightFactor: 0.86,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: context.borderColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: _gradientColors,
                                ),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Icon(
                                Icons.fact_check_outlined,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Lựa chọn yêu cầu',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Chọn các tiêu chí cần đối chiếu với hồ sơ ứng viên.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.35,
                                      color: context.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: const Icon(Icons.close_rounded),
                              style: IconButton.styleFrom(
                                backgroundColor: context.elevatedSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: context.borderColor),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _requirementOptions.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final option = _requirementOptions[index];
                            final type = option['type']! as String;
                            final selected = draft.contains(type);
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setSheetState(() {
                                    if (selected) {
                                      draft.remove(type);
                                    } else {
                                      draft.add(type);
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(17),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? const Color(
                                            0xFF7B1FA2,
                                          ).withValues(alpha: 0.075)
                                        : context.elevatedSurface.withValues(
                                            alpha: 0.55,
                                          ),
                                    borderRadius: BorderRadius.circular(17),
                                    border: Border.all(
                                      color: selected
                                          ? const Color(0xFF7B1FA2)
                                          : context.borderColor,
                                      width: selected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? const Color(
                                                  0xFF7B1FA2,
                                                ).withValues(alpha: 0.13)
                                              : Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(
                                            13,
                                          ),
                                        ),
                                        child: Icon(
                                          option['icon']! as IconData,
                                          color: selected
                                              ? const Color(0xFF7B1FA2)
                                              : context.textSecondary,
                                          size: 21,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              option['label']! as String,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: context.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              option['description']! as String,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                height: 1.35,
                                                color: context.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        width: 25,
                                        height: 25,
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? const Color(0xFF7B1FA2)
                                              : Colors.transparent,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: selected
                                                ? const Color(0xFF7B1FA2)
                                                : context.borderColor,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: selected
                                            ? const Icon(
                                                Icons.check_rounded,
                                                size: 16,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          border: Border(
                            top: BorderSide(color: context.borderColor),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(sheetContext),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('Hủy'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                onPressed: () =>
                                    Navigator.pop(sheetContext, true),
                                icon: const Icon(Icons.check_rounded),
                                label: Text(
                                  draft.isEmpty
                                      ? 'Áp dụng'
                                      : 'Áp dụng (${draft.length})',
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF7B1FA2),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
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
              ),
            );
          },
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _selectedRequirementTypes
        ..clear()
        ..addAll(draft);
      if (draft.contains('languages') && _requiredLanguage == 'Tất cả') {
        _requiredLanguage = 'Tiếng Anh';
        _englishLevelType = 'CEFR';
        _requiredLanguageLevel = 'B1';
      }
      if (draft.contains('gender') && _requiredGender == 'any') {
        _requiredGender = 'male';
      }
      if (draft.contains('education') && _minEducation == 'none') {
        _minEducation = 'high_school';
      }
      if (draft.contains('experience') && _requiredExperience == 'Tất cả') {
        _requiredExperience = 'no_exp';
      }
    });
  }

  List<Widget> _buildCandidateRequirementsEditor() {
    final widgets = <Widget>[
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showRequirementPicker,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF7B1FA2).withValues(alpha: 0.11),
                  const Color(0xFF1565C0).withValues(alpha: 0.07),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF7B1FA2).withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: _gradientColors),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7B1FA2).withValues(alpha: 0.22),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.playlist_add_check_circle_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lựa chọn yêu cầu',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _selectedRequirementTypes.isEmpty
                            ? 'Chọn kỹ năng, chứng chỉ, ngoại ngữ và các tiêu chí khác'
                            : 'Đang áp dụng ${_selectedRequirementTypes.length} tiêu chí cho bài đăng',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    size: 19,
                    color: Color(0xFF7B1FA2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ];

    if (_selectedRequirementTypes.isNotEmpty) {
      widgets.addAll([
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 17,
              color: Color(0xFF2E7D32),
            ),
            const SizedBox(width: 7),
            Text(
              'Tiêu chí đã chọn',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _requirementOptions
              .where((option) {
                return _selectedRequirementTypes.contains(option['type']);
              })
              .map((option) {
                final type = option['type']! as String;
                return InputChip(
                  avatar: Icon(
                    option['icon']! as IconData,
                    size: 17,
                    color: const Color(0xFF7B1FA2),
                  ),
                  label: Text(
                    option['label']! as String,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  deleteIcon: const Icon(Icons.close_rounded, size: 17),
                  backgroundColor: const Color(
                    0xFF7B1FA2,
                  ).withValues(alpha: 0.08),
                  side: BorderSide(
                    color: const Color(0xFF7B1FA2).withValues(alpha: 0.2),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onDeleted: () =>
                      setState(() => _selectedRequirementTypes.remove(type)),
                );
              })
              .toList(),
        ),
      ]);
    }

    if (_selectedRequirementTypes.contains('skills')) {
      widgets.addAll([
        const SizedBox(height: 14),
        _buildRequirementCard(
          title: 'Kỹ năng bắt buộc',
          icon: Icons.psychology_outlined,
          children: [
            _buildTextField(
              controller: _requiredSkillsCtrl,
              label: 'Các kỹ năng',
              hint: 'Ví dụ: Giao tiếp, Excel, phục vụ khách hàng',
              prefixIcon: Icons.psychology_outlined,
              maxLines: 2,
            ),
            const SizedBox(height: 6),
            Text(
              'Ngăn cách nhiều kỹ năng bằng dấu phẩy.',
              style: TextStyle(fontSize: 11.5, color: context.textSecondary),
            ),
          ],
        ),
      ]);
    }
    if (_selectedRequirementTypes.contains('certificates')) {
      widgets.addAll([
        const SizedBox(height: 12),
        _buildRequirementCard(
          title: 'Chứng chỉ bắt buộc',
          icon: Icons.workspace_premium_outlined,
          children: [
            _buildTextField(
              controller: _requiredCertificatesCtrl,
              label: 'Tên chứng chỉ',
              hint: 'Ví dụ: Chứng chỉ hành nghề, An toàn lao động',
              prefixIcon: Icons.workspace_premium_outlined,
              maxLines: 2,
            ),
          ],
        ),
      ]);
    }
    if (_selectedRequirementTypes.contains('languages')) {
      widgets.addAll([
        const SizedBox(height: 12),
        _buildRequirementCard(
          title: 'Ngoại ngữ và trình độ tối thiểu',
          icon: Icons.translate_rounded,
          children: _buildLanguageRequirementFields(),
        ),
      ]);
    }
    if (_selectedRequirementTypes.contains('gender')) {
      widgets.addAll([
        const SizedBox(height: 12),
        _buildRequirementCard(
          title: 'Giới tính',
          icon: Icons.wc_outlined,
          children: [
            _buildDropdown<String>(
              label: 'Giới tính yêu cầu',
              value: _requiredGender,
              prefixIcon: Icons.wc_outlined,
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Nam')),
                DropdownMenuItem(value: 'female', child: Text('Nữ')),
                DropdownMenuItem(value: 'other', child: Text('Khác')),
              ],
              onChanged: (value) =>
                  setState(() => _requiredGender = value ?? 'male'),
            ),
          ],
        ),
      ]);
    }
    if (_selectedRequirementTypes.contains('education')) {
      widgets.addAll([
        const SizedBox(height: 12),
        _buildRequirementCard(
          title: 'Học vấn',
          icon: Icons.school_outlined,
          children: [
            _buildDropdown<String>(
              label: 'Trình độ tối thiểu',
              value: _minEducation,
              prefixIcon: Icons.school_outlined,
              items: FullTimeJobDetails.educationOptions
                  .where((option) => option['value'] != 'none')
                  .map(
                    (option) => DropdownMenuItem(
                      value: option['value'],
                      child: Text(option['label']!),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _minEducation = value ?? 'high_school'),
            ),
          ],
        ),
      ]);
    }
    if (_selectedRequirementTypes.contains('experience')) {
      widgets.addAll([
        const SizedBox(height: 12),
        _buildRequirementCard(
          title: 'Kinh nghiệm làm việc',
          icon: Icons.work_history_outlined,
          children: [
            _buildDropdown<String>(
              label: 'Kinh nghiệm tối thiểu',
              value: _requiredExperience,
              prefixIcon: Icons.work_history_outlined,
              items: const [
                DropdownMenuItem(
                  value: 'no_exp',
                  child: Text('Không yêu cầu - chấp nhận người mới', overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(value: 'under_1', child: Text('Dưới 1 năm', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: '1_to_3', child: Text('1 - 3 năm', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: '3_to_5', child: Text('3 - 5 năm', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'over_5', child: Text('Trên 5 năm', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) =>
                  setState(() => _requiredExperience = value ?? 'no_exp'),
            ),
          ],
        ),
      ]);
    }

    widgets.addAll([
      const SizedBox(height: 14),
      _buildTextField(
        controller: _requirementsCtrl,
        label: 'Yêu cầu khác (không bắt buộc)',
        hint: 'Ví dụ: Có phương tiện đi lại, có thể làm cuối tuần...',
        prefixIcon: Icons.notes_rounded,
        maxLines: 3,
      ),
    ]);
    return widgets;
  }

  List<Widget> _buildLanguageRequirementFields() {
    final widgets = <Widget>[
      _buildDropdown<String>(
        label: 'Ngoại ngữ',
        value: _requiredLanguage,
        prefixIcon: Icons.translate_rounded,
        items: LanguageProficiencyLevels.languageOptions
            .map(
              (language) =>
                  DropdownMenuItem(value: language, child: Text(language)),
            )
            .toList(),
        onChanged: (language) {
          if (language == null) return;
          setState(() {
            _requiredLanguage = language;
            if (language == 'Tiếng Anh') {
              _englishLevelType = 'CEFR';
              _requiredLanguageLevel = 'B1';
            } else {
              final levels = LanguageProficiencyLevels.forLanguage(language);
              _requiredLanguageLevel = levels.isEmpty ? 'Tất cả' : levels.first;
            }
          });
        },
      ),
      const SizedBox(height: 12),
    ];

    if (_requiredLanguage == 'Tiếng Anh') {
      widgets.add(
        _buildDropdown<String>(
          label: 'Hệ quy chiếu',
          value: _englishLevelType,
          prefixIcon: Icons.straighten_rounded,
          items: const [
            DropdownMenuItem(value: 'CEFR', child: Text('CEFR (A1 - C2)')),
            DropdownMenuItem(value: 'TOEIC', child: Text('TOEIC')),
            DropdownMenuItem(value: 'IELTS', child: Text('IELTS')),
          ],
          onChanged: (type) {
            if (type == null) return;
            setState(() {
              _englishLevelType = type;
              if (type == 'CEFR') {
                _requiredLanguageLevel = 'B1';
              } else {
                _languageScoreCtrl.text = type == 'TOEIC' ? '650' : '6.0';
              }
            });
          },
        ),
      );
      widgets.add(const SizedBox(height: 12));
    }

    if (_requiredLanguage == 'Tiếng Anh' &&
        (_englishLevelType == 'TOEIC' || _englishLevelType == 'IELTS')) {
      widgets.add(
        _buildTextField(
          controller: _languageScoreCtrl,
          label: 'Điểm $_englishLevelType tối thiểu',
          hint: _englishLevelType == 'TOEIC' ? '650' : '6.0',
          prefixIcon: Icons.score_outlined,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
        ),
      );
    } else {
      final levels = _requiredLanguage == 'Tiếng Anh'
          ? LanguageProficiencyLevels.englishCefrLevels
          : LanguageProficiencyLevels.forLanguage(_requiredLanguage);
      if (!levels.contains(_requiredLanguageLevel) && levels.isNotEmpty) {
        _requiredLanguageLevel = levels.first;
      }
      widgets.add(
        _buildDropdown<String>(
          label: 'Trình độ tối thiểu',
          value: _requiredLanguageLevel,
          prefixIcon: Icons.trending_up_rounded,
          items: levels
              .map(
                (level) => DropdownMenuItem(value: level, child: Text(level)),
              )
              .toList(),
          onChanged: (level) {
            if (level != null) {
              setState(() => _requiredLanguageLevel = level);
            }
          },
        ),
      );
    }
    widgets.addAll([
      const SizedBox(height: 6),
      Text(
        'Điều kiện sẽ được hiểu là “từ mức này trở lên”, ví dụ TOEIC từ 650.',
        style: TextStyle(fontSize: 11.5, color: context.textSecondary),
      ),
    ]);
    return widgets;
  }

  Widget _buildRequirementCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: context.elevatedSurface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFF7B1FA2).withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B1FA2).withValues(alpha: 0.045),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF7B1FA2).withValues(alpha: 0.15),
                      const Color(0xFF1565C0).withValues(alpha: 0.09),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 19, color: const Color(0xFF7B1FA2)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Đối chiếu với thông tin hồ sơ ứng viên',
                      style: TextStyle(
                        fontSize: 10.8,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Đang dùng',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFullTimeRequirementsSection() {
    return _buildSection(
      'Yêu cầu ứng viên',
      [
        ..._buildCandidateRequirementsEditor(),
        const SizedBox(height: 14),
        _buildPreferenceToggle(
          icon: Icons.description_outlined,
          title: 'Bắt buộc nộp CV',
          subtitle: 'Ứng viên phải đính kèm CV khi ứng tuyển',
          value: _requiresCv,
          onChanged: (v) => setState(() => _requiresCv = v),
        ),
        const SizedBox(height: 10),
        _buildPreferenceToggle(
          icon: Icons.record_voice_over_outlined,
          title: 'Phỏng vấn trực tiếp',
          subtitle: 'NTD sẽ liên hệ phỏng vấn trước khi nhận việc',
          value: _interviewRequired,
          onChanged: (v) => setState(() => _interviewRequired = v),
        ),
      ],
      icon: Icons.fact_check_outlined,
      subtitle: 'Xây dựng bộ tiêu chí phù hợp với vị trí tuyển dụng',
      optional: true,
    );
  }

  Widget _buildPreferenceToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: value
            ? const Color(0xFF7B1FA2).withValues(alpha: 0.065)
            : context.elevatedSurface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: value
              ? const Color(0xFF7B1FA2).withValues(alpha: 0.22)
              : context.borderColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: value
                  ? const Color(0xFF7B1FA2).withValues(alpha: 0.12)
                  : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 19,
              color: value ? const Color(0xFF7B1FA2) : context.textSecondary,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.8,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: const Color(0xFF7B1FA2),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildFullTimeBenefitsSection() {
    return _buildSection(
      'Phúc lợi & thử việc',
      [
        _buildTextField(
          controller: _probationCtrl,
          label: 'Thời gian thử việc (ngày)',
          hint: '60',
          prefixIcon: Icons.hourglass_bottom_rounded,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _benefitsCtrl,
          label: 'Quyền lợi',
          hint: 'Bảo hiểm, thưởng, ăn trưa, nghỉ phép...',
          prefixIcon: Icons.redeem_outlined,
          maxLines: 3,
        ),
      ],
      icon: Icons.workspace_premium_outlined,
      subtitle: 'Trình bày chính sách và quyền lợi dành cho nhân sự',
      optional: true,
    );
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
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -34,
            top: -42,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: 72,
            bottom: -46,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 18, 20),
              child: Row(
                children: [
                  Material(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => Get.back(),
                      borderRadius: BorderRadius.circular(14),
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEdit
                              ? 'Sửa bài đăng'
                              : (_isFullTimeScreen
                                    ? 'Tạo bài đăng Full-time'
                                    : 'Tạo bài đăng Part-time'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.25,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _isEdit
                              ? 'Cập nhật nội dung tuyển dụng của bạn'
                              : 'Tạo cơ hội việc làm rõ ràng và thu hút',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: const Icon(
                      Icons.post_add_rounded,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormIntroduction() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF7B1FA2).withValues(alpha: 0.09),
            const Color(0xFF1565C0).withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF7B1FA2).withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: _gradientColors),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7B1FA2).withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hoàn thiện thông tin tuyển dụng',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Các trường có dấu * là bắt buộc. Thông tin càng rõ ràng, ứng viên càng dễ đưa ra quyết định.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_imageBase64s.isNotEmpty) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _imageBase64s.asMap().entries.map((entry) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        base64Decode(entry.value),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Material(
                      color: const Color(0xFFE53935),
                      shape: const CircleBorder(),
                      elevation: 3,
                      child: InkWell(
                        onTap: () =>
                            setState(() => _imageBase64s.removeAt(entry.key)),
                        customBorder: const CircleBorder(),
                        child: const SizedBox(
                          width: 26,
                          height: 26,
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
        ],
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _pickPostImage,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF7B1FA2).withValues(alpha: 0.045),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF7B1FA2).withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B1FA2).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: Color(0xFF7B1FA2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Thêm ảnh cho bài đăng',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_imageBase64s.length}/5 ảnh · Mỗi ảnh dưới 900KB',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF7B1FA2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── SECTION ────────────────────────────────────────────────────────────────
  Widget _buildSection(
    String title,
    List<Widget> children, {
    IconData icon = Icons.widgets_outlined,
    String? subtitle,
    bool optional = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF7B1FA2).withValues(alpha: 0.14),
                      const Color(0xFF1565C0).withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 21, color: const Color(0xFF7B1FA2)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: context.textPrimary,
                              letterSpacing: -0.15,
                            ),
                          ),
                        ),
                        if (optional)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.elevatedSurface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Tùy chọn',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: context.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: context.borderColor.withValues(alpha: 0.7)),
          const SizedBox(height: 16),
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
    IconData? prefixIcon,
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
        alignLabelWithHint: maxLines > 1,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: 20, color: const Color(0xFF7B1FA2)),
        hintStyle: TextStyle(
          color: context.textSecondary.withValues(alpha: 0.72),
          fontSize: 13,
        ),
        labelStyle: TextStyle(
          color: context.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          color: Color(0xFF7B1FA2),
          fontWeight: FontWeight.w700,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE53935)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 15,
        ),
        filled: true,
        fillColor: context.elevatedSurface.withValues(alpha: 0.72),
      ),
    );
  }

  // ── DROPDOWN ───────────────────────────────────────────────────────────────
  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    IconData? prefixIcon,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: 20, color: const Color(0xFF7B1FA2)),
        labelStyle: TextStyle(
          color: context.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          color: Color(0xFF7B1FA2),
          fontWeight: FontWeight.w700,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 15,
        ),
        filled: true,
        fillColor: context.elevatedSurface.withValues(alpha: 0.72),
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      borderRadius: BorderRadius.circular(14),
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: context.textPrimary,
      ),
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
        Row(
          children: [
            const Icon(
              Icons.workspaces_outline,
              size: 17,
              color: Color(0xFF7B1FA2),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: context.elevatedSurface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            children: options.map((opt) {
              final isSelected = opt['value'] == selected;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(opt['value']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              begin: _gradientBegin,
                              end: _gradientEnd,
                              colors: _gradientColors,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF7B1FA2,
                                ).withValues(alpha: 0.22),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          opt['value'] == 'full_time'
                              ? Icons.business_center_outlined
                              : Icons.schedule_outlined,
                          size: 17,
                          color: isSelected
                              ? Colors.white
                              : context.textSecondary,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          opt['label']!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : context.textSecondary,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: context.elevatedSurface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: date != null
                          ? context.textPrimary
                          : context.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF7B1FA2).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: Color(0xFF7B1FA2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── BUTTONS ────────────────────────────────────────────────────────────────
  Widget _buildActionButtons() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: context.borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => _submit(isDraft: true),
                      icon: const Icon(Icons.bookmark_border_rounded, size: 19),
                      label: const Text('Lưu nháp'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF7B1FA2),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        side: const BorderSide(
                          color: Color(0xFF7B1FA2),
                          width: 1.4,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: _isSubmitting
                            ? null
                            : const LinearGradient(
                                begin: _gradientBegin,
                                end: _gradientEnd,
                                colors: _gradientColors,
                              ),
                        color: _isSubmitting ? context.elevatedSurface : null,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: _isSubmitting
                            ? null
                            : [
                                BoxShadow(
                                  color: const Color(
                                    0xFF7B1FA2,
                                  ).withValues(alpha: 0.28),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () => _submit(isDraft: false),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                          _isSubmitting ? 'Đang xử lý...' : 'Gửi duyệt',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          disabledForegroundColor: context.textSecondary,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── TIME INPUT BOX ─────────────────────────────────────────────────────────
  Widget _buildTimeBox({
    required String label,
    required TextEditingController hourCtrl,
    required TextEditingController minCtrl,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: context.elevatedSurface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 34,
                child: Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) _normalizeTimePart(hourCtrl, 23);
                  },
                  child: TextField(
                    controller: hourCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                      const _MaxTimePartInputFormatter(23),
                    ],
                    textAlign: TextAlign.center,
                    textInputAction: TextInputAction.next,
                    onEditingComplete: () {
                      _normalizeTimePart(hourCtrl, 23);
                      FocusScope.of(context).nextFocus();
                    },
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: '00',
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: context.textPrimary,
                  ),
                ),
              ),
              SizedBox(
                width: 34,
                child: Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) _normalizeTimePart(minCtrl, 59);
                  },
                  child: TextField(
                    controller: minCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                      const _MaxTimePartInputFormatter(59),
                    ],
                    textAlign: TextAlign.center,
                    textInputAction: TextInputAction.next,
                    onEditingComplete: () {
                      _normalizeTimePart(minCtrl, 59);
                      FocusScope.of(context).nextFocus();
                    },
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: '00',
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationDeadlineBox() {
    return _buildSection(
      'Hạn ứng tuyển',
      [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildDatePicker(
                label: 'Ngày hạn *',
                date: _applicationDeadline,
                onTap: _pickDeadlineDate,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: _buildTimeBox(
                label: 'Giờ hạn *',
                hourCtrl: _deadlineHourCtrl,
                minCtrl: _deadlineMinCtrl,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: const Color(0xFFFFB300).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                size: 17,
                color: Color(0xFFE65100),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nên đặt hạn đủ sớm để có thời gian xem và duyệt hồ sơ ứng viên.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: context.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      icon: Icons.timer_outlined,
      subtitle: 'Thời điểm hệ thống ngừng nhận đơn ứng tuyển',
    );
  }
}

class _MaxTimePartInputFormatter extends TextInputFormatter {
  const _MaxTimePartInputFormatter(this.maxValue);

  final int maxValue;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final value = int.tryParse(text);
    if (value == null) return oldValue;
    if (value <= maxValue) return newValue;

    final clamped = maxValue.toString().padLeft(2, '0');
    return TextEditingValue(
      text: clamped,
      selection: TextSelection.collapsed(offset: clamped.length),
    );
  }
}
